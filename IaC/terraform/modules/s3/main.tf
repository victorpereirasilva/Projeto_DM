# Módulo de Armazenamento - S3 Data Lake

# Bucket principal com camadas RAW / PROCESSED / CURATED
resource "aws_s3_bucket" "main_bucket" {

  # Nome do bucket
  bucket = var.name_bucket

  # Impede destruição acidental do bucket com dados
  force_destroy = false

  tags = {
    Name    = var.name_bucket
    Project = "projeto-dm"
  }
}

# Versionamento do bucket principal
resource "aws_s3_bucket_versioning" "main_bucket_versioning" {
  bucket = aws_s3_bucket.main_bucket.id

  versioning_configuration {
    status = var.versioning_bucket
  }
}

# Criptografia do bucket com KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "main_bucket_encryption" {
  bucket = aws_s3_bucket.main_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      # Usa chave KMS gerenciada pelo módulo kms
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    # Força criptografia em todos os uploads
    bucket_key_enabled = true
  }
}

# Bloqueia todo acesso público ao bucket (conformidade LGPD)
resource "aws_s3_bucket_public_access_block" "main_bucket_public_access" {
  bucket = aws_s3_bucket.main_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Política de ciclo de vida para controle de retenção de dados (LGPD)
resource "aws_s3_bucket_lifecycle_configuration" "main_bucket_lifecycle" {
  bucket = aws_s3_bucket.main_bucket.id

  # Regra para camada RAW: move para Glacier após 90 dias, expira em 365 dias
  rule {
    id     = "raw-lifecycle"
    status = "Enabled"

    filter {
      prefix = "raw/"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }

  # Regra para camada PROCESSED: move para Infrequent Access após 60 dias
  rule {
    id     = "processed-lifecycle"
    status = "Enabled"

    filter {
      prefix = "processed/"
    }

    transition {
      days          = 60
      storage_class = "STANDARD_IA"
    }
  }

  # Regra para logs: expira após 30 dias
  rule {
    id     = "logs-lifecycle"
    status = "Enabled"

    filter {
      prefix = "logs/"
    }

    expiration {
      days = 30
    }
  }
}

# Faz upload dos scripts Python do pipeline para o bucket
resource "aws_s3_object" "pipeline_scripts" {
  for_each = fileset(var.files_bucket, "*.py")

  bucket = aws_s3_bucket.main_bucket.id
  key    = "pipeline/${each.value}"
  source = "${var.files_bucket}/${each.value}"
  etag   = filemd5("${var.files_bucket}/${each.value}")
}

# Faz upload dos arquivos de dados para o bucket
resource "aws_s3_object" "data_files" {
  for_each = fileset(var.files_data, "**")

  bucket = aws_s3_bucket.main_bucket.id
  key    = "dados/${each.value}"
  source = "${var.files_data}/${each.value}"
  etag   = filemd5("${var.files_data}/${each.value}")
}

# Faz upload dos scripts bash para o bucket
resource "aws_s3_object" "bash_scripts" {
  for_each = fileset(var.files_bash, "*.sh")

  bucket = aws_s3_bucket.main_bucket.id
  key    = "scripts/${each.value}"
  source = "${var.files_bash}/${each.value}"
  etag   = filemd5("${var.files_bash}/${each.value}")
}

# Cria prefixos (pastas) para as camadas do Data Lake
resource "aws_s3_object" "prefix_raw" {
  bucket  = aws_s3_bucket.main_bucket.id
  key     = "raw/"
  content = ""
}

resource "aws_s3_object" "prefix_processed" {
  bucket  = aws_s3_bucket.main_bucket.id
  key     = "processed/"
  content = ""
}

resource "aws_s3_object" "prefix_curated" {
  bucket  = aws_s3_bucket.main_bucket.id
  key     = "curated/"
  content = ""
}

resource "aws_s3_object" "prefix_logs" {
  bucket  = aws_s3_bucket.main_bucket.id
  key     = "logs/"
  content = ""
}

resource "aws_s3_object" "prefix_output" {
  bucket  = aws_s3_bucket.main_bucket.id
  key     = "output/"
  content = ""
}
