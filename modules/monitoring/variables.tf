variable "project_name" {
  description = "Project name (used for resource naming)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "ecs_service_name" {
  description = "ECS backend service name"
  type        = string
}

variable "frontend_service_name" {
  description = "ECS frontend service name"
  type        = string
}

variable "db_instance_identifier" {
  description = "RDS DB instance identifier"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix (for CloudWatch alarm and dashboard dimensions)"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name for the backend ECS service"
  type        = string
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications (empty = skip SNS subscription)"
  type        = string
  default     = ""
}

# ─── Alarm thresholds ─────────────────────────────────────────────────────────
variable "ecs_cpu_threshold" {
  description = "ECS CPU utilization alarm threshold (%)"
  type        = number
  default     = 80
}

variable "ecs_memory_threshold" {
  description = "ECS memory utilization alarm threshold (%)"
  type        = number
  default     = 85
}

variable "rds_cpu_threshold" {
  description = "RDS CPU utilization alarm threshold (%)"
  type        = number
  default     = 80
}

variable "rds_free_storage_threshold" {
  description = "RDS free storage alarm threshold in bytes (default: 5 GB)"
  type        = number
  default     = 5368709120
}

variable "rds_connections_threshold" {
  description = "RDS database connections alarm threshold"
  type        = number
  default     = 100
}

variable "alb_5xx_threshold" {
  description = "ALB 5XX error count alarm threshold (per minute)"
  type        = number
  default     = 10
}

variable "alb_latency_threshold" {
  description = "ALB p95 response time alarm threshold in seconds"
  type        = number
  default     = 2
}
