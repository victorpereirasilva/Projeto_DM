# Módulo de Processamento - Amazon EMR

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
  }

  # Configuração do nó principal
  master_instance_group {
    # Tipo de instância do nó principal
    instance_type = "m5.xlarge"
  }

  # Configuração dos nós workers
  core_instance_group {
    # Tipo de instância dos nós core
    instance_type = "m5.xlarge"

    # Quantidade de nós workers
    instance_count = 2
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

  # Descrição
  description = "Allow inbound traffic for EMR main node."

  # Opção para revogar regras ao deletar o grupo
  revoke_rules_on_delete = true

  # Regra de entrada: SSH para administração
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
