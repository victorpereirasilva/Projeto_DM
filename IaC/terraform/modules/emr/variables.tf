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

# -------------------------------------------------------------------
# ESCALABILIDADE
# Todos os parâmetros de capacidade são variáveis: dimensionar o cluster
# para um volume maior não exige alterar código, apenas terraform.tfvars.
# -------------------------------------------------------------------

variable "master_instance_type" {
  type        = string
  description = "Tipo de instância do nó principal (escalabilidade vertical)"
  default     = "m5.xlarge"
}

variable "core_instance_type" {
  type        = string
  description = "Tipo de instância dos nós core (escalabilidade vertical)"
  default     = "m5.xlarge"
}

variable "core_instance_count" {
  type        = number
  description = "Quantidade inicial de nós core, antes do ajuste automático"
  default     = 2
}

variable "min_capacity_units" {
  type        = number
  description = "Capacidade mínima do EMR Managed Scaling, em instâncias"
  default     = 3
}

variable "max_capacity_units" {
  type        = number
  description = "Capacidade máxima do EMR Managed Scaling, em instâncias"
  default     = 10
}

variable "subnet_id" {
  type        = string
  description = "Subnet onde o cluster sobe. Vazio usa a VPC default da conta."
  default     = ""
}

variable "allowed_ssh_cidr" {
  type        = string
  description = "CIDR autorizado a abrir SSH no nó principal do EMR (ex.: 203.0.113.4/32). Vazio, o padrão, não cria nenhuma regra de entrada."
  default     = ""

  validation {
    condition     = var.allowed_ssh_cidr != "0.0.0.0/0"
    error_message = "Expor o SSH do EMR para 0.0.0.0/0 não é permitido. Informe o CIDR da sua origem ou deixe vazio."
  }
}
