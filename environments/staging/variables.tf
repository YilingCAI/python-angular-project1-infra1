variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "mypythonproject1"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# Networking
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "database_subnet_cidrs" {
  description = "Database subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "app_port" {
  description = "Application port"
  type        = number
  default     = 8000
}

# RDS Configuration
variable "db_name" {
  description = "Database name"
  type        = string
  default     = "gamedb"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "postgres"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.1"
}

variable "db_instance_class" {
  description = "Database instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage for auto-scaling"
  type        = number
  default     = 100
}

variable "backup_retention_days" {
  description = "Backup retention period"
  type        = number
  default     = 30
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = true
}

# ECS Configuration
variable "ecr_repository_url" {
  description = "ECR repository URL"
  type        = string
}

variable "frontend_ecr_repository_url" {
  description = "Frontend ECR repository URL (optional; defaults by replacing /backend with /frontend)"
  type        = string
  default     = ""
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "frontend_image_tag" {
  description = "Frontend Docker image tag (optional; defaults to image_tag)"
  type        = string
  default     = ""
}

variable "frontend_port" {
  description = "Frontend container port"
  type        = number
  default     = 4200
}

variable "task_cpu" {
  description = "ECS task CPU units"
  type        = string
  default     = "512"
}

variable "task_memory" {
  description = "ECS task memory in MB"
  type        = string
  default     = "1024"
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "frontend_desired_count" {
  description = "Desired number of frontend ECS tasks"
  type        = number
  default     = 1
}

variable "min_capacity" {
  description = "Minimum number of ECS tasks"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum number of ECS tasks"
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

# ALB Configuration
variable "health_check_path" {
  description = "ALB health check path"
  type        = string
  default     = "/health"
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
  default     = ""
}

# Security & JWT
variable "jwt_secret_key" {
  description = "JWT secret key"
  type        = string
  sensitive   = true
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

variable "enable_secret_rotation" {
  description = "Enable Secrets Manager automatic rotation resources (requires Lambda rotation function integration)"
  type        = bool
  default     = false
}

# Logging
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

# Debug
variable "debug" {
  description = "Enable debug mode"
  type        = bool
  default     = false
}
