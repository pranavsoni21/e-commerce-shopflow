output "db_host" {
  description = "RDS instance DNS name"
  value       = module.rds.db_host
}

output "Monitoring-EC2-public-ip" {
  value = module.monitoring.EC2-public-ip
}

output "notification_svc_role_arn" {
  value = module.iam.notification_svc_role_arn
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster CA certificate"
  value       = module.eks.cluster_certificate_authority_data
}