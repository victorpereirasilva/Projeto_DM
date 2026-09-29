# Outputs do Módulo Glue

output "database_name" {
  description = "Nome do banco no Glue Data Catalog, consultado pelo Athena"
  value       = aws_glue_catalog_database.projeto_dm_db.name
}

output "workflow_name" {
  description = "Nome do workflow que encadeia o ETL e a curadoria"
  value       = aws_glue_workflow.pipeline_workflow.name
}

output "etl_job_name" {
  description = "Nome do job de ETL (RAW -> PROCESSED)"
  value       = aws_glue_job.etl_job.name
}

output "curated_job_name" {
  description = "Nome do job de curadoria (PROCESSED -> CURATED)"
  value       = aws_glue_job.curated_job.name
}

output "crawler_names" {
  description = "Crawlers das três camadas, na ordem em que devem rodar"
  value = [
    aws_glue_crawler.raw_crawler.name,
    aws_glue_crawler.processed_crawler.name,
    aws_glue_crawler.curated_crawler.name,
  ]
}
