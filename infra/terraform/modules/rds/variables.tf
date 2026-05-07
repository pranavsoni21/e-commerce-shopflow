variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
}

# From VPC module outputs
variable "private_subnet_ids" {
  description = "Private subnet IDs — RDS must live in private subnets only"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID — needed to create the RDS security group"
  type        = string
}

# From EKS module output
# RDS security group only allows traffic from EKS nodes
variable "eks_node_security_group_id" {
  description = "Security group ID of EKS worker nodes — only source allowed to reach RDS"
  type        = string
}

# From KMS module output
variable "kms_key_arn" {
  description = "KMS key ARN for RDS storage encryption"
  type        = string
}

# Credentials — pass these from root tfvars, never hardcode
# In production these are bootstrapped once then Vault takes over rotation
variable "db_username" {
  description = "Master username for RDS instance"
  type        = string
  sensitive   = true # won't appear in terraform plan output
}

variable "db_password" {
  description = "Master password for RDS instance — bootstrapped here, rotated by Vault"
  type        = string
  sensitive   = true # won't appear in terraform plan output
}
