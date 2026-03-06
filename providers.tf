provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data source for current AWS account ID (used in KMS key policies)
data "aws_caller_identity" "current" {
}
