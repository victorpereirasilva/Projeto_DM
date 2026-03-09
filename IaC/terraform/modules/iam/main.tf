# Módulo de Segurança - IAM

# Obtém o ID da conta AWS atual
data "aws_caller_identity" "current" {}

# -------------------------------------------------------------------
# ROLES PARA O EMR
# -------------------------------------------------------------------

# Role de serviço do EMR
resource "aws_iam_role" "emr_service_role" {

  # Nome da role
  name = "projeto-dm-emr-service-role"

  # Política de confiança: permite que o serviço EMR assuma esta role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "elasticmapreduce.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Project = "projeto-dm"
  }
}

# Anexa a política gerenciada da AWS ao serviço EMR
resource "aws_iam_role_policy_attachment" "emr_service_policy" {
  role       = aws_iam_role.emr_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceRole"
}

# Role para as instâncias EC2 do EMR
resource "aws_iam_role" "emr_ec2_role" {

  # Nome da role
  name = "projeto-dm-emr-ec2-role"

  # Política de confiança: permite que instâncias EC2 assumam esta role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Project = "projeto-dm"
  }
}

# Anexa a política gerenciada da AWS para instâncias EC2 do EMR
resource "aws_iam_role_policy_attachment" "emr_ec2_policy" {
  role       = aws_iam_role.emr_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role"
}

# Perfil de instância necessário para associar a role ao EC2 do EMR
resource "aws_iam_instance_profile" "emr_instance_profile" {

  # Nome do perfil de instância
  name = "projeto-dm-emr-instance-profile"
  role = aws_iam_role.emr_ec2_role.name
}

# -------------------------------------------------------------------
# ROLE PARA O GLUE (ETL / Data Catalog)
# -------------------------------------------------------------------

# Role de serviço para o AWS Glue
resource "aws_iam_role" "glue_service_role" {

  # Nome da role
  name = "projeto-dm-glue-service-role"

  # Política de confiança: permite que o serviço Glue assuma esta role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Project = "projeto-dm"
  }
}

# Anexa a política gerenciada da AWS para o Glue
resource "aws_iam_role_policy_attachment" "glue_service_policy" {
  role       = aws_iam_role.glue_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Política customizada do Glue: acesso ao S3, KMS e CloudWatch
resource "aws_iam_policy" "glue_s3_policy" {

  # Nome da política
  name        = "projeto-dm-glue-s3-policy"
  description = "Permite que o Glue acesse o S3, KMS e escreva logs no CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Acesso de leitura e escrita ao bucket do projeto
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.name_bucket}",
          "arn:aws:s3:::${var.name_bucket}/*"
        ]
      },
      {
        # Permissão para usar a chave KMS na criptografia
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        # Escrita de logs no CloudWatch
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:/aws-glue/*"
      }
    ]
  })
}

# Anexa a política customizada à role do Glue
resource "aws_iam_role_policy_attachment" "glue_s3_policy_attachment" {
  role       = aws_iam_role.glue_service_role.name
  policy_arn = aws_iam_policy.glue_s3_policy.arn
}
