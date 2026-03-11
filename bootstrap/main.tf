data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  account_id         = data.aws_caller_identity.current.account_id
  backend_repo_name  = "${var.project_name}/backend"
  frontend_repo_name = "${var.project_name}/frontend"
  project_slug       = replace(lower(var.project_name), "_", "-")
  state_bucket_names = {
    for env in var.environments :
    env => lookup(var.state_bucket_names, env, "") != "" ? lookup(var.state_bucket_names, env, "") : "${local.project_slug}-tfstate-${env}-${local.account_id}"
  }

  ecr_actions = ["ecr:*"]

  infra_actions = [
    "ecs:*",
    "ec2:*",
    "elasticloadbalancing:*",
    "logs:*",
    "cloudwatch:*",
    "secretsmanager:*",
    "kms:*",
    "rds:*"
  ]

  state_bucket_actions = [
    "s3:DeleteObject",
    "s3:GetBucketEncryption",
    "s3:GetBucketLocation",
    "s3:GetBucketVersioning",
    "s3:GetObject",
    "s3:ListBucket",
    "s3:PutBucketEncryption",
    "s3:PutBucketVersioning",
    "s3:PutObject"
  ]

  github_oidc_provider_arn = aws_iam_openid_connect_provider.github.arn
}

resource "aws_s3_bucket" "terraform_state" {
  for_each = local.state_bucket_names
  bucket   = each.value

  tags = {
    Name        = each.value
    Environment = each.key
    Purpose     = "terraform-state"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  for_each = aws_s3_bucket.terraform_state
  bucket   = each.value.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  for_each = aws_s3_bucket.terraform_state
  bucket   = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  for_each = aws_s3_bucket.terraform_state
  bucket   = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_ecr_repository" "backend" {
  name                 = local.backend_repo_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_repository" "frontend" {
  name                 = local.frontend_repo_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = var.oidc_thumbprints
}

data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect = "Allow"

    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.github_oidc_subjects
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name                 = var.github_actions_role_name
  max_session_duration = 3600
  assume_role_policy   = data.aws_iam_policy_document.github_actions_trust.json

  tags = {
    Name    = var.github_actions_role_name
    Scope   = "shared"
    Purpose = "cicd"
  }
}

data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    sid     = "ECR"
    effect  = "Allow"
    actions = local.ecr_actions
    resources = [
      aws_ecr_repository.backend.arn,
      aws_ecr_repository.frontend.arn,
      "arn:${data.aws_partition.current.partition}:ecr:${var.aws_region}:${local.account_id}:repository/${local.backend_repo_name}",
      "arn:${data.aws_partition.current.partition}:ecr:${var.aws_region}:${local.account_id}:repository/${local.frontend_repo_name}"
    ]
  }

  statement {
    sid       = "ECRAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid       = "ECSAndInfraDeploy"
    effect    = "Allow"
    actions   = local.infra_actions
    resources = ["*"]
  }
  statement {
    sid       = "BucketAccess"
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]
  }
  statement {
    sid     = "StateBucket"
    effect  = "Allow"
    actions = local.state_bucket_actions
    resources = concat(
      [for bucket in values(aws_s3_bucket.terraform_state) : bucket.arn],
      [for bucket in values(aws_s3_bucket.terraform_state) : "${bucket.arn}/*"]
    )
  }

  statement {
    sid    = "PassRole"
    effect = "Allow"
    actions = [
      "iam:PassRole",
      "iam:GetRole",
      "iam:CreateServiceLinkedRole",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:TagRole",
      "iam:GetRolePolicy"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "GitHubActionsPolicy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}
