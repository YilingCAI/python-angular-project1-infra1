variable "project_name" {
  description = "Project name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "ALB security group ID"
  type        = string
}

variable "app_port" {
  description = "Application port"
  type        = number
  default     = 8000
}

variable "frontend_port" {
  description = "Frontend container port"
  type        = number
  default     = 4200
}

variable "backend_path_patterns" {
  description = "Path patterns that should route to backend target group"
  type        = list(string)
  default     = ["/health", "/health/*", "/docs", "/docs/*", "/redoc", "/redoc/*", "/openapi.json", "/api/*"]
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/health"
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
  default     = ""
}
