# ── Consumed by Kubernetes secrets / Vault config ────────────

output "db_host" {
  description = "RDS endpoint — pass to Vault database secrets engine"
  value       = aws_db_instance.shopflow_db.address
}

output "db_port" {
  description = "RDS port — always 5432 for PostgreSQL"
  value       = aws_db_instance.shopflow_db.port
}

output "db_username" {
  description = "Master username — used by Vault to manage dynamic credentials"
  value       = aws_db_instance.shopflow_db.username
  sensitive   = true
}

output "db_instance_id" {
  description = "RDS instance identifier — useful for console lookups and monitoring"
  value       = aws_db_instance.shopflow_db.id
}

output "rds_security_group_id" {
  description = "RDS security group ID — needed if other resources need DB access"
  value       = aws_security_group.rds_sg.id
}

# Connection strings per service database
# These go into Vault as the base connection config
# Vault then issues short-lived credentials on top of these
output "connection_strings" {
  description = "Per-service DB connection strings (without password — Vault supplies that)"
  sensitive   = true
  value = {
    user    = "postgresql://${aws_db_instance.shopflow_db.address}:5432/userdb"
    product = "postgresql://${aws_db_instance.shopflow_db.address}:5432/productdb"
    order   = "postgresql://${aws_db_instance.shopflow_db.address}:5432/orderdb"
  }
}
