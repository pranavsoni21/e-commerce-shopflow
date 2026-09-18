terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.11.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }

  required_version = ">1.15.3"
  cloud {
    organization = "fort-hcp"
    workspaces {
      name = "dev"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}
