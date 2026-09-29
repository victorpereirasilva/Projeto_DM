# Variáveis do Módulo S3

variable "name_bucket" {
  type        = string
  description = "Nome do bucket principal do Data Lake"
}

variable "versioning_bucket" {
  type        = string
  description = "Estado do versionamento do bucket: Enabled, Suspended ou Disabled"
  default     = "Enabled"

  validation {
    condition     = contains(["Enabled", "Suspended", "Disabled"], var.versioning_bucket)
    error_message = "versioning_bucket aceita apenas Enabled, Suspended ou Disabled."
  }
}

variable "files_bucket" {
  type        = string
  description = "Pasta local com os scripts Python do pipeline, enviados para pipeline/ no bucket"
  default     = "./pipeline"
}

variable "files_data" {
  type        = string
  description = "Pasta local com o dataset CSV, enviado para raw/batch/ no bucket"
  default     = "./dados"
}

variable "files_bash" {
  type        = string
  description = "Pasta local com os scripts shell, enviados para scripts/ no bucket"
  default     = "./scripts"
}

variable "kms_key_arn" {
  type        = string
  description = "ARN da chave KMS que criptografa o bucket"
}
