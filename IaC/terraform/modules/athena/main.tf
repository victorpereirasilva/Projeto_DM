# Módulo de Consulta - Amazon Athena
#
# O Athena não precisa de servidor nem de provisionamento, mas precisa de
# uma coisa: um lugar para gravar o resultado das consultas. Sem isso, a
# primeira query no console falha pedindo um "query result location", e o
# usuário acaba configurando à mão — um passo manual fora do IaC, que é
# exatamente o que o requisito de reprodutibilidade quer evitar.
#
# O workgroup abaixo resolve isso e, de passagem, impõe duas políticas:
# resultado criptografado com a chave do projeto e teto de varredura por
# consulta.

resource "aws_athena_workgroup" "projeto_dm" {

  name        = "${var.name_bucket}-workgroup"
  description = "Workgroup do Projeto DM: resultado criptografado e limite de varredura"

  configuration {

    # Impede que a consulta sobrescreva as configurações do workgroup.
    # Sem isso, o local de resultado e a criptografia definidos aqui
    # seriam apenas sugestões.
    enforce_workgroup_configuration = true

    publish_cloudwatch_metrics_enabled = true

    # Teto de dados varridos por consulta. O Athena cobra por varredura:
    # um SELECT * sem filtro de partição em uma tabela grande é uma fatura
    # inesperada. O limite aborta a consulta em vez de cobrá-la.
    bytes_scanned_cutoff_per_query = var.bytes_scanned_cutoff

    result_configuration {

      # Resultado das consultas na mesma conta e região do Data Lake
      output_location = "s3://${var.name_bucket}/athena-results/"

      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = var.kms_key_arn
      }
    }
  }

  tags = {
    Name    = "${var.name_bucket}-workgroup"
    Project = "projeto-dm"
  }
}

# Consultas salvas. Ficam disponíveis no console do Athena, na aba "Saved
# queries", de modo que a demonstração não depende de digitar SQL de memória.
resource "aws_athena_named_query" "taxa_faltas_por_unidade" {
  name        = "projeto-dm-taxa-faltas-por-unidade"
  description = "Indicadores da camada CURATED: taxa de faltas por unidade de saude"
  database    = var.glue_db_name
  workgroup   = aws_athena_workgroup.projeto_dm.id

  query = <<-SQL
    SELECT unidade_saude,
           total_agendamentos,
           total_comparecimentos,
           taxa_faltas
    FROM faltas
    ORDER BY taxa_faltas DESC
    LIMIT 20;
  SQL
}

resource "aws_athena_named_query" "metricas_modelos" {
  name        = "projeto-dm-metricas-modelos"
  description = "Metricas dos modelos treinados, com a linha de base para comparacao"
  database    = var.glue_db_name
  workgroup   = aws_athena_workgroup.projeto_dm.id

  query = <<-SQL
    SELECT modelo, acuracia, f1, auc
    FROM metrics
    ORDER BY auc DESC;
  SQL
}

# Confirma que o mascaramento aconteceu: a consulta lê a camada PROCESSED
# e nenhum CPF ou telefone aparece em claro. É a verificação de privacidade
# feita pelo próprio consumidor do dado, não pela promessa do pipeline.
resource "aws_athena_named_query" "amostra_mascarada" {
  name        = "projeto-dm-amostra-mascarada"
  description = "Amostra da camada PROCESSED comprovando o mascaramento dos dados pessoais"
  database    = var.glue_db_name
  workgroup   = aws_athena_workgroup.projeto_dm.id

  query = <<-SQL
    SELECT nome_paciente, cpf, telefone, valor_procedimento, ano, mes
    FROM atendimentos
    LIMIT 10;
  SQL
}
