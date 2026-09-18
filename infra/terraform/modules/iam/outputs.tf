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


output "notification_svc_role_arn" {
  value = aws_iam_role.notification_svc.arn
}

output "load_balancer_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = aws_iam_role.load_balancer_controller.arn
}