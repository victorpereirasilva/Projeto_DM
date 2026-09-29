# Script Principal

# Módulo de Segurança (criado primeiro: a policy da chave KMS precisa das roles)
module "iam" {
  source      = "./modules/iam"
  name_bucket = var.name_bucket
}

# Módulo de Criptografia
module "kms" {
  source      = "./modules/kms"
  name_bucket = var.name_bucket

  # Roles do EMR e do Glue autorizadas a usar a chave para ler/gravar no Data Lake
  principal_role_arns = module.iam.todas_as_roles_arns
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

# Módulo de Processamento
module "emr" {
  source           = "./modules/emr"
  name_emr         = var.name_emr
  name_bucket      = var.name_bucket
  instance_profile = module.iam.instance_profile
  service_role     = module.iam.service_role

  # Dimensionamento do cluster, ajustável sem alterar código
  master_instance_type = var.emr_master_instance_type
  core_instance_type   = var.emr_core_instance_type
  core_instance_count  = var.emr_core_instance_count
  max_capacity_units   = var.emr_max_capacity_units

  # Origem autorizada a abrir SSH no nó principal. Vazio por padrão:
  # nenhuma porta administrativa fica exposta à internet.
  allowed_ssh_cidr = var.allowed_ssh_cidr

  # Subnet do cluster. Vazio usa a VPC default da conta.
  subnet_id = var.emr_subnet_id

  # Os scripts e os dados precisam estar no S3 antes do cluster subir e rodar o step
  depends_on = [module.s3]
}

# Módulo de Ingestão em Tempo Real (via streaming da arquitetura Lambda)
module "kinesis" {
  source            = "./modules/kinesis"
  name_bucket       = var.name_bucket
  bucket_arn        = module.s3.bucket_arn
  kms_key_arn       = module.kms.kms_key_arn
  firehose_role_arn = module.iam.firehose_role_arn
}

# Módulo de Monitoramento e Observabilidade
module "monitoring" {
  source      = "./modules/monitoring"
  name_bucket = var.name_bucket
  name_emr    = var.name_emr
  alarm_email = var.alarm_email

  # O alarme de nós pendentes precisa do ID do cluster, não do nome
  emr_cluster_id = module.emr.cluster_id

  # Filtro de métricas usado pelo alarme de ausência de ingestão
  s3_metrics_filter_id = module.s3.metrics_filter_id

  # Monitora também a via de streaming da arquitetura Lambda
  firehose_delivery_stream_name = module.kinesis.delivery_stream_name
}

# Módulo de ETL com Glue
module "glue" {
  source       = "./modules/glue"
  name_bucket  = var.name_bucket
  glue_db_name = var.glue_db_name
  iam_role_arn = module.iam.glue_role_arn

  # Os scripts dos jobs precisam estar no S3 antes dos jobs serem criados
  depends_on = [module.s3]
}

# Módulo de Consulta com Athena
module "athena" {
  source      = "./modules/athena"
  name_bucket = var.name_bucket
  kms_key_arn = module.kms.kms_key_arn

  # As consultas salvas referenciam o banco catalogado pelo Glue
  glue_db_name         = module.glue.database_name
  bytes_scanned_cutoff = var.athena_bytes_scanned_cutoff

  # O bucket precisa existir antes de ser apontado como local de resultado
  depends_on = [module.s3]
}
