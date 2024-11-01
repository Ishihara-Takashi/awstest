# ---------------------------------------------
# Terraform configuration
# ---------------------------------------------
terraform {
  required_version = ">=0.13"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  backend "s3" {
    bucket  = "aws-ecs-terraform-tfstate-ishihara-test"
    key     = "tfstylog.tfstate"
    region  = "ap-northeast-1"
    dynamodb_table = "aws-ecs-terraform-tfstate-locking"
    profile = "terraform"
  }

  provider "aws" {
   region  = "ap-northeast-1"
  }
}
