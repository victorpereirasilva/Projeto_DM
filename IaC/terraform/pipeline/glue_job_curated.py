# Projeto DM - Job AWS Glue: curadoria da camada PROCESSED para a camada CURATED
#
# Responsabilidades deste job:
#   1. Ler os dados limpos e mascarados da camada PROCESSED
#   2. Gerar os indicadores de faltas por unidade, especialidade e período
#   3. Gravar em Parquet na camada CURATED, pronta para Athena e QuickSight
#
# O treinamento dos modelos de Machine Learning permanece no Amazon EMR
# (pipeline/projeto.py), que é o motor de processamento distribuído do case.
# Este job cuida da curadoria analítica consumida pela área de negócio.

import sys

import boto3
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql.functions import avg, col, count, round as spark_round, sum as spark_sum

# Módulo do projeto, enviado ao job via --extra-py-files
from p_log import grava_log

# -------------------------------------------------------------------
# PARÂMETROS DO JOB
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

bucket = boto3.resource("s3").Bucket(NOME_BUCKET)

caminho_origem = f"s3://{NOME_BUCKET}/{PREFIXO_ORIGEM}atendimentos/"
caminho_destino = f"s3://{NOME_BUCKET}/{PREFIXO_DESTINO}"

grava_log(f"Log - Glue Curadoria iniciada. Origem: {caminho_origem}", bucket)

# -------------------------------------------------------------------
# 1. LEITURA DA CAMADA PROCESSED
# -------------------------------------------------------------------

df = spark.read.parquet(caminho_origem)

grava_log(f"Log - Registros lidos da camada PROCESSED: {df.count()}", bucket)

# A coluna alvo chega como string do CSV original; converte para numérico
df = df.withColumn("compareceu_num", col("compareceu").cast("double"))

# -------------------------------------------------------------------
# 2. INDICADORES ANALÍTICOS DE ABSENTEÍSMO
# -------------------------------------------------------------------

colunas_agrupamento = [
    c
    for c in ["ano", "mes", "uf", "unidade_saude", "especialidade"]
    if c in df.columns
]

indicadores = (
    df.groupBy(*colunas_agrupamento)
    .agg(
        count("*").alias("total_agendamentos"),
        spark_sum("compareceu_num").alias("total_comparecimentos"),
        spark_round(avg("dias_espera"), 2).alias("media_dias_espera"),
        spark_round(avg("distancia_km"), 2).alias("media_distancia_km"),
    )
)

# Taxa de faltas: o indicador que a área de negócio acompanha
indicadores = indicadores.withColumn(
    "taxa_faltas",
    spark_round(
        1 - (col("total_comparecimentos") / col("total_agendamentos")), 4
    ),
)

grava_log("Log - Indicadores de faltas calculados.", bucket)

# -------------------------------------------------------------------
# 3. GRAVAÇÃO NA CAMADA CURATED
# -------------------------------------------------------------------

colunas_particao = [c for c in ["ano", "mes"] if c in indicadores.columns]

escrita = indicadores.write.mode("overwrite")

if colunas_particao:
    escrita = escrita.partitionBy(*colunas_particao)

escrita.parquet(f"{caminho_destino}analytics/faltas/")

grava_log(
    f"Log - Curadoria concluida. Dados em {caminho_destino}analytics/faltas/",
    bucket,
)

job.commit()
