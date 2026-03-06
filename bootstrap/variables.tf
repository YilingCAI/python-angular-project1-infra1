variable "aws_region" {
  description = "AWS region for bootstrap resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "mypythonproject1"
}

variable "github_org" {
  description = "GitHub organization/user name"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "github_actions_role_name" {
  description = "IAM role name assumed by GitHub Actions via OIDC"
  type        = string
  default     = "GitHubActionsRole"
}

variable "github_environments" {
  description = "Deprecated: previously used for environment-based OIDC trust"
  type        = list(string)
  default     = ["staging", "production"]
}

variable "github_oidc_subjects" {
  description = "Allowed OIDC subject claims. Default restricts to repo main branch ref. Example: repo:ORG/REPO:ref:refs/heads/main"
  type        = list(string)
  default     = []
}

variable "state_bucket_name" {
  description = "Override for Terraform state bucket name; empty uses terraform-state-<account-id>"
  type        = string
  default     = ""
}

variable "lock_table_name" {
  description = "DynamoDB lock table name (legacy compatibility)"
  type        = string
  default     = "terraform-locks"
}

variable "create_lock_table" {
  description = "Create DynamoDB lock table for backward compatibility"
  type        = bool
  default     = true
}

variable "oidc_thumbprints" {
  description = "Thumbprints for GitHub OIDC provider"
  type        = list(string)
  default     = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}
