# ── Consumed by EKS module ───────────────────────────────────

output "eks_cluster_role_arn" {
  description = "Pass to EKS module as var.eks_role_arn"
  value       = aws_iam_role.eks_cluster_role.arn
}

output "eks_node_role_arn" {
  description = "Pass to EKS module as var.node_role_arn"
  value       = aws_iam_role.eks_node_role.arn
}

# Pass this to EKS module's depends_on to prevent the race condition
# where nodes try to join before IAM policies are attached
output "node_role_policy_attachments" {
  description = "Use in EKS module depends_on"
  value = [
    aws_iam_role_policy_attachment.worker_node_policy.id,
    aws_iam_role_policy_attachment.cni_policy.id,
    aws_iam_role_policy_attachment.ecr_read_policy.id,
    aws_iam_role_policy_attachment.ebs_csi_node_policy.id,
  ]
}

# ── Consumed by EKS addon (ebs-csi-driver) ───────────────────

output "ebs_csi_role_arn" {
  description = "Pass to aws_eks_addon ebs-csi-driver as service_account_role_arn"
  value       = aws_iam_role.ebs_csi_role.arn
}

# ── Consumed by Vault Helm chart values ──────────────────────

output "vault_role_arn" {
  description = "Annotate Vault's service account with this ARN"
  value       = aws_iam_role.vault_role.arn
}

# ── Consumed by GitHub Actions secret ────────────────────────

output "github_actions_role_arn" {
  description = "Set as AWS_ROLE_ARN secret in GitHub repository settings"
  value       = aws_iam_role.github_actions_role.arn
}
