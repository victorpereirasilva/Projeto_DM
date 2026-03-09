# Script Principal

# Módulo de Criptografia (deve ser criado primeiro pois outros módulos dependem dele)
module "kms" {
  source      = "./modules/kms"
  name_bucket = var.name_bucket
}

# Módulo de Armazenamento
module "s3" {
  source            = "./modules/s3"
  name_bucket       = var.name_bucket
  versioning_bucket = var.versioning_bucket
  files_bucket      = var.files_bucket
  files_data        = var.files_data
  files_bash        = var.files_bash
  kms_key_arn       = module.kms.kms_key_arn
}

# Módulo de Segurança
module "iam" {
  source      = "./modules/iam"
  name_bucket = var.name_bucket
}

# Módulo de Processamento
module "emr" {
  source           = "./modules/emr"
  name_emr         = var.name_emr
  name_bucket      = var.name_bucket
  instance_profile = module.iam.instance_profile
  service_role     = module.iam.service_role
}

# Módulo de Monitoramento e Observabilidade
module "monitoring" {
  source      = "./modules/monitoring"
  name_bucket = var.name_bucket
  name_emr    = var.name_emr
  alarm_email = var.alarm_email
}

# Módulo de ETL com Glue
module "glue" {
  source       = "./modules/glue"
  name_bucket  = var.name_bucket
  glue_db_name = var.glue_db_name
  iam_role_arn = module.iam.glue_role_arn
}
