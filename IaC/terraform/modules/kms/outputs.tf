# Outputs do Módulo KMS

output "kms_key_arn" {
  description = "ARN da chave que criptografa o Data Lake e o stream do Kinesis"
  value       = aws_kms_key.s3_kms_key.arn
}

output "kms_key_id" {
  description = "ID da chave KMS"
  value       = aws_kms_key.s3_kms_key.key_id
}

output "kms_alias" {
  description = "Alias da chave, usado para localizá-la no console"
  value       = aws_kms_alias.s3_kms_key_alias.name
}
