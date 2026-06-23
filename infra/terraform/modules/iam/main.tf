# ============================================================
# ShopFlow IAM Module
# Manages all roles and policies for EKS, nodes, and pods
#
# Three layers:
#   1. EKS Cluster Role    — control plane permissions
#   2. Node Group Role     — worker node permissions
#   3. IRSA Roles          — pod-level AWS access (Vault, EBS CSI, GitHub Actions)
# ============================================================


# ─────────────────────────────────────────────────────────────
# LAYER 1: EKS CLUSTER ROLE
# Used by: EKS control plane to manage AWS resources
# Trust:   Only the EKS service can assume this
# ─────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    sid     = "EKSClusterAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster_role" {
  name               = "${var.tags["ProjectName"]}-eks-cluster-role"
  description        = "Role assumed by EKS control plane to manage cluster resources"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json
  tags               = var.tags
}

# Gives EKS control plane permission to manage networking,
# security groups, and load balancers on your behalf
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}


# ─────────────────────────────────────────────────────────────
# LAYER 2: NODE GROUP ROLE
# Used by: EC2 worker nodes to join cluster and pull images
# Trust:   Only EC2 service can assume this
# ─────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "eks_node_assume_role" {
  statement {
    sid     = "EKSNodeAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_node_role" {
  name               = "${var.tags["ProjectName"]}-eks-node-role"
  description        = "Role assumed by EKS worker nodes"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json
  tags               = var.tags
}

# Allows nodes to register with the cluster, describe node resources,
# and report node status back to control plane
resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# Allows the VPC CNI plugin to assign/unassign secondary IPs
# to pods — without this, pods don't get IP addresses
resource "aws_iam_role_policy_attachment" "cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# Allows nodes to pull Docker images from ECR
# (read-only — nodes should never push images)
resource "aws_iam_role_policy_attachment" "ecr_read_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Allows the EBS CSI driver to create/attach/delete EBS volumes
# Required for Prometheus persistent storage in Phase 7
resource "aws_iam_role_policy_attachment" "ebs_csi_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}


# ─────────────────────────────────────────────────────────────
# LAYER 3a: IRSA — EBS CSI CONTROLLER ROLE
#
# Used by: The ebs-csi-controller pod in kube-system namespace
# Trust:   Only that specific pod's service account via OIDC
#
# Why separate from node role?
# Node role gives ALL pods on a node EBS access.
# IRSA gives ONLY the CSI controller pod EBS access.
# ─────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    sid     = "EBSCSIAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"] # IRSA uses WebIdentity, not AssumeRole

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    # This condition is the key security control:
    # Only the exact service account in the exact namespace can assume this role.
    # Even another pod in kube-system with a different service account cannot.
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_role" {
  name               = "${var.tags["ProjectName"]}-ebs-csi-role"
  description        = "IRSA role for EBS CSI driver controller pod"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_irsa_policy" {
  role       = aws_iam_role.ebs_csi_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

