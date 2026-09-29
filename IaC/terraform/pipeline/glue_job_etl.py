# Projeto DM - Job AWS Glue: ETL da camada RAW para a camada PROCESSED
#
# Este é o caminho batch agendado do pipeline. Ele lê os dados brutos,
# aplica o mascaramento de dados sensíveis (LGPD), limpa, tipa, particiona
# e grava na camada PROCESSED.
#
# Toda a transformação vem de p_processamento.py — a MESMA implementação
# usada pelo pipeline do Amazon EMR. Isso é deliberado: os dois caminhos
# gravam no mesmo prefixo da camada PROCESSED, e uma segunda implementação
# aqui abriria espaço para schemas divergentes na mesma tabela do catálogo.
#
# Diferente dos módulos p_*.py (que são bibliotecas), este arquivo é um job
# executável do Glue: possui getResolvedOptions, GlueContext e job.commit().

import sys

import boto3
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext

# Módulos do projeto, enviados ao job via --extra-py-files
from p_log import grava_log
from p_processamento import (
    grava_camada_processed,
    le_camada_raw,
    transforma_raw_para_processed,
)

# -------------------------------------------------------------------
# PARÂMETROS DO JOB
# Recebidos via default_arguments do recurso aws_glue_job no Terraform
# -------------------------------------------------------------------

args = getResolvedOptions(
    sys.argv,
    ["JOB_NAME", "SOURCE_BUCKET", "SOURCE_PREFIX", "TARGET_PREFIX"],
)

NOME_BUCKET = args["SOURCE_BUCKET"]
PREFIXO_ORIGEM = args["SOURCE_PREFIX"]
PREFIXO_DESTINO = args["TARGET_PREFIX"]

# -------------------------------------------------------------------
# INICIALIZAÇÃO DO CONTEXTO GLUE / SPARK
# -------------------------------------------------------------------

sc = SparkContext.getOrCreate()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

# Objeto de acesso ao bucket para envio dos arquivos de log
bucket = boto3.resource("s3").Bucket(NOME_BUCKET)

caminho_origem = f"s3://{NOME_BUCKET}/{PREFIXO_ORIGEM}"
caminho_destino = f"s3://{NOME_BUCKET}/{PREFIXO_DESTINO}atendimentos/"

grava_log(f"Log - Glue ETL iniciado. Origem: {caminho_origem}", bucket)

# -------------------------------------------------------------------
# EXECUÇÃO — leitura, transformação e gravação
# -------------------------------------------------------------------

df = le_camada_raw(spark, caminho_origem, bucket)

df = transforma_raw_para_processed(spark, df, bucket)

grava_camada_processed(df, caminho_destino, bucket)

grava_log(f"Log - Glue ETL concluido. Dados gravados em {caminho_destino}", bucket)

job.commit()
