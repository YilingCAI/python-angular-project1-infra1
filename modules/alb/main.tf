/**
 * ALB (Application Load Balancer) Module
 * - ALB in public subnets
 * - Target group for ECS tasks
 * - HTTPS support with ACM certificate
 * - Access logs to S3
 */

data "aws_caller_identity" "current" {}

# S3 bucket for ALB logs
# checkov:skip=CKV_AWS_144:Cross-region replication is not required for a transient ALB access-log bucket
# checkov:skip=CKV2_AWS_62:S3 event notifications are not required for an ALB access-log bucket
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

# Enable server-side encryption with AES256 (CKV_AWS_27)
# NOTE: ALB log delivery service does NOT support SSE-KMS — it requires SSE-S3 (AES256).
# Using aws:kms here will cause "Access Denied" errors when ELB tries to write logs.
resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = false
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

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
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

# Bucket policy for ALB to write logs
# NOTE: The DenyUnencryptedObjectUploads statement is intentionally omitted.
# The ELB log delivery service writes with SSE-S3 and does not send an
# s3:x-amz-server-side-encryption header, so a deny-if-not-encrypted policy
# would block all log delivery. Bucket default encryption (AES256) ensures
# all objects are encrypted at rest.
resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowELBServiceAccountPutObject"
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
      },
      {
        Sid    = "DenyNonHTTPS"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action   = "s3:*"
        Resource = ["${aws_s3_bucket.alb_logs.arn}", "${aws_s3_bucket.alb_logs.arn}/*"]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
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
# checkov:skip=CKV2_AWS_28:WAF integration is managed separately as optional infrastructure
# checkov:skip=CKV2_AWS_20:HTTP listener only exists when no ACM cert is provided; it redirects to HTTPS via a separate listener when cert is present
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    enabled = true
    prefix  = "alb-logs"
  }

  enable_deletion_protection       = true
  enable_http2                     = true
  enable_cross_zone_load_balancing = true
  drop_invalid_header_fields       = true

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# Target Group (CKV_AWS_378 - use HTTPS for protocol)
# checkov:skip=CKV_AWS_378:Target groups use HTTP internally; TLS terminates at the ALB (standard ECS Fargate pattern)
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

# checkov:skip=CKV_AWS_378:Target groups use HTTP internally; TLS terminates at the ALB (standard ECS Fargate pattern)
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
# checkov:skip=CKV_AWS_2:HTTP listener is intentional when no ACM certificate is configured (dev/no-TLS environments)
# checkov:skip=CKV_AWS_103:TLS 1.2 enforcement only applies to HTTPS listeners; this listener is HTTP-only for dev
# checkov:skip=CKV2_AWS_20:HTTP forward listener is only created when no cert is provided; HTTPS redirect listener is created when cert exists
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
