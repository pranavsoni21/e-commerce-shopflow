# kms/main.tf — simple version, no circular dependency

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "vault_unseal" {
  description             = "KMS key for Vault auto-unseal — ${var.tags["ProjectName"]}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.tags["ProjectName"]}-vault-unseal-key"
  })
}

resource "aws_kms_alias" "vault_unseal" {
  name          = "alias/${var.tags["ProjectName"]}-vault-unseal"
  target_key_id = aws_kms_key.vault_unseal.key_id
}

resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption — ${var.tags["ProjectName"]}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.tags["ProjectName"]}-rds-key"
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.tags["ProjectName"]}-rds"
  target_key_id = aws_kms_key.rds.key_id
}