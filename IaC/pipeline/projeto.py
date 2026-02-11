# Script Principal

# Instala pacote Python dentro de código Python
import subprocess
comando = "python3 -m pip install boto3"
subprocess.run(comando.split())

# Imports
import os
import boto3
import traceback
import pyspark 
from pyspark.sql import SparkSession
from p_log import grava_log
from p_processamento import limpa_transforma_dados
from p_ml import cria_modelos_ml

# Nome do Bucket
NOME_BUCKET = "projeto-dm-381492141074"

# Chaves de acesso à AWS
#AWSACCESSKEYID = ""
#AWSSECRETKEY = ""

print("\nLog Inicializando o Processamento.")

# Cria um recurso de acesso ao S3 via código Python
s3_resource = boto3.resource('s3', aws_access_key_id = AWSACCESSKEYID, aws_secret_access_key = AWSSECRETKEY)

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

# Bloco de limpeza e transformação
try:
	DadosHTFfeaturized, DadosTFIDFfeaturized, DadosW2Vfeaturized = limpa_transforma_dados(spark, 
																							  bucket, 
																							  NOME_BUCKET, 
																							  ambiente_execucao_EMR)
except:
	grava_log("Log - Ocorreu uma falha na limpeza e transformação dos dados", bucket)
	grava_log(traceback.format_exc(), bucket)
	spark.stop()
	raise Exception(traceback.format_exc())

# Bloco de criação dos modelos de Machine Learning usando a saida do bloco de limpeza
try:
	cria_modelos_ml (spark, 
					     DadosHTFfeaturized, 
					     DadosTFIDFfeaturized, 
					     DadosW2Vfeaturized, 
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



