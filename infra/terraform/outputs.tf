output "db_host" {
  description = "RDS instance DNS name"
  value       = module.rds.db_host
}

output "Monitoring-EC2-public-ip" {
  value = module.monitoring.EC2-public-ip
}
