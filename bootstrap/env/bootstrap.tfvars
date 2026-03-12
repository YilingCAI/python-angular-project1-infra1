aws_region          = "us-east-1"
project_name        = "mypythonproject1"
expected_account_id = "891377039642"

environments = ["dev", "staging", "prod"]

# Keep names stable to match existing landing-zone resources.
state_bucket_names = {
  dev     = "mypythonproject1-tfstate-dev"
  staging = "mypythonproject1-tfstate-staging"
  prod    = "mypythonproject1-tfstate-prod"
}

github_actions_role_name = "GitHubActionsRole"

github_oidc_subjects = [
  "repo:YilingCAI/python-angular-project1-infra1:environment:dev",
  "repo:YilingCAI/python-angular-project1-infra1:environment:staging",
  "repo:YilingCAI/python-angular-project1-infra1:environment:prod",
  "repo:yilingcai/python-angular-project1-infra1:environment:dev",
  "repo:yilingcai/python-angular-project1-infra1:environment:staging",
  "repo:yilingcai/python-angular-project1-infra1:environment:prod",
  "repo:YilingCAI/python-angular-project1-infra1:ref:refs/heads/main",
  "repo:yilingcai/python-angular-project1-infra1:ref:refs/heads/main",
  "repo:YilingCAI/python-angular-project1-infra1:pull_request",
  "repo:yilingcai/python-angular-project1-infra1:pull_request"
]

oidc_thumbprints = [
  "6938fd4d98bab03faadb97b34396831e3780aea1"
]
