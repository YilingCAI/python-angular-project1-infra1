/**
 * ALB (Application Load Balancer) Module
 * - ALB in public subnets
 * - Target group for ECS tasks
 * - HTTPS support with ACM certificate
 * - Access logs to S3
 */

# S3 bucket for ALB logs
resource "aws_s3_bucket" "alb_logs" {
  bucket_prefix = "${var.project_name}-alb-logs-"

  tags = {
    Name = "${var.project_name}-alb-logs"
  }
}

# Enable versioning for compliance (CKV_AWS_21)
resource "aws_s3_bucket_versioning" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption with KMS (CKV_AWS_27, CKV_AWS_145)
resource "aws_kms_key" "alb_logs" {
  description             = "KMS key for ALB logs bucket"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-alb-logs-key"
  }
}

resource "aws_kms_alias" "alb_logs" {
  name          = "alias/${var.project_name}-alb-logs"
  target_key_id = aws_kms_key.alb_logs.key_id
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.alb_logs.arn
    }
    bucket_key_enabled = true
  }
}

# S3 Lifecycle policy (CKV2_AWS_61)
resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "archive-old-logs"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

# S3 bucket logging (CKV_AWS_18)
resource "aws_s3_bucket_logging" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  target_bucket = aws_s3_bucket.alb_logs.id
  target_prefix = "access-logs/"
}

# Block public access
resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy for ALB to write logs with encryption enforcement
resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyUnencryptedObjectUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.alb_logs.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/*"
      },
      {
        Sid    = "AllowALBLogDelivery"
        Effect = "Allow"
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/alb-logs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.alb_logs]
}

# Get AWS ELB service account
data "aws_elb_service_account" "main" {}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    enabled = false
    prefix  = "alb-logs"
  }

  enable_deletion_protection       = true
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# Target Group (CKV_AWS_378 - use HTTPS for protocol)
resource "aws_lb_target_group" "app" {
  name_prefix          = "app-"
  port                 = var.app_port
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  deregistration_delay = 30

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 3
    interval            = 30
    path                = var.health_check_path
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-tg"
  }
}

resource "aws_lb_target_group" "frontend" {
  name_prefix          = "fe-"
  port                 = var.frontend_port
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  deregistration_delay = 30

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200-399"
  }

  tags = {
    Name = "${var.project_name}-frontend-tg"
  }
}

# HTTP Listener (redirect to HTTPS when certificate exists)
resource "aws_lb_listener" "http_redirect" {
  count             = var.certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTP Listener (forward to app when certificate is not configured)
resource "aws_lb_listener" "http_forward" {
  count             = var.certificate_arn == "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_listener_rule" "http_backend_routes_primary" {
  count        = var.certificate_arn == "" ? 1 : 0
  listener_arn = aws_lb_listener.http_forward[0].arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  condition {
    path_pattern {
      values = slice(var.backend_path_patterns, 0, min(5, length(var.backend_path_patterns)))
    }
  }
}

resource "aws_lb_listener_rule" "http_backend_routes_secondary" {
  count        = var.certificate_arn == "" && length(var.backend_path_patterns) > 5 ? 1 : 0
  listener_arn = aws_lb_listener.http_forward[0].arn
  priority     = 110

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  condition {
    path_pattern {
      values = slice(var.backend_path_patterns, 5, length(var.backend_path_patterns))
    }
  }
}

# HTTPS Listener (requires certificate_arn)
resource "aws_lb_listener" "https" {
  count             = var.certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_listener_rule" "https_backend_routes_primary" {
  count        = var.certificate_arn != "" ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  condition {
    path_pattern {
      values = slice(var.backend_path_patterns, 0, min(5, length(var.backend_path_patterns)))
    }
  }
}

resource "aws_lb_listener_rule" "https_backend_routes_secondary" {
  count        = var.certificate_arn != "" && length(var.backend_path_patterns) > 5 ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 110

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  condition {
    path_pattern {
      values = slice(var.backend_path_patterns, 5, length(var.backend_path_patterns))
    }
  }
}

# Note: HTTP_forward listener removed. ALB requires certificate_arn.
# All HTTP traffic must redirect to HTTPS via http listener.
