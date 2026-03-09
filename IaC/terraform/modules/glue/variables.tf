# Variáveis do Módulo Glue

variable "name_bucket" {
  type        = string
  description = "Nome do bucket principal do projeto"
}

variable "glue_db_name" {
  type        = string
  description = "Nome do banco de dados no Glue Data Catalog"
  default     = "projeto_dm_catalog"
}

variable "iam_role_arn" {
  type        = string
  description = "ARN da role IAM do Glue com permissões de acesso ao S3"
}
