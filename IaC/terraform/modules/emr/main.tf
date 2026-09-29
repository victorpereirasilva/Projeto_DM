# Módulo de Processamento - Amazon EMR

# -------------------------------------------------------------------
# REDE
# O cluster precisa de uma subnet, e os security groups precisam estar na
# mesma VPC dessa subnet. Duas situações são atendidas:
#
#   subnet_id informado  -> usa essa subnet e descobre a VPC a partir dela
#   subnet_id vazio      -> usa a VPC default da conta (comportamento padrão)
#
# Sem o primeiro caso, o módulo só funcionaria em contas que ainda têm a VPC
# default — contas criadas com baseline corporativo normalmente não têm, e a
# falha aparece como um erro de rede do EMR no meio do apply, difícil de
# relacionar à causa.
# -------------------------------------------------------------------

data "aws_subnet" "selecionada" {
  count = var.subnet_id == "" ? 0 : 1
  id    = var.subnet_id
}

data "aws_vpc" "default" {
  count   = var.subnet_id == "" ? 1 : 0
  default = true
}

locals {
  vpc_id = var.subnet_id == "" ? data.aws_vpc.default[0].id : data.aws_subnet.selecionada[0].vpc_id
}

# Cluster EMR com PySpark para processamento distribuído de Machine Learning
resource "aws_emr_cluster" "emr_cluster" {

  # Nome do cluster
  name          = var.name_emr

  # Versão do EMR com suporte ao Spark
  release_label = "emr-6.15.0"

  # Aplicações instaladas no cluster
  applications = ["Spark", "Hadoop", "Hive"]

  # Encerra o cluster automaticamente após o job finalizar
  auto_termination_policy {
    idle_timeout = 3600
  }

  # Configuração das instâncias EC2 do cluster
  ec2_attributes {
    instance_profile                  = var.instance_profile
    emr_managed_master_security_group = aws_security_group.emr_main_sg.id
    emr_managed_slave_security_group  = aws_security_group.emr_core_sg.id

    # Subnet explícita quando informada; null deixa o EMR escolher uma
    # subnet da VPC default
    subnet_id = var.subnet_id == "" ? null : var.subnet_id
  }

  # Configuração do nó principal
  master_instance_group {
    # Tipo de instância do nó principal (escalabilidade vertical: basta trocar aqui)
    instance_type = var.master_instance_type
  }

  # Configuração dos nós workers
  core_instance_group {
    # Tipo de instância dos nós core
    instance_type = var.core_instance_type

    # Quantidade inicial de nós workers — o EMR Managed Scaling ajusta
    # esse número automaticamente conforme a carga do YARN
    instance_count = var.core_instance_count
  }

  # ESCALABILIDADE HORIZONTAL
  # O EMR Managed Scaling adiciona e remove nós sozinho, com base na
  # demanda de memória e contêineres pendentes no YARN. É o que permite
  # rodar a mesma stack com 90 mil ou 90 milhões de registros sem
  # alterar uma linha de código.
  managed_scaling_policy {
    compute_limits {
      unit_type                       = "Instances"
      minimum_capacity_units          = var.min_capacity_units
      maximum_capacity_units          = var.max_capacity_units
      maximum_core_capacity_units     = var.max_capacity_units
      maximum_ondemand_capacity_units = var.max_capacity_units
    }
  }

  # Role de serviço do EMR
  service_role = var.service_role

  # Caminho para os logs do cluster no S3
  log_uri = "s3://${var.name_bucket}/logs/emr/"

  # Script de bootstrap: prepara o ambiente Python nos nós do cluster
  bootstrap_action {
    name = "Prepara Ambiente Python"
    path = "s3://${var.name_bucket}/scripts/bootstrap.sh"
  }

  # Configurações do Spark para otimização de memória e execução
  configurations_json = jsonencode([
    {
      Classification = "spark-defaults"
      Properties = {
        "spark.dynamicAllocation.enabled" = "true"
        "spark.executor.memory"           = "4g"
        "spark.driver.memory"             = "4g"
        "spark.sql.shuffle.partitions"    = "200"
      }
    }
  ])

  # Step para executar o script principal de processamento
  step {
    name              = "Executa Pipeline Principal"
    action_on_failure = "CONTINUE"

    hadoop_jar_step {
      jar = "command-runner.jar"
      args = [
        "spark-submit",
        "--deploy-mode", "cluster",
        "--master", "yarn",

        # Módulos do projeto importados por projeto.py. Em deploy-mode cluster
        # apenas o script principal é distribuído; sem --py-files os imports
        # de p_log / p_processamento / p_ml / p_masking falham no driver.
        "--py-files", join(",", [
          "s3://${var.name_bucket}/pipeline/p_log.py",
          "s3://${var.name_bucket}/pipeline/p_masking.py",
          "s3://${var.name_bucket}/pipeline/p_processamento.py",
          "s3://${var.name_bucket}/pipeline/p_ml.py"
        ]),

        "s3://${var.name_bucket}/pipeline/projeto.py"
      ]
    }
  }

  tags = {
    Name    = var.name_emr
    Project = "projeto-dm"
  }
}

# -------------------------------------------------------------------
# SECURITY GROUPS DO EMR
# -------------------------------------------------------------------

# Grupo de segurança para o nó principal do EMR
resource "aws_security_group" "emr_main_sg" {

  # Nome do grupo de segurança
  name = "${var.name_emr}-main-sg"

  # Mesma VPC da subnet do cluster
  vpc_id = local.vpc_id

  # Descrição
  description = "Allow inbound traffic for EMR main node."

  # Opção para revogar regras ao deletar o grupo
  revoke_rules_on_delete = true

  # Regra de entrada: SSH para administração, restrito a uma origem conhecida.
  # O bloco só é criado quando allowed_ssh_cidr é informado — por padrão o
  # cluster sobe sem nenhuma porta administrativa aberta para a internet.
  dynamic "ingress" {
    for_each = var.allowed_ssh_cidr == "" ? [] : [var.allowed_ssh_cidr]

    content {
      description = "SSH administrativo a partir de uma origem autorizada"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # Regra de saída: permite todo tráfego de saída
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Grupo de segurança para os nós core (workers) do EMR
resource "aws_security_group" "emr_core_sg" {

  # Nome do grupo de segurança
  name = "${var.name_emr}-core-sg"

  # Mesma VPC da subnet do cluster
  vpc_id = local.vpc_id

  # Descrição
  description = "Allow inbound outbound traffic for EMR core nodes."

  # Opção para revogar regras ao deletar o grupo
  revoke_rules_on_delete = true

  # Regra de entrada: tráfego interno entre nós do cluster
  ingress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = true
  }

  # Regra de saída: permite todo tráfego de saída
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
