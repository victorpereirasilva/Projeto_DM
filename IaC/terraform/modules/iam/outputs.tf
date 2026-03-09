# Outputs do Módulo IAM

output "instance_profile" {
  description = "Nome do perfil de instância para o EMR"
  value       = aws_iam_instance_profile.emr_instance_profile.name
}

output "service_role" {
  description = "ARN da role de serviço do EMR"
  value       = aws_iam_role.emr_service_role.arn
}

output "glue_role_arn" {
  description = "ARN da role de serviço do Glue"
  value       = aws_iam_role.glue_service_role.arn
}
