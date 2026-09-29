# Script Principal - orquestrador do job executado no Amazon EMR
#
# Todas as dependências são instaladas pelo bootstrap do cluster
# (scripts/bootstrap.sh). Instalar pacote em tempo de execução dentro do
# código torna a execução não determinística e mascara falhas de ambiente.

# Imports
import os
import boto3
import traceback
from pyspark.sql import SparkSession
from p_log import grava_log
from p_processamento import limpa_transforma_dados
from p_ml import cria_modelos_ml

# Nome do Bucket
# ATENÇÃO: substitua pelo nome real do seu bucket (sem credenciais no código)
NOME_BUCKET = os.environ.get("NOME_BUCKET", "projeto-dm-SEU_ACCOUNT_ID")

print("\nLog Inicializando o Processamento.")

# Cria um recurso de acesso ao S3 via boto3
# As credenciais são obtidas automaticamente via IAM Role do EMR (sem chaves no código)
s3_resource = boto3.resource('s3')

# Define o objeto de acesso ao bucket via Python
bucket = s3_resource.Bucket(NOME_BUCKET)

# Grava o log
grava_log("Log - Bucket Encontrado.", bucket)

# Grava o log
grava_log("Log - Inicializando o Apache Spark.", bucket)

# Cria a Spark Session e grava o log no caso de erro
try:
    spark = SparkSession.builder.appName("ProjetoDM").getOrCreate()
    spark.sparkContext.setLogLevel("ERROR")
except:
    grava_log("Log - Ocorreu uma falha na Inicialização do Spark", bucket)
    grava_log(traceback.format_exc(), bucket)
    raise Exception(traceback.format_exc())

# Grava o log
grava_log("Log - Spark Inicializado.", bucket)

# Define o ambiente de execução do Amazon EMR
ambiente_execucao_EMR = False if os.path.isdir('dados/') else True

# Bloco de limpeza, mascaramento e engenharia de atributos (RAW -> PROCESSED)
try:
    dados_atributos = limpa_transforma_dados(spark,
                                             bucket,
                                             NOME_BUCKET,
                                             ambiente_execucao_EMR)
except:
    grava_log("Log - Ocorreu uma falha na limpeza e transformação dos dados", bucket)
    grava_log(traceback.format_exc(), bucket)
    spark.stop()
    raise Exception(traceback.format_exc())

# Bloco de treinamento dos modelos de Machine Learning (PROCESSED -> CURATED)
try:
    cria_modelos_ml(spark,
                    dados_atributos,
                    bucket,
                    NOME_BUCKET,
                    ambiente_execucao_EMR)
except:
    grava_log("Log - Ocorreu Alguma Falha ao Criar os Modelos de Machine Learning", bucket)
    grava_log(traceback.format_exc(), bucket)
    spark.stop()
    raise Exception(traceback.format_exc())

# Grava o log
grava_log("Log - Modelos Criados e Salvos no S3.", bucket)

# Grava o log
grava_log("Log - Processamento Finalizado com Sucesso.", bucket)

# Finaliza o Spark (encerra o cluster EMR)
spark.stop()
