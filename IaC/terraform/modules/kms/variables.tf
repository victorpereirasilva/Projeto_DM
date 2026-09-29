# Variáveis do Módulo KMS

variable "name_bucket" {
  type        = string
  description = "Nome do bucket principal, usado nas tags"
}

variable "principal_role_arns" {
  type        = list(string)
  description = "ARNs das roles IAM do projeto (EMR EC2, EMR service e Glue) que precisam usar a chave KMS para ler e gravar dados criptografados no Data Lake"
  default     = []
}
