# Variáveis do Módulo Monitoring

variable "name_bucket" {
  type        = string
  description = "Nome do bucket principal do projeto"
}

variable "name_emr" {
  type        = string
  description = "Nome do cluster EMR para monitoramento"
}

variable "alarm_email" {
  type        = string
  description = "E-mail para receber alertas via SNS"
}

variable "firehose_delivery_stream_name" {
  type        = string
  description = "Nome do delivery stream do Firehose monitorado pelo alarme de atraso de entrega"
}

variable "emr_cluster_id" {
  type        = string
  description = "ID do cluster EMR (j-XXXXXXXX). O CloudWatch usa o ID, e não o nome, na dimensão JobFlowId."
}

variable "s3_metrics_filter_id" {
  type        = string
  description = "ID do filtro de métricas de requisição do S3 na camada RAW, usado pelo alarme de ausência de ingestão"
}
