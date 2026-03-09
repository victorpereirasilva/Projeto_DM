# Módulo de Criptografia - AWS KMS

# Obtém o ID da conta AWS atual
data "aws_caller_identity" "current" {}

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
    Statement = [
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
      }
    ]
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
