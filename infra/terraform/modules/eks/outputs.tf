output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks_oidc.arn
}

output "oidc_provider_url" {
  value = aws_iam_openid_connect_provider.eks_oidc.url
}

output "eks_cluster_arn" {
  value = aws_eks_cluster.eks_cluster.arn
}

output "node_security_group_id" {
  value = aws_eks_node_group.eks_node_group.resources[0].remote_access_security_group_id
}