# Creating locals block for common tags
locals {
  tags = {
    "ProjectName" = var.project_name
    "CreatedBy"   = "Terraform"
    "Environment" = var.environment
  }
}

# VPC
module "vpc" {
  source = "./modules/vpc"
  tags   = local.tags
}

# ECR
module "ecr" {
  source = "./modules/ecr"
  tags   = local.tags
}

module "eks" {
  source = "./modules/eks"
  tags   = local.tags

  depends_on         = [module.iam.node_role_policy_attachments]
  eks_role_arn       = module.iam.eks_cluster_role_arn
  node_role_arn      = module.iam.eks_node_role_arn
  private_subnet_ids = module.vpc.private_subnets_id
}

module "iam" {
  source = "./modules/iam"
  tags   = local.tags

  ecr_repository_arns = module.ecr.ecr_repository_arns
  eks_cluster_arn     = module.eks.eks_cluster_arn
  github_org          = var.github_org
  github_repo         = var.github_repo
  oidc_provider_arn   = module.eks.oidc_provider_arn
  oidc_provider_url   = module.eks.oidc_provider_url
}

module "rds" {
  source = "./modules/rds"
  tags   = local.tags

  db_password                = var.db_password
  db_username                = var.db_username
  eks_node_security_group_id = module.eks.node_security_group_id
  private_subnet_ids         = module.vpc.private_subnets_id
  vpc_id                     = module.vpc.vpc_id
}

