variable "project_name" {
  description = "Project name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "ecr_repository_url" {
  description = "ECR repository URL"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "app_port" {
  description = "Application port"
  type        = number
  default     = 8000
}

variable "task_cpu" {
  description = "ECS task CPU (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "512"
}

variable "task_memory" {
  description = "ECS task memory (512, 1024, 2048, 3072, 4096, etc.)"
  type        = string
  default     = "1024"
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Minimum number of tasks"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum number of tasks"
  type        = number
  default     = 10
}

variable "target_cpu_utilization" {
  description = "Target CPU utilization for auto-scaling"
  type        = number
  default     = 70
}

variable "target_memory_utilization" {
  description = "Target memory utilization for auto-scaling"
  type        = number
  default     = 80
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "ECS tasks security group ID"
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN"
  type        = string
}

variable "db_secret_arn" {
  description = "RDS database secret ARN"
  type        = string
}

variable "jwt_secret_arn" {
  description = "JWT secret ARN"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for secret decryption"
  type        = string
}

variable "db_kms_key_arn" {
  description = "KMS key ARN used to encrypt DB secret"
  type        = string
}

variable "debug" {
  description = "Enable debug mode"
  type        = bool
  default     = false
}

variable "jwt_algorithm" {
  description = "JWT algorithm"
  type        = string
  default     = "HS256"
}

variable "jwt_expire_minutes" {
  description = "JWT expiration time in minutes"
  type        = number
  default     = 60
}
