output "sns_topic_arn" {
  description = "SNS topic ARN for monitoring alerts"
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "alarm_arns" {
  description = "Map of all CloudWatch alarm ARNs"
  value = {
    ecs_cpu_high             = aws_cloudwatch_metric_alarm.ecs_cpu_high.arn
    ecs_memory_high          = aws_cloudwatch_metric_alarm.ecs_memory_high.arn
    ecs_frontend_cpu_high    = aws_cloudwatch_metric_alarm.ecs_frontend_cpu_high.arn
    ecs_frontend_memory_high = aws_cloudwatch_metric_alarm.ecs_frontend_memory_high.arn
    rds_cpu_high             = aws_cloudwatch_metric_alarm.rds_cpu_high.arn
    rds_free_storage_low     = aws_cloudwatch_metric_alarm.rds_free_storage_low.arn
    rds_connections_high     = aws_cloudwatch_metric_alarm.rds_connections_high.arn
    alb_5xx_high             = aws_cloudwatch_metric_alarm.alb_5xx_high.arn
    alb_latency_high         = aws_cloudwatch_metric_alarm.alb_latency_high.arn
  }
}
