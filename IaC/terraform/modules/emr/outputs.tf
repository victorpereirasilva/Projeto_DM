# Outputs do Módulo EMR

output "cluster_id" {
  description = "ID do cluster EMR (formato j-XXXXXXXX). É este valor, e não o nome, que o CloudWatch usa na dimensão JobFlowId."
  value       = aws_emr_cluster.emr_cluster.id
}

output "cluster_name" {
  description = "Nome do cluster EMR"
  value       = aws_emr_cluster.emr_cluster.name
}

output "master_security_group_id" {
  description = "ID do security group do nó principal"
  value       = aws_security_group.emr_main_sg.id
}
