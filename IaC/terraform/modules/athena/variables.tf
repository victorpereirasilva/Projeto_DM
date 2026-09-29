# Variáveis do Módulo Athena

variable "name_bucket" {
  type        = string
  description = "Nome do bucket principal do projeto, onde ficam os resultados das consultas"
}

variable "kms_key_arn" {
  type        = string
  description = "ARN da chave KMS usada para criptografar o resultado das consultas"
}

variable "glue_db_name" {
  type        = string
  description = "Banco de dados do Glue Data Catalog consultado pelas queries salvas"
}

variable "bytes_scanned_cutoff" {
  type        = number
  description = "Teto de bytes varridos por consulta. O padrão, 10 GB, é o mínimo aceito pela AWS."
  default     = 10737418240

  validation {
    condition     = var.bytes_scanned_cutoff >= 10485760
    error_message = "O Athena exige no mínimo 10 MB (10485760 bytes) de teto de varredura por consulta."
  }
}
