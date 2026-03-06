variable "project_name" {
  description = "Project name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_id" {
  description = "ECS cluster ID"
  type        = string
}

variable "ecr_repository_url" {
  description = "Frontend ECR repository URL"
  type        = string
}

variable "image_tag" {
  description = "Frontend Docker image tag"
  type        = string
}

variable "frontend_port" {
  description = "Frontend container port"
  type        = number
  default     = 4200
}

variable "desired_count" {
  description = "Desired number of frontend tasks"
  type        = number
  default     = 1
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
  description = "ALB target group ARN for frontend service"
  type        = string
}
