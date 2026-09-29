# Outputs do Módulo Athena

output "workgroup_name" {
  description = "Nome do workgroup a ser selecionado no console do Athena"
  value       = aws_athena_workgroup.projeto_dm.name
}

output "output_location" {
  description = "Prefixo S3 onde o Athena grava o resultado das consultas"
  value       = "s3://${var.name_bucket}/athena-results/"
}
