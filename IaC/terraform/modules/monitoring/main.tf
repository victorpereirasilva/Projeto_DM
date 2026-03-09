# Módulo de Observabilidade - CloudWatch + CloudTrail + SNS

# Obtém o ID da conta AWS atual
data "aws_caller_identity" "current" {}

# Obtém a região atual
data "aws_region" "current" {}

# -------------------------------------------------------------------
# SNS - Tópico para envio de alertas por e-mail
# -------------------------------------------------------------------

# Tópico SNS para notificações de alertas
resource "aws_sns_topic" "alertas_pipeline" {

  # Nome do tópico
  name = "projeto-dm-alertas-pipeline"

  tags = {
    Project = "projeto-dm"
  }
}

# Inscrição de e-mail no tópico SNS para receber os alertas
resource "aws_sns_topic_subscription" "alertas_email" {

  # Tópico ao qual a inscrição pertence
  topic_arn = aws_sns_topic.alertas_pipeline.arn

  # Protocolo de entrega: e-mail
  protocol = "email"

  # Endereço de e-mail que receberá os alertas
  endpoint = var.alarm_email
}

# -------------------------------------------------------------------
# CLOUDWATCH LOGS - Grupos de log por serviço
# -------------------------------------------------------------------

# Grupo de logs para o pipeline principal
resource "aws_cloudwatch_log_group" "pipeline_logs" {

  # Nome do grupo de logs
  name = "/projeto-dm/pipeline"

  # Retenção de 30 dias (conformidade LGPD)
  retention_in_days = 30

  tags = {
    Project = "projeto-dm"
  }
}

# Grupo de logs para o Glue ETL
resource "aws_cloudwatch_log_group" "glue_logs" {

  # Nome do grupo de logs
  name = "/aws-glue/jobs/projeto-dm"

  # Retenção de 30 dias
  retention_in_days = 30

  tags = {
    Project = "projeto-dm"
  }
}

# Grupo de logs para o EMR
resource "aws_cloudwatch_log_group" "emr_logs" {

  # Nome do grupo de logs
  name = "/projeto-dm/emr"

  # Retenção de 30 dias
  retention_in_days = 30

  tags = {
    Project = "projeto-dm"
  }
}

# -------------------------------------------------------------------
# CLOUDWATCH ALARMS - Alarmes automáticos por condição
# -------------------------------------------------------------------

# Alarme: falha nos jobs do Glue
resource "aws_cloudwatch_metric_alarm" "glue_job_failure" {

  # Nome do alarme
  alarm_name = "projeto-dm-glue-job-failure"

  # Descrição do alarme
  alarm_description = "Dispara quando um job do Glue falha"

  # Namespace e métrica monitorada
  namespace   = "Glue"
  metric_name = "glue.driver.aggregate.numFailedTasks"

  # Condição de disparo: soma de falhas >= 1 em 5 minutos
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  # Dimensão: nome do job Glue
  dimensions = {
    JobName = "projeto-dm-etl-job"
  }

  # Ação ao disparar: envia notificação para o SNS
  alarm_actions = [aws_sns_topic.alertas_pipeline.arn]
  ok_actions    = [aws_sns_topic.alertas_pipeline.arn]

  tags = {
    Project = "projeto-dm"
  }
}

# Alarme: ausência de dados ingeridos no S3
resource "aws_cloudwatch_metric_alarm" "s3_no_data_ingested" {

  # Nome do alarme
  alarm_name = "projeto-dm-s3-no-new-data"

  # Descrição do alarme
  alarm_description = "Dispara quando nenhum dado novo é ingerido na camada RAW por mais de 24h"

  # Namespace e métrica monitorada
  namespace   = "AWS/S3"
  metric_name = "NumberOfObjects"

  # Condição: sem novos objetos por mais de 1 dia
  statistic           = "Average"
  period              = 86400
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "LessThanOrEqualToThreshold"
  treat_missing_data  = "breaching"

  # Dimensões: bucket principal
  dimensions = {
    BucketName  = var.name_bucket
    StorageType = "StandardStorage"
  }

  # Ação ao disparar
  alarm_actions = [aws_sns_topic.alertas_pipeline.arn]

  tags = {
    Project = "projeto-dm"
  }
}

