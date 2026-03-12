terraform {
  required_version = ">= 1.5"

  backend "local" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.35"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
