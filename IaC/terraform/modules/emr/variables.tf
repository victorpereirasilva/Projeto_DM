# Variáveis do Módulo EMR

variable "name_emr" {
  type        = string
  description = "Nome do cluster EMR"
}

variable "name_bucket" {
  type        = string
  description = "Nome do bucket principal do projeto"
}

variable "instance_profile" {
  type        = string
  description = "Nome do perfil de instância IAM para as instâncias EC2 do EMR"
}

variable "service_role" {
  type        = string
  description = "ARN da role de serviço do EMR"
}
