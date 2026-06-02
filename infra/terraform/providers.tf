terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.11.0"
    }
  }
  required_version = "~>1.15.3"
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
