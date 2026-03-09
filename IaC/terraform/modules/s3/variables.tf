# Variáveis do Módulo S3

variable "name_bucket" {
  type        = string
  description = "Nome do bucket principal do projeto"
}

variable "versioning_bucket" {
  type        = string
  description = "Define se o versionamento do bucket estará habilitado"
}

variable "files_bucket" {
  type        = string
  description = "Pasta de onde os scripts python serão obtidos para o processamento"
  default     = "./pipeline"
}

variable "files_data" {
  type        = string
  description = "Pasta de onde os dados serão obtidos"
  default     = "./dados"
}

variable "files_bash" {
  type        = string
  description = "Pasta de onde os scripts bash serão obtidos"
  default     = "./scripts"
}

variable "kms_key_arn" {
  type        = string
  description = "ARN da chave KMS para criptografia do bucket"
}