# Alarme: cluster EMR com nós pendentes
resource "aws_cloudwatch_metric_alarm" "emr_cluster_failure" {

  # Nome do alarme
  alarm_name = "projeto-dm-emr-cluster-failure"

  # Descrição do alarme
  alarm_description = "Dispara quando o cluster EMR apresenta nós pendentes por tempo excessivo"

  # Namespace e métrica monitorada
  namespace   = "AWS/ElasticMapReduce"
  metric_name = "CoreNodesPending"

  # Condição: nós pendentes por mais de 10 minutos
  statistic           = "Average"
  period              = 600
  evaluation_periods  = 1
  threshold           = 2
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  # Dimensão: nome do cluster EMR
  dimensions = {
    JobFlowId = var.name_emr
  }

  # Ação ao disparar
  alarm_actions = [aws_sns_topic.alertas_pipeline.arn]

  tags = {
    Project = "projeto-dm"
  }
}

# -------------------------------------------------------------------
# CLOUDWATCH DASHBOARD - Visão centralizada do pipeline
# -------------------------------------------------------------------

# Dashboard com métricas do pipeline em tempo real
resource "aws_cloudwatch_dashboard" "pipeline_dashboard" {

  # Nome do dashboard
  dashboard_name = "projeto-dm-pipeline-dashboard"

  # Widgets do dashboard em JSON
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Jobs Glue - Tarefas com Falha"
          view   = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["Glue", "glue.driver.aggregate.numFailedTasks", "JobName", "projeto-dm-etl-job"]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "S3 - Objetos no Bucket"
          view   = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/S3", "NumberOfObjects", "BucketName", var.name_bucket, "StorageType", "AllStorageTypes"]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          title  = "EMR - Nós do Cluster"
          view   = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ElasticMapReduce", "CoreNodesPending", "JobFlowId", var.name_emr],
            ["AWS/ElasticMapReduce", "CoreNodesRunning", "JobFlowId", var.name_emr]
          ]
        }
      }
    ]
  })
}

# -------------------------------------------------------------------
# CLOUDTRAIL - Auditoria de acessos (LGPD)
# -------------------------------------------------------------------

# Bucket dedicado para os logs do CloudTrail
resource "aws_s3_bucket" "cloudtrail_bucket" {

  # Nome do bucket de auditoria
  bucket        = "${var.name_bucket}-cloudtrail-logs"
  force_destroy = true

  tags = {
    Project = "projeto-dm"
    Purpose = "auditoria-lgpd"
  }
}

# Política do bucket CloudTrail: permite que o serviço escreva os logs
resource "aws_s3_bucket_policy" "cloudtrail_bucket_policy" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Permite que o CloudTrail verifique o ACL do bucket
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = "arn:aws:s3:::${var.name_bucket}-cloudtrail-logs"
      },
      {
        # Permite que o CloudTrail escreva logs no bucket
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${var.name_bucket}-cloudtrail-logs/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# Trail do CloudTrail para auditoria de acessos ao Data Lake
resource "aws_cloudtrail" "data_lake_trail" {

  # Nome do trail
  name = "projeto-dm-data-lake-trail"

  # Bucket onde os logs serão armazenados
  s3_bucket_name = aws_s3_bucket.cloudtrail_bucket.id

  # Registra eventos de gestão globais
  include_global_service_events = true

  # Habilita validação de integridade dos logs
  enable_log_file_validation = true

  # Registra eventos de dados no S3 (leitura e escrita - conformidade LGPD)
  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      # Monitora todos os objetos do bucket principal
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::${var.name_bucket}/"]
    }
  }

  # Dependência: bucket de logs e sua política devem existir antes
  depends_on = [aws_s3_bucket_policy.cloudtrail_bucket_policy]

  tags = {
    Project = "projeto-dm"
    Purpose = "auditoria-lgpd"
  }
}
