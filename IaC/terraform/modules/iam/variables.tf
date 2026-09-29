# Variáveis do Módulo IAM

variable "name_bucket" {
  type        = string
  description = "Nome do bucket do Data Lake. As policies são restritas a este bucket, em vez de conceder acesso amplo ao S3 da conta."
}
