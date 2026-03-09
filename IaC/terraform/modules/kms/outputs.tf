# Outputs do Módulo KMS

output "kms_key_arn" {
  description = "ARN da chave KMS para uso nos outros módulos"
  value       = aws_kms_key.s3_kms_key.arn
}

output "kms_key_id" {
  description = "ID da chave KMS"
  value       = aws_kms_key.s3_kms_key.key_id
}
