# Variáveis EMR

variable "name_emr" {
  type        = string
  description = "Nome do cluster EMR"
}

variable "name_bucket" {
  type        = string
  description = "Nome do bucket"
}

variable "instance_profile" {}

variable "service_role" {}
