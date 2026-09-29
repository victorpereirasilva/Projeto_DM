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

# Política customizada das instâncias EC2 do EMR.
#
# Substitui a política gerenciada AmazonElasticMapReduceforEC2Role, que
# concede acesso amplo a S3, DynamoDB, Glue, SDB e Kinesis em TODA a conta.
# Aqui o acesso a dado fica restrito ao bucket do projeto — é a role que o
# Spark assume, e portanto a que realmente toca o Data Lake.
resource "aws_iam_policy" "emr_ec2_policy" {

  # Nome da política
  name        = "projeto-dm-emr-ec2-policy"
  description = "Permissoes minimas para o Spark no EMR acessar o Data Lake do projeto"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Leitura e escrita restritas ao bucket do projeto
        Sid    = "AcessoAoDataLake"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${var.name_bucket}",
          "arn:aws:s3:::${var.name_bucket}/*"
        ]
      },
      {
        # Uso da chave KMS que criptografa o Data Lake
        Sid    = "UsoDaChaveKMS"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        # Leitura do catálogo, para consultar as tabelas do Data Lake via Spark SQL
        Sid    = "LeituraDoCatalogo"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions"
        ]
        Resource = "*"
      },
      {
        # Escrita dos logs do cluster no CloudWatch
        Sid    = "EscritaDeLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/projeto-dm/*"
      },
      {
        # Metadados que o EMR consulta durante a inicialização do cluster
        Sid    = "MetadadosDoCluster"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "elasticmapreduce:Describe*",
          "elasticmapreduce:ListBootstrapActions",
          "elasticmapreduce:ListClusters",
          "elasticmapreduce:ListInstanceGroups",
          "elasticmapreduce:ListInstances",
          "elasticmapreduce:ListSteps",
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

# Anexa a política customizada às instâncias EC2 do EMR
resource "aws_iam_role_policy_attachment" "emr_ec2_policy" {
  role       = aws_iam_role.emr_ec2_role.name
  policy_arn = aws_iam_policy.emr_ec2_policy.arn
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

# -------------------------------------------------------------------
# ROLE PARA O KINESIS DATA FIREHOSE (ingestão em tempo real)
#
# A role vive aqui, e não no módulo kinesis, porque a policy da chave KMS
# precisa conhecer o ARN dela. Se a role fosse criada dentro do módulo
# kinesis — que por sua vez consome a chave KMS — haveria um ciclo de
# dependência entre os módulos.
# -------------------------------------------------------------------

# Região atual, usada para montar o ARN do stream
data "aws_region" "current" {}

# Role de serviço do Firehose
resource "aws_iam_role" "firehose_role" {

  # Nome da role
  name = "projeto-dm-firehose-role"

  # Política de confiança: permite que o Firehose assuma esta role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Project = "projeto-dm"
  }
}

# Política do Firehose: ler do stream, gravar na camada RAW, usar KMS e logar
resource "aws_iam_policy" "firehose_policy" {

  # Nome da política
  name        = "projeto-dm-firehose-policy"
  description = "Permite ao Firehose ler do Kinesis e gravar na camada RAW do Data Lake"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Leitura dos eventos no Kinesis Data Streams
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListShards"
        ]
        Resource = "arn:aws:kinesis:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stream/${var.name_bucket}-atendimentos-stream"
      },
      {
        # Escrita restrita à camada RAW do bucket do projeto
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.name_bucket}",
          "arn:aws:s3:::${var.name_bucket}/raw/*"
        ]
      },
      {
        # Uso da chave KMS para gravar dados criptografados
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        # Registro de logs de entrega no CloudWatch
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogStream"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/kinesisfirehose/*"
      }
    ]
  })
}

# Anexa a política à role do Firehose
resource "aws_iam_role_policy_attachment" "firehose_policy_attachment" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.firehose_policy.arn
}
