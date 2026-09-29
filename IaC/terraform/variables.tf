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

# -------------------------------------------------------------------
# ESCALABILIDADE DO CLUSTER EMR
# Ajustar o dimensionamento é questão de terraform.tfvars, não de código.
# -------------------------------------------------------------------

variable "emr_master_instance_type" {
  type        = string
  description = "Tipo de instância do nó principal do EMR"
  default     = "m5.xlarge"
}

variable "emr_core_instance_type" {
  type        = string
  description = "Tipo de instância dos nós core do EMR"
  default     = "m5.xlarge"
}

variable "emr_core_instance_count" {
  type        = number
  description = "Quantidade inicial de nós core do EMR"
  default     = 2
}

variable "emr_max_capacity_units" {
  type        = number
  description = "Teto de instâncias do EMR Managed Scaling"
  default     = 10
}

# -------------------------------------------------------------------
# SEGURANÇA
# -------------------------------------------------------------------

variable "allowed_ssh_cidr" {
  type        = string
  description = "CIDR autorizado a abrir SSH no nó principal do EMR (ex.: 203.0.113.4/32). Vazio, o padrão, não cria regra de entrada alguma."
  default     = ""
}
