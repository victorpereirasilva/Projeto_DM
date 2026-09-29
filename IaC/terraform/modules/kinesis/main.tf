# Módulo de Ingestão em Tempo Real - Amazon Kinesis
#
# Implementa a via de streaming da arquitetura Lambda:
#
#   Produtor (aplicação de agendamento)
#        -> Kinesis Data Streams   (buffer durável, ordenado, reproduzível)
#        -> Kinesis Data Firehose  (entrega gerenciada, sem servidores)
#        -> camada RAW do Data Lake em s3://bucket/raw/streaming/
#
# A partir da camada RAW o dado segue exatamente o mesmo caminho do lote:
# é mascarado e tratado no ETL antes de alcançar PROCESSED e CURATED.

# -------------------------------------------------------------------
# KINESIS DATA STREAMS - buffer de eventos em tempo real
# -------------------------------------------------------------------

resource "aws_kinesis_stream" "atendimentos_stream" {

  # Nome do stream
  name = "${var.name_bucket}-atendimentos-stream"

  # Modo sob demanda: a capacidade escala sozinha com o volume de eventos,
  # sem provisionamento manual de shards (escalabilidade horizontal nativa)
  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }

  # Janela de reprocessamento: 24h permitem reler os eventos em caso de falha
  retention_period = 24

  # Criptografia em repouso com a chave KMS do projeto (LGPD)
  encryption_type = "KMS"
  kms_key_id      = var.kms_key_arn

  tags = {
    Name    = "${var.name_bucket}-atendimentos-stream"
    Project = "projeto-dm"
  }
}

# -------------------------------------------------------------------
# CLOUDWATCH - Grupo de logs da entrega do Firehose
# -------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "firehose_logs" {

  # Nome do grupo de logs
  name = "/aws/kinesisfirehose/projeto-dm-atendimentos"

  # Retenção de 30 dias, alinhada aos demais grupos do projeto
  retention_in_days = 30

  tags = {
    Project = "projeto-dm"
  }
}

# Stream de log da entrega no S3
resource "aws_cloudwatch_log_stream" "firehose_s3_delivery" {
  name           = "S3Delivery"
  log_group_name = aws_cloudwatch_log_group.firehose_logs.name
}

# -------------------------------------------------------------------
# KINESIS DATA FIREHOSE - entrega dos eventos na camada RAW
# -------------------------------------------------------------------

resource "aws_kinesis_firehose_delivery_stream" "raw_delivery" {

  # Nome do delivery stream
  name = "projeto-dm-raw-delivery"

  # Origem: o Kinesis Data Stream criado acima
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.atendimentos_stream.arn
    role_arn           = var.firehose_role_arn
  }

  extended_s3_configuration {
    role_arn   = var.firehose_role_arn
    bucket_arn = var.bucket_arn

    # Destino dentro da camada RAW, já particionado por ano/mes
    prefix              = "raw/streaming/ano=!{timestamp:yyyy}/mes=!{timestamp:MM}/"
    error_output_prefix = "raw/streaming_errors/!{firehose:error-output-type}/"

    # Buffer de entrega: o que ocorrer primeiro entre 5 MB e 60 segundos
    buffering_size     = 5
    buffering_interval = 60

    # Compressão reduz custo de armazenamento e de varredura no Athena
    compression_format = "GZIP"

    # Criptografia em repouso com a chave KMS do projeto
    kms_key_arn = var.kms_key_arn

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose_logs.name
      log_stream_name = aws_cloudwatch_log_stream.firehose_s3_delivery.name
    }
  }

  tags = {
    Project = "projeto-dm"
  }
}
