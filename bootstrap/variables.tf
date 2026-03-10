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

variable "expected_account_id" {
  description = "Expected AWS account ID for bootstrap operations. Leave empty to disable Terraform-side account check."
  type        = string
  default     = ""

  validation {
    condition     = var.expected_account_id == "" || can(regex("^[0-9]{12}$", var.expected_account_id))
    error_message = "expected_account_id must be empty or a 12-digit AWS account ID."
  }
}

variable "environments" {
  description = "Environment names to bootstrap in one run"
  type        = set(string)
  default     = ["dev", "staging", "prod"]
}

variable "github_actions_role_name" {
  description = "Shared IAM role name assumed by GitHub Actions via OIDC"
  type        = string
  default     = "GitHubActionsRole"
}

variable "github_oidc_subjects" {
  description = "Allowed OIDC subject claims for GitHub OIDC trust. Example: repo:ORG/REPO:ref:refs/heads/main"
  type        = list(string)

  validation {
    condition     = length(var.github_oidc_subjects) > 0
    error_message = "github_oidc_subjects must include at least one allowed OIDC subject claim."
  }
}

variable "state_bucket_names" {
  description = "Optional per-environment state bucket name overrides"
  type        = map(string)
  default     = {}
}

variable "oidc_thumbprints" {
  description = "Thumbprints for GitHub OIDC provider"
  type        = list(string)
  default     = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}
