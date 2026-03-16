/**
 * Main Terraform Configuration
 * Orchestrates all modules: network, RDS, ALB, and ECS
 */

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Partial S3 backend configuration — all values injected at `terraform init` time
  # via -backend-config flags in CI workflows (staging.yml / release.yml).
  # This allows the same code to target staging and production state buckets
  # without storing bucket names or keys in version control.
  #
  # Example init command (run in CI):
  #   terraform init \
  #     -backend-config="bucket=$TERRAFORM_STATE_BUCKET" \
  #     -backend-config="key=<environment>/terraform.tfstate" \
  #     -backend-config="region=$AWS_REGION" \
  #     -backend-config="use_lockfile=true"
  #
  # Local development: run `terraform init -backend=false` to skip remote state.
  backend "s3" {
    encrypt = true
  }
}

data "aws_caller_identity" "current" {}

locals {
  frontend_ecr_repository_url = var.frontend_ecr_repository_url != "" ? var.frontend_ecr_repository_url : replace(var.ecr_repository_url, "/backend", "/frontend")
  frontend_image_tag          = var.frontend_image_tag != "" ? var.frontend_image_tag : var.image_tag
}

# Networking Module
module "network" {
  source = "../../modules/vpc"

  project_name          = var.project_name
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs
  app_port              = var.app_port
  frontend_port         = var.frontend_port
}

# RDS Module
module "rds" {
  source = "../../modules/rds"

  project_name             = var.project_name
  database_subnet_ids      = module.network.database_subnet_ids
  rds_security_group_id    = module.network.rds_security_group_id
  db_name                  = var.db_name
  db_username              = var.db_username
  db_engine_version        = var.db_engine_version
  db_instance_class        = var.db_instance_class
  db_allocated_storage     = var.db_allocated_storage
  db_max_allocated_storage = var.db_max_allocated_storage
  backup_retention_days    = var.backup_retention_days
  multi_az                 = var.multi_az
  log_retention_days       = var.log_retention_days
  enable_secret_rotation   = var.enable_secret_rotation
}

# ALB Module
module "alb" {
  source = "../../modules/alb"

  project_name          = var.project_name
  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  alb_security_group_id = module.network.alb_security_group_id
  app_port              = var.app_port
  frontend_port         = var.frontend_port
  health_check_path     = var.health_check_path
  certificate_arn       = var.certificate_arn
}

# JWT Secret in Secrets Manager (referenced by ECS)
# checkov:skip=CKV2_AWS_57:Automatic rotation requires a Lambda rotation function which is managed separately
resource "aws_secretsmanager_secret" "jwt_secret" {
  name_prefix             = "${var.project_name}-jwt-secret-"
  recovery_window_in_days = 7
  kms_key_id              = aws_kms_key.secrets.id

  tags = {
    Name = "${var.project_name}-jwt-secret"
  }
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id = aws_secretsmanager_secret.jwt_secret.id
  secret_string = jsonencode({
    JWT_SECRET_KEY = var.jwt_secret_key
  })
}

# KMS Key for secrets
resource "aws_kms_key" "secrets" {
  description             = "KMS key for Secrets Manager"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-secrets-key"
  }
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.project_name}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

# KMS Key Policy for Secrets Manager encryption (CKV_AWS_33)
resource "aws_kms_key_policy" "secrets" {
  key_id = aws_kms_key.secrets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Secrets Manager to use the key"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${var.aws_region}.amazonaws.com"
          }
        }
      },
      {
        Sid    = "Allow ECS Task Execution Role to decrypt secrets"
        Effect = "Allow"
        Principal = {
          AWS = module.ecs.task_execution_role_arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

# ECS Module
module "ecs" {
  source = "../../modules/ecs-service"

  project_name              = var.project_name
  aws_region                = var.aws_region
  ecr_repository_url        = var.ecr_repository_url
  image_tag                 = var.image_tag
  app_port                  = var.app_port
  task_cpu                  = var.task_cpu
  task_memory               = var.task_memory
  desired_count             = var.desired_count
  min_capacity              = var.min_capacity
  max_capacity              = var.max_capacity
  target_cpu_utilization    = var.target_cpu_utilization
  target_memory_utilization = var.target_memory_utilization
  log_retention_days        = var.log_retention_days
  private_subnet_ids        = module.network.private_subnet_ids
  ecs_security_group_id     = module.network.ecs_tasks_security_group_id
  target_group_arn          = module.alb.target_group_arn
  db_secret_arn             = module.rds.secret_arn
  jwt_secret_arn            = aws_secretsmanager_secret.jwt_secret.arn
  kms_key_arn               = aws_kms_key.secrets.arn
  db_kms_key_arn            = module.rds.kms_key_arn
  debug                     = var.debug
  jwt_algorithm             = var.jwt_algorithm
  jwt_expire_minutes        = var.jwt_expire_minutes

  depends_on = [module.alb]
}

module "ecs_frontend" {
  source = "../../modules/iam"

  project_name          = var.project_name
  aws_region            = var.aws_region
  cluster_id            = module.ecs.cluster_id
  ecr_repository_url    = local.frontend_ecr_repository_url
  image_tag             = local.frontend_image_tag
  frontend_port         = var.frontend_port
  desired_count         = var.frontend_desired_count
  private_subnet_ids    = module.network.private_subnet_ids
  ecs_security_group_id = module.network.ecs_tasks_security_group_id
  target_group_arn      = module.alb.frontend_target_group_arn
}

module "monitoring" {
  source = "../../modules/monitoring"

  project_name           = var.project_name
  aws_region             = var.aws_region
  cluster_name           = module.ecs.cluster_name
  ecs_service_name       = module.ecs.service_name
  frontend_service_name  = module.ecs_frontend.service_name
  db_instance_identifier = "${var.project_name}-db"
  alb_arn_suffix         = module.alb.alb_arn_suffix
  log_group_name         = module.ecs.log_group_name
  alert_email            = var.alert_email
  ecs_cpu_threshold      = var.ecs_cpu_threshold
  ecs_memory_threshold   = var.ecs_memory_threshold
  rds_cpu_threshold      = var.rds_cpu_threshold

  depends_on = [module.ecs, module.ecs_frontend, module.rds, module.alb]
}
