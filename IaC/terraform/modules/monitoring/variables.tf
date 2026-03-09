# Variáveis do Módulo Monitoring

variable "name_bucket" {
  type        = string
  description = "Nome do bucket principal do projeto"
}

variable "name_emr" {
  type        = string
  description = "Nome do cluster EMR para monitoramento"
}

variable "alarm_email" {
  type        = string
  description = "E-mail para receber alertas via SNS"
}
