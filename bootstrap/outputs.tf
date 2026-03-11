output "state_bucket_names" {
  description = "Terraform state bucket names by environment"
  value       = { for env, b in aws_s3_bucket.terraform_state : env => b.bucket }
}

output "state_bucket_arns" {
  description = "Terraform state bucket ARNs by environment"
  value       = { for env, b in aws_s3_bucket.terraform_state : env => b.arn }
}

output "github_actions_role_arn" {
  description = "Shared IAM role ARN for GitHub Actions OIDC deployments"
  value       = aws_iam_role.github_actions.arn
}

output "github_actions_role_name" {
  description = "Shared IAM role name for GitHub Actions"
  value       = aws_iam_role.github_actions.name
}

output "github_oidc_provider_arn" {
  description = "GitHub OIDC provider ARN"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "backend_ecr_repository_url" {
  description = "Backend ECR repository URL"
  value       = aws_ecr_repository.backend.repository_url
}

output "frontend_ecr_repository_url" {
  description = "Frontend ECR repository URL"
  value       = aws_ecr_repository.frontend.repository_url
}
