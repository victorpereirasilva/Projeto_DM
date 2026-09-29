# Outputs do Módulo S3

output "bucket_id" {
  description = "ID do bucket principal"
  value       = aws_s3_bucket.main_bucket.id
}

output "bucket_arn" {
  description = "ARN do bucket principal"
  value       = aws_s3_bucket.main_bucket.arn
}

output "metrics_filter_id" {
  description = "ID do filtro de métricas de requisição da camada RAW, consumido pelo alarme de ausência de ingestão"
  value       = aws_s3_bucket_metric.raw_layer_metrics.name
}
