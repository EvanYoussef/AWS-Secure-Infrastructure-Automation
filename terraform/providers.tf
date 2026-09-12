terraform {
  backend "s3" {
    bucket       = "evanyoussef-devsecops-terraform-state-1366463268"
    key          = "devsecops/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}