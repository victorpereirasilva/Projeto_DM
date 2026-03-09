# Outputs do Módulo Glue

output "glue_database_name" {
  description = "Nome do banco de dados no Glue Data Catalog"
  value       = aws_glue_catalog_database.projeto_dm_db.name
}

output "etl_job_name" {
  description = "Nome do job ETL principal"
  value       = aws_glue_job.etl_job.name
}

output "workflow_name" {
  description = "Nome do workflow de orquestração"
  value       = aws_glue_workflow.pipeline_workflow.name
}
