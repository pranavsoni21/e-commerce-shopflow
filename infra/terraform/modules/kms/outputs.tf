output "vault_unseal_key_arn" {
  description = "Pass to IAM module as var.kms_key_arn"
  value       = aws_kms_key.vault_unseal.arn
}

output "vault_unseal_key_id" {
  description = "Pass to Vault helm values as key_id for auto-unseal"
  value       = aws_kms_key.vault_unseal.key_id
}

output "rds_key_arn" {
  description = "Pass to RDS module as var.kms_key_arn"
  value       = aws_kms_key.rds.arn
}