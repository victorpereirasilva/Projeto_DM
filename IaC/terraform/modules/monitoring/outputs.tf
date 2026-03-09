# Outputs do Módulo Monitoring

output "sns_topic_arn" {
  description = "ARN do tópico SNS de alertas"
  value       = aws_sns_topic.alertas_pipeline.arn
}

output "cloudtrail_arn" {
  description = "ARN do CloudTrail de auditoria"
  value       = aws_cloudtrail.data_lake_trail.arn
}
