# Outputs da raiz
#
# Depois do apply, estes valores são o que se precisa para operar o ambiente
# sem procurar nada no console: nomes de jobs para disparar à mão, o ID do
# cluster e o workgroup a selecionar no Athena.

output "bucket_data_lake" {
  description = "Bucket do Data Lake"
  value       = module.s3.bucket_id
}

output "emr_cluster_id" {
  description = "ID do cluster EMR, usado nas dimensões de métrica do CloudWatch"
  value       = module.emr.cluster_id
}

output "glue_workflow" {
  description = "Workflow a disparar para executar o pipeline fora do horário agendado"
  value       = module.glue.workflow_name
}

output "glue_crawlers" {
  description = "Crawlers das três camadas, na ordem em que devem rodar"
  value       = module.glue.crawler_names
}

output "glue_database" {
  description = "Banco do Glue Data Catalog a selecionar no Athena"
  value       = module.glue.database_name
}

output "athena_workgroup" {
  description = "Workgroup a selecionar no console do Athena antes da primeira consulta"
  value       = module.athena.workgroup_name
}

output "athena_output_location" {
  description = "Onde o Athena grava o resultado das consultas"
  value       = module.athena.output_location
}
