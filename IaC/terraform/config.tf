# Configuração do Estado Remoto, Versão do Terraform e Provider

terraform {
  # 1.10+ é exigido pelo bloqueio de estado nativo do backend S3
  required_version = "~> 1.10"

  # Provider AWS
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend do estado remoto.
  # Este bucket deve ser criado manualmente antes do terraform init —
  # é o problema clássico do ovo e da galinha: o backend não pode ser
  # provisionado pela mesma configuração que o utiliza.
  backend "s3" {
    encrypt = true
    bucket  = "proj-dm-terraform-SEU_ACCOUNT_ID"
    key     = "projeto-dm.tfstate"
    region  = "us-east-2"

    # Bloqueio de estado nativo do S3 (Terraform 1.10+).
    # Impede que dois applies simultâneos corrompam o estado, sem exigir
    # a tabela DynamoDB que as versões anteriores demandavam.
    use_lockfile = true
  }
}

# Região do provider
provider "aws" {
  region = "us-east-2"

  # Tags aplicadas automaticamente a todos os recursos que as suportam.
  # Garante rastreabilidade de custo e propriedade mesmo em recursos
  # onde a tag foi esquecida.
  default_tags {
    tags = {
      Project     = "projeto-dm"
      ManagedBy   = "terraform"
      Environment = "dev"
    }
  }
}
