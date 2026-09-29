# Módulo de ETL - AWS Glue

# -------------------------------------------------------------------
# GLUE DATA CATALOG - Catálogo centralizado de tabelas
# -------------------------------------------------------------------

# Banco de dados no Glue Data Catalog
resource "aws_glue_catalog_database" "projeto_dm_db" {

  # Nome do banco de dados no catálogo
  name        = var.glue_db_name
  description = "Catálogo de dados do Projeto DM - Data Lake"
}

# -------------------------------------------------------------------
# GLUE CRAWLERS - Descoberta automática do schema dos dados
# -------------------------------------------------------------------

# Crawler para a camada RAW
resource "aws_glue_crawler" "raw_crawler" {

  # Nome do crawler
  name          = "projeto-dm-raw-crawler"
  database_name = aws_glue_catalog_database.projeto_dm_db.name
  role          = var.iam_role_arn
  description   = "Descobre e cataloga dados brutos da camada RAW"

  # Origem dos dados: camada RAW do S3
  s3_target {
    path = "s3://${var.name_bucket}/raw/"
  }

  # Agendamento: executa diariamente às 02:00 UTC
  schedule = "cron(0 2 * * ? *)"

  # Atualiza o schema ao detectar mudanças
  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  tags = {
    Project = "projeto-dm"
    Layer   = "raw"
  }
}

# Crawler para a camada PROCESSED
resource "aws_glue_crawler" "processed_crawler" {

  # Nome do crawler
  name          = "projeto-dm-processed-crawler"
  database_name = aws_glue_catalog_database.projeto_dm_db.name
  role          = var.iam_role_arn
  description   = "Descobre e cataloga dados limpos da camada PROCESSED"

  # Origem dos dados: camada PROCESSED do S3
  s3_target {
    path = "s3://${var.name_bucket}/processed/"
  }

  # Agendamento: executa diariamente às 04:00 UTC (após o ETL)
  schedule = "cron(0 4 * * ? *)"

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  tags = {
    Project = "projeto-dm"
    Layer   = "processed"
  }
}

# Crawler para a camada CURATED
resource "aws_glue_crawler" "curated_crawler" {

  # Nome do crawler
  name          = "projeto-dm-curated-crawler"
  database_name = aws_glue_catalog_database.projeto_dm_db.name
  role          = var.iam_role_arn
  description   = "Descobre e cataloga dados prontos para consumo na camada CURATED"

  # Origem dos dados: os conjuntos analíticos da camada CURATED.
  # curated/models/ fica de fora de propósito — são modelos serializados do
  # Spark ML, não tabelas; catalogá-los só poluiria o Data Catalog.
  s3_target {
    path = "s3://${var.name_bucket}/curated/analytics/"
  }

  s3_target {
    path = "s3://${var.name_bucket}/curated/metrics/"
  }

  # Agendamento: executa diariamente às 06:00 UTC
  schedule = "cron(0 6 * * ? *)"

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  tags = {
    Project = "projeto-dm"
    Layer   = "curated"
  }
}

# -------------------------------------------------------------------
# GLUE JOB - ETL principal (RAW → PROCESSED com mascaramento)
# -------------------------------------------------------------------

# Job Glue para transformação e mascaramento de dados
resource "aws_glue_job" "etl_job" {

  # Nome do job
  name        = "projeto-dm-etl-job"
  role_arn    = var.iam_role_arn
  description = "Job ETL: limpa, transforma e mascara dados da camada RAW para PROCESSED"

  # Configuração do worker: G.1X = 4 vCPUs, 16 GB RAM
  worker_type       = "G.1X"
  number_of_workers = 2

  # Versão do Glue com suporte ao Spark 3
  glue_version = "4.0"

  # Script de transformação armazenado no S3
  command {
    name            = "glueetl"
    script_location = "s3://${var.name_bucket}/pipeline/glue_job_etl.py"
    python_version  = "3"
  }

  # Argumentos padrão do job
  default_arguments = {
    "--job-language"                     = "python"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"                   = "true"
    "--enable-spark-ui"                  = "true"
    "--enable-glue-datacatalog"          = "true"
    "--spark-event-logs-path"            = "s3://${var.name_bucket}/logs/glue-spark-ui/"
    "--TempDir"                          = "s3://${var.name_bucket}/logs/glue-temp/"
    "--SOURCE_BUCKET"                    = var.name_bucket
    "--SOURCE_PREFIX"                    = "raw/batch/"
    "--TARGET_PREFIX"                    = "processed/"

    # Módulos do projeto importados pelo script.
    # Sem este argumento o job falha no import de p_log / p_masking.
    "--extra-py-files" = join(",", [
      "s3://${var.name_bucket}/pipeline/p_log.py",
      "s3://${var.name_bucket}/pipeline/p_masking.py",
      "s3://${var.name_bucket}/pipeline/p_processamento.py"
    ])
  }

  # Timeout do job em minutos
  timeout = 60

  # Número máximo de tentativas em caso de falha
  max_retries = 1

  tags = {
    Project = "projeto-dm"
  }
}

