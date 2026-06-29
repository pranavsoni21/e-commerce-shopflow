output "db_host" {
  description = "RDS instance DNS name"
  value = module.rds.db_host
}

output "db_connection_strings" {
  value = module.rds.connection_strings
  sensitive = true
}
