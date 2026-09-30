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

  # Backend do estado remoto — configuração parcial.
  #
  # O bucket deve ser criado manualmente antes do terraform init: é o problema
  # clássico do ovo e da galinha, já que o backend não pode ser provisionado
  # pela mesma configuração que o utiliza.
  #
  # O nome do bucket NÃO fica aqui. Ele carrega o Account ID, e este arquivo é
  # versionado num repositório público. O bloco backend não aceita variáveis —
  # é avaliado antes de as variáveis existirem —, então a saída é a configuração
  # parcial: o que falta vem de um arquivo à parte, fora do Git.
  #
  #   cp backend.hcl.example backend.hcl   # e preencha o bucket
  #   terraform init -backend-config=backend.hcl
  #
  backend "s3" {
    encrypt = true
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