# -------------------------------------------------------------------
# GLUE JOB - Curadoria (PROCESSED → CURATED)
# O treinamento dos modelos de ML roda no Amazon EMR (pipeline/projeto.py).
# Este job produz as agregações analíticas de consumo.
# -------------------------------------------------------------------

# Job Glue para curadoria analítica dos dados
resource "aws_glue_job" "curated_job" {

  # Nome do job
  name        = "projeto-dm-curated-job"
  role_arn    = var.iam_role_arn
  description = "Job de curadoria: gera agregacoes analiticas da camada PROCESSED para a CURATED"

  # Configuração do worker
  worker_type       = "G.1X"
  number_of_workers = 2

  # Versão do Glue
  glue_version = "4.0"

  # Script de curadoria armazenado no S3
  command {
    name            = "glueetl"
    script_location = "s3://${var.name_bucket}/pipeline/glue_job_curated.py"
    python_version  = "3"
  }

  # Argumentos padrão
  default_arguments = {
    "--job-language"                     = "python"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"                   = "true"
    "--enable-glue-datacatalog"          = "true"
    "--TempDir"                          = "s3://${var.name_bucket}/logs/glue-temp/"
    "--SOURCE_BUCKET"                    = var.name_bucket
    "--SOURCE_PREFIX"                    = "processed/"
    "--TARGET_PREFIX"                    = "curated/"

    # Módulos do projeto importados pelo script
    "--extra-py-files" = "s3://${var.name_bucket}/pipeline/p_log.py"
  }

  # Timeout do job em minutos
  timeout = 60

  # Número máximo de tentativas
  max_retries = 1

  tags = {
    Project = "projeto-dm"
  }
}

# -------------------------------------------------------------------
# GLUE WORKFLOW - Orquestra a execução dos jobs em sequência
# -------------------------------------------------------------------

# Workflow que encadeia ETL → Curadoria/ML
resource "aws_glue_workflow" "pipeline_workflow" {

  # Nome do workflow
  name        = "projeto-dm-pipeline-workflow"
  description = "Orquestra o pipeline completo: RAW → PROCESSED → CURATED"

  tags = {
    Project = "projeto-dm"
  }
}

# Trigger de início: dispara o ETL diariamente às 03:00 UTC
resource "aws_glue_trigger" "start_etl_trigger" {

  # Nome do trigger
  name          = "projeto-dm-start-etl"
  workflow_name = aws_glue_workflow.pipeline_workflow.name

  # Tipo agendado (cron)
  type     = "SCHEDULED"
  schedule = "cron(0 3 * * ? *)"

  # Job a ser disparado
  actions {
    job_name = aws_glue_job.etl_job.name
  }

  tags = {
    Project = "projeto-dm"
  }
}

# Trigger condicional: dispara a curadoria após o ETL completar com sucesso
resource "aws_glue_trigger" "start_curated_trigger" {

  # Nome do trigger
  name          = "projeto-dm-start-curated"
  workflow_name = aws_glue_workflow.pipeline_workflow.name

  # Tipo condicional: aguarda o job anterior completar
  type = "CONDITIONAL"

  # Condição: ETL deve ter completado com sucesso
  predicate {
    conditions {
      job_name = aws_glue_job.etl_job.name
      state    = "SUCCEEDED"
    }
  }

  # Job a ser disparado após a condição ser satisfeita
  actions {
    job_name = aws_glue_job.curated_job.name
  }

  tags = {
    Project = "projeto-dm"
  }
}
