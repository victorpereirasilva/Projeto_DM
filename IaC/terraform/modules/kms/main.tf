# Módulo de Criptografia - AWS KMS

# Obtém o ID da conta AWS atual
data "aws_caller_identity" "current" {}

# -------------------------------------------------------------------
# PRINCIPALS IAM DO PROJETO
# O Spark no EMR e os jobs do Glue não acessam o S3 como "serviço":
# eles assumem suas roles IAM. Sem essas roles na policy da chave,
# toda leitura/escrita no bucket criptografado falha com AccessDenied.
# -------------------------------------------------------------------

locals {
  # O statement só é incluído quando há roles informadas
  statement_roles_projeto = length(var.principal_role_arns) > 0 ? [
    {
      Sid    = "AllowProjectRolesUsage"
      Effect = "Allow"
      Principal = {
        AWS = var.principal_role_arns
      }
      Action = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      Resource = "*"
    }
  ] : []
}

# Chave KMS para criptografia dos dados em repouso no S3
resource "aws_kms_key" "s3_kms_key" {

  # Descrição da chave
  description = "Chave KMS para criptografia do Data Lake - Projeto DM"

  # Rotação automática anual da chave
  enable_key_rotation = true

  # Período de espera antes da exclusão (mínimo 7 dias)
  deletion_window_in_days = 7

  # Política da chave: define quem pode usar e administrar
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        # Permite que o root da conta gerencie a chave
        Sid    = "EnableRootPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        # Permite que o S3 use a chave para criptografia
        Sid    = "AllowS3ServiceUsage"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]
        Resource = "*"
      },
      {
        # Permite que o Glue use a chave para ler e escrever dados criptografados
        Sid    = "AllowGlueServiceUsage"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]
        Resource = "*"
      },
      {
        # Permite que o EMR use a chave nos jobs Spark
        Sid    = "AllowEMRServiceUsage"
        Effect = "Allow"
        Principal = {
          Service = "elasticmapreduce.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]
        Resource = "*"
      },
      {
        # Permite que o Kinesis e o Firehose criptografem os eventos
        # que trafegam pela via de streaming
        Sid    = "AllowKinesisServiceUsage"
        Effect = "Allow"
        Principal = {
          Service = [
            "kinesis.amazonaws.com",
            "firehose.amazonaws.com"
          ]
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ], local.statement_roles_projeto)
  })

  tags = {
    Name    = "projeto-dm-kms-key"
    Project = "projeto-dm"
  }
}

# Alias para facilitar a identificação da chave no console AWS
resource "aws_kms_alias" "s3_kms_key_alias" {

  # Nome do alias
  name          = "alias/projeto-dm-s3-key"
  target_key_id = aws_kms_key.s3_kms_key.key_id
}
