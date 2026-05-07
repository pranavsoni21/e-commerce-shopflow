variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
}

# From EKS module output
variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider created by the EKS module"
  type        = string
}

# From EKS module output
variable "oidc_provider_url" {
  description = "URL of the OIDC provider (without https://)"
  type        = string
}

# From KMS module (created separately for Vault auto-unseal)
variable "kms_key_arn" {
  description = "ARN of the KMS key used by Vault for auto-unseal"
  type        = string
}

# From ECR module output
variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs GitHub Actions can push to"
  type        = list(string)
}

# From EKS module output
variable "eks_cluster_arn" {
  description = "ARN of the EKS cluster"
  type        = string
}

# Your GitHub org and repo name
variable "github_org" {
  description = "GitHub organization or username (e.g. 'pranav-org')"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (e.g. 'shopflow')"
  type        = string
}
