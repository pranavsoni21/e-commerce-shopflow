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


# ─────────────────────────────────────────────────────────────
# LAYER 3b: IRSA — VAULT ROLE
#
# Used by: Vault pod in the vault namespace
# Trust:   Only vault's service account via OIDC
#
# Vault needs KMS to auto-unseal itself when pods restart.
# Without KMS auto-unseal, you'd have to manually unseal
# Vault every time a node reboots — painful at 3am.
# ─────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "vault_assume_role" {
  statement {
    sid     = "VaultAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:vault:vault"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "vault_role" {
  name               = "${var.tags["ProjectName"]}-vault-role"
  description        = "IRSA role for HashiCorp Vault pod — KMS auto-unseal"
  assume_role_policy = data.aws_iam_policy_document.vault_assume_role.json
  tags               = var.tags
}

# Inline policy — only the exact KMS key Vault uses
# kms:Encrypt     → Vault wraps unseal keys before storing
# kms:Decrypt     → Vault unwraps unseal keys on startup
# kms:DescribeKey → Vault verifies the key exists and is enabled
data "aws_iam_policy_document" "vault_kms_permissions" {
  statement {
    sid    = "VaultKMSUnseal"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_policy" "vault_kms_policy" {
  name        = "${var.tags["ProjectName"]}-vault-kms-policy"
  description = "Allows Vault to use KMS for auto-unseal"
  policy      = data.aws_iam_policy_document.vault_kms_permissions.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "vault_kms_attachment" {
  role       = aws_iam_role.vault_role.name
  policy_arn = aws_iam_policy.vault_kms_policy.arn
}


# ─────────────────────────────────────────────────────────────
# LAYER 3c: GITHUB ACTIONS ROLE
#
# Used by: GitHub Actions CI/CD pipeline (Phase 4)
# Trust:   Only your specific GitHub repo can assume this
#          via OIDC — no long-lived AWS keys needed
#
# This is NOT an IRSA role (it's not a pod).
# GitHub has its own OIDC provider separate from EKS.
# ─────────────────────────────────────────────────────────────

# Register GitHub's OIDC provider with AWS once per account
data "tls_certificate" "github_oidc" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_oidc.certificates[0].sha1_fingerprint]
  tags            = var.tags
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    sid     = "GitHubActionsAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    # Restricts to ONLY your repo — not any other GitHub repo in the world.
    # Format: repo:<org>/<repo>:ref:refs/heads/<branch>
    # Using wildcard on ref so all branches can build, but only main deploys
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "github_actions_role" {
  name               = "${var.tags["ProjectName"]}-github-actions-role"
  description        = "Role assumed by GitHub Actions via OIDC — no static credentials"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
  tags               = var.tags
}

# Least-privilege: only exactly what the pipeline needs
# GetAuthorizationToken → docker login to ECR
# Batch/Put/Initiate/Upload/Complete → docker push steps
# DescribeCluster        → kubectl config update-kubeconfig
data "aws_iam_policy_document" "github_actions_permissions" {
  # ECR: push images (scoped to your account's registries)
  statement {
    sid       = "ECRGetAuthToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # GetAuthorizationToken cannot be scoped to a resource
  }

  statement {
    sid    = "ECRPushImages"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]
    resources = var.ecr_repository_arns # scoped to ShopFlow repos only
  }

  # EKS: update kubeconfig so kubectl works in the pipeline
  statement {
    sid       = "EKSDescribeCluster"
    effect    = "Allow"
    actions   = ["eks:DescribeCluster"]
    resources = [var.eks_cluster_arn]
  }
}

resource "aws_iam_policy" "github_actions_policy" {
  name        = "${var.tags["ProjectName"]}-github-actions-policy"
  description = "Least-privilege policy for GitHub Actions CI/CD"
  policy      = data.aws_iam_policy_document.github_actions_permissions.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "github_actions_attachment" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = aws_iam_policy.github_actions_policy.arn
}
