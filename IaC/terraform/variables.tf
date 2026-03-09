# Script de Definição de Variáveis

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

variable "name_emr" {
  type        = string
  description = "Nome do cluster EMR"
}

variable "alarm_email" {
  type        = string
  description = "E-mail para receber alertas de monitoramento via SNS"
}

variable "glue_db_name" {
  type        = string
  description = "Nome do banco de dados no AWS Glue Data Catalog"
  default     = "projeto_dm_catalog"
}
