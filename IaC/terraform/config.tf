# Configuração Para o Estado Remoto, Versão do Terraform e Provider

# Versão do Terraform
terraform {
  required_version = "~> 1.7"

  # Provider AWS
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend usado para o estado remoto
  # Este bucket deve ser criado manualmente antes do terraform init
  backend "s3" {
    encrypt = true
    bucket  = "proj-dm-terraform-SEU_ACCOUNT_ID"
    key     = "projeto-dm.tfstate"
    region  = "us-east-2"
  }
}

# Região do provider
provider "aws" {
  region = "us-east-2"
}
