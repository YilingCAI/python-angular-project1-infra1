output "service_name" {
  description = "Frontend ECS service name"
  value       = aws_ecs_service.frontend.name
}

output "task_definition_arn" {
  description = "Frontend task definition ARN"
  value       = aws_ecs_task_definition.frontend.arn
}
