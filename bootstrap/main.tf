data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  account_id         = data.aws_caller_identity.current.account_id
  effective_bucket   = var.state_bucket_name != "" ? var.state_bucket_name : "terraform-state-${local.account_id}"
  backend_repo_name  = "${var.project_name}/backend"
  frontend_repo_name = "${var.project_name}/frontend"
  oidc_subjects      = length(var.github_oidc_subjects) > 0 ? var.github_oidc_subjects : ["repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"]
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = local.effective_bucket

  tags = {
    Name    = local.effective_bucket
    Purpose = "terraform-state"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_lock" {
  count        = var.create_lock_table ? 1 : 0
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name    = var.lock_table_name
    Purpose = "terraform-lock-legacy"
  }
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
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.oidc_subjects
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = var.github_actions_role_name
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
}

data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    sid     = "ECR"
    effect  = "Allow"
    actions = ["ecr:*"]
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
    sid    = "ECSAndInfraDeploy"
    effect = "Allow"
    actions = [
      "ecs:*",
      "ec2:*",
      "elasticloadbalancing:*",
      "logs:*",
      "cloudwatch:*",
      "secretsmanager:*",
      "kms:*",
      "rds:*"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "StateBucket"
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.terraform_state.arn,
      "${aws_s3_bucket.terraform_state.arn}/*"
    ]
  }

  statement {
    sid       = "LegacyLockTable"
    effect    = "Allow"
    actions   = ["dynamodb:*"]
    resources = var.create_lock_table ? [aws_dynamodb_table.terraform_lock[0].arn] : ["*"]
  }

  statement {
    sid       = "PassRole"
    effect    = "Allow"
    actions   = ["iam:PassRole", "iam:GetRole", "iam:CreateServiceLinkedRole"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "GitHubActionsPolicy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}
