# Variáveis do Módulo Glue

variable "name_bucket" {
  type        = string
  description = "Nome do bucket do Data Lake lido e gravado pelos jobs e crawlers"
}

variable "glue_db_name" {
  type        = string
  description = "Nome do banco de dados no Glue Data Catalog"
  default     = "projeto_dm_catalog"
}

variable "iam_role_arn" {
  type        = string
  description = "ARN da role assumida pelos jobs e crawlers do Glue"
}
