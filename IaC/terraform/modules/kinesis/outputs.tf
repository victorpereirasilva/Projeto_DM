# Outputs do Módulo Kinesis

output "stream_name" {
  description = "Nome do Kinesis Data Stream de atendimentos"
  value       = aws_kinesis_stream.atendimentos_stream.name
}

output "stream_arn" {
  description = "ARN do Kinesis Data Stream de atendimentos"
  value       = aws_kinesis_stream.atendimentos_stream.arn
}

output "delivery_stream_name" {
  description = "Nome do delivery stream do Firehose que grava na camada RAW"
  value       = aws_kinesis_firehose_delivery_stream.raw_delivery.name
}
