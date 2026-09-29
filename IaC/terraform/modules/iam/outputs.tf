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

output "emr_ec2_role_arn" {
  description = "ARN da role assumida pelas instâncias EC2 do EMR (é ela que o Spark usa para acessar o S3 e a chave KMS)"
  value       = aws_iam_role.emr_ec2_role.arn
}

output "firehose_role_arn" {
  description = "ARN da role assumida pelo Kinesis Data Firehose"
  value       = aws_iam_role.firehose_role.arn
}

output "todas_as_roles_arns" {
  description = "Lista com todas as roles do projeto que precisam usar a chave KMS"
  value = [
    aws_iam_role.emr_ec2_role.arn,
    aws_iam_role.emr_service_role.arn,
    aws_iam_role.glue_service_role.arn,
    aws_iam_role.firehose_role.arn
  ]
}
