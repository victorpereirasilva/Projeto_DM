# Variáveis do Módulo Kinesis

variable "name_bucket" {
  type        = string
  description = "Nome do bucket principal do projeto, usado como prefixo dos recursos"
}

variable "bucket_arn" {
  type        = string
  description = "ARN do bucket do Data Lake onde o Firehose grava a camada RAW"
}

variable "kms_key_arn" {
  type        = string
  description = "ARN da chave KMS usada para criptografar o stream e os objetos entregues"
}

variable "firehose_role_arn" {
  type        = string
  description = "ARN da role do Firehose, criada no módulo iam (a policy da chave KMS precisa dela, por isso a role vive fora deste módulo)"
}
