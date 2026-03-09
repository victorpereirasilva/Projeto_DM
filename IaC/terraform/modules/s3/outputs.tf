# Outputs do Módulo S3

output "bucket_id" {
  description = "ID do bucket principal"
  value       = aws_s3_bucket.main_bucket.id
}

output "bucket_arn" {
  description = "ARN do bucket principal"
  value       = aws_s3_bucket.main_bucket.arn
}
