output "rds_key_arn" {
  description = "Pass to RDS module as var.kms_key_arn"
  value       = aws_kms_key.rds.arn
}