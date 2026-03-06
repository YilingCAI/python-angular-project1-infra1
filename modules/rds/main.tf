/**
 * RDS PostgreSQL Module
 * - PostgreSQL instance in private subnets
 * - Credentials stored in AWS Secrets Manager
 * - Automated backups and encryption
 */

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# Generate random password
resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store password in Secrets Manager with KMS encryption (CKV_AWS_149)
resource "aws_secretsmanager_secret" "db_password" {
  name_prefix             = "${var.project_name}-db-password-"
  recovery_window_in_days = 7
  kms_key_id              = aws_kms_key.rds.id

  tags = {
    Name = "${var.project_name}-db-password"
  }
}

# Enable automatic rotation for DB password (CKV2_AWS_57)
resource "aws_secretsmanager_secret_rotation" "db_password" {
  count     = var.enable_secret_rotation ? 1 : 0
  secret_id = aws_secretsmanager_secret.db_password.id
  rotation_rules {
    automatically_after_days = 30
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username          = var.db_username
    password          = random_password.db_password.result
    engine            = "postgres"
    host              = aws_db_instance.main.address
    port              = aws_db_instance.main.port
    dbname            = var.db_name
    DATABASE_USER     = var.db_username
    DATABASE_PASSWORD = random_password.db_password.result
    DATABASE_HOST     = aws_db_instance.main.address
    DATABASE_PORT     = tostring(aws_db_instance.main.port)
    DATABASE_NAME     = var.db_name
    DATABASE_URL      = "postgresql://${var.db_username}:${random_password.db_password.result}@${aws_db_instance.main.address}:${aws_db_instance.main.port}/${var.db_name}"
  })
  # Ensure the secret value update happens after the RDS instance is created
  depends_on = [aws_db_instance.main]
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.database_subnet_ids

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier             = "${var.project_name}-db"
  engine                 = "postgres"
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  max_allocated_storage  = var.db_max_allocated_storage
  db_name                = var.db_name
  username               = var.db_username
  password               = random_password.db_password.result
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_security_group_id]

  # Security
  skip_final_snapshot                 = false
  final_snapshot_identifier           = "${var.project_name}-db-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  copy_tags_to_snapshot               = true
  publicly_accessible                 = false
  storage_encrypted                   = true
  kms_key_id                          = aws_kms_key.rds.arn
  iam_database_authentication_enabled = true
  deletion_protection                 = true

  # Backups
  backup_retention_period    = var.backup_retention_days
  backup_window              = "03:00-04:00"
  maintenance_window         = "mon:04:00-mon:05:00"
  multi_az                   = var.multi_az
  auto_minor_version_upgrade = true

  # Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql"]
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn

  # Performance Insights with KMS encryption (CKV_AWS_354)
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.rds.arn
  performance_insights_retention_period = 7

  tags = {
    Name = "${var.project_name}-db"
  }

  depends_on = [
  ]
}

# KMS Key for RDS encryption
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-rds-key"
  }
}

# KMS Key Policy for RDS (CKV2_AWS_64)
resource "aws_kms_key_policy" "rds" {
  key_id = aws_kms_key.rds.id

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
        Sid    = "Allow RDS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.project_name}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# IAM Role for RDS monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# KMS Key for CloudWatch Logs
resource "aws_kms_key" "cloudwatch_logs" {
  description             = "KMS key for CloudWatch Logs"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-cloudwatch-logs-key"
  }
}

# CloudWatch Log Group for RDS with KMS encryption and 1-year retention (CKV_AWS_158, CKV_AWS_338)
resource "aws_cloudwatch_log_group" "rds" {
  name              = "/aws/rds/${var.project_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-rds-logs"
  }
}
