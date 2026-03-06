output "aws_account_id" {
  description = "AWS account id"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region used by bootstrap"
  value       = var.aws_region
}

output "terraform_state_bucket" {
  description = "Terraform remote state bucket"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "terraform_lock_table" {
  description = "Legacy lock table name (empty when disabled)"
  value       = var.create_lock_table ? aws_dynamodb_table.terraform_lock[0].name : ""
}

output "github_actions_role_arn" {
  description = "Role ARN for GitHub Actions OIDC"
  value       = aws_iam_role.github_actions.arn
}

output "backend_ecr_repository_url" {
  description = "Backend ECR repository URL"
  value       = aws_ecr_repository.backend.repository_url
}

output "frontend_ecr_repository_url" {
  description = "Frontend ECR repository URL"
  value       = aws_ecr_repository.frontend.repository_url
}
