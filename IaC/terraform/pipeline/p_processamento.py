# Processamento

# Imports
import os
import os.path
import numpy
from pyspark.ml.feature import * 
from pyspark.sql import functions
from pyspark.sql.functions import * 
from pyspark.sql.types import StringType,IntegerType
from pyspark.ml.classification import *
from pyspark.ml.evaluation import *
from pyspark.ml.evaluation import MulticlassClassificationEvaluator
from pyspark.ml.feature import StopWordsRemover
from pyspark.ml.tuning import CrossValidator, ParamGridBuilder
from p_log import grava_log
from p_upload_s3 import upload_dados_processados_bucket

# Define uma função para calcular a quantidade e a porcentagem de valores nulos em cada coluna de um DataFrame
def calcula_valores_nulos(df):
    
    # Inicializa uma lista vazia para armazenar o resultado de contagem de nulos
    null_columns_counts = []
    
    # Conta o número total de linhas no DataFrame
    numRows = df.count()

    # Itera sobre cada coluna no DataFrame
    for k in df.columns:
        
        # Conta o número de linhas nulas na coluna atual
        nullRows = df.where(col(k).isNull()).count()
        
        # Verifica se o número de linhas nulas é maior que zero
        if(nullRows > 0):
            
            # Cria uma tupla com o nome da coluna, número de nulos e a porcentagem de nulos
            temp = k, nullRows, (nullRows / numRows) * 100
            
            # Adiciona a tupla à lista de resultados
            null_columns_counts.append(temp)

    # Retorna a lista de colunas com a contagem e porcentagem de valores nulos
    return null_columns_counts

# Função para limpeza e transformação
def limpa_transforma_dados(spark, bucket, nome_bucket, ambiente_execucao_EMR):
	
	# Define o caminho para armazenar o resultado do processamento
	path =  f"s3://{nome_bucket}/dados/" if ambiente_execucao_EMR else  "dados/"

	# Grava no log
	grava_log("Log - Importando os dados...", bucket)

	# Carrega o arquivo CSV
	reviews = spark.read.csv(path+'dataset.csv', header=True, escape="\"")

	# Grava no log
	grava_log("Log - Dados Importados com Sucesso.", bucket)
	grava_log("Log - Total de Registros: " + str(reviews.count()), bucket)
	grava_log("Log - Verificando se Existem Dados Nulos.", bucket)

	# Calcula os valores ausentes
	null_columns_calc_list = calcula_valores_nulos(reviews)

	# Ação com base nos valores ausentes
	if (len(null_columns_calc_list) > 0):
		for column in null_columns_calc_list:
			grava_log("Coluna " + str(column[0]) + " possui " + str(column[2]) + " de dados nulos", bucket)
		reviews = reviews.dropna()
		grava_log("Dados nulos excluídos", bucket)
		grava_log("Log - Total de Registros Depois da Limpeza: " + str(reviews.count()), bucket)
	else:
		grava_log("Log - Valores Ausentes Nao Foram Detectados.", bucket)

	# Grava no log
	grava_log("Log - Verificando o Balanceamento de Classes.", bucket)
	
	# Conta os registros de avaliações positivas e negativas
	count_positive_sentiment = reviews.where(reviews['sentiment'] == "positive").count()
	count_negative_sentiment = reviews.where(reviews['sentiment'] == "negative").count()

	# Grava no log
	grava_log("Log - Existem " + str(count_positive_sentiment) + " reviews positivos e " + str(count_negative_sentiment) + " reviews negativos", bucket)

	# Cria o dataframe
	df = reviews

	# Grava no log
	grava_log("Log - Transformando os Dados", bucket)
	
	# Cria o indexador
	indexer = StringIndexer(inputCol="sentiment", outputCol="label")
	
	# Treina o indexador
	df = indexer.fit(df).transform(df)

	# Grava no log
	grava_log("Log - Limpeza dos Dados", bucket)
	
	# Remove caracteres especiais dos dados de texto
	df = df.withColumn("review", regexp_replace(df["review"], '<.*/>', ''))
	df = df.withColumn("review", regexp_replace(df["review"], '[^A-Za-z ]+', ''))
	df = df.withColumn("review", regexp_replace(df["review"], ' +', ' '))
	df = df.withColumn("review", lower(df["review"]))

	# Grava no log
	grava_log("Log - Os Dados de Texto Foram Limpos", bucket)
	grava_log("Log - Tokenizando os Dados de Texto.", bucket)

	# Cria o tokenizador (converte dados de texto em representações numéricas)
	regex_tokenizer = RegexTokenizer(inputCol="review", outputCol="words", pattern="\\W")

	# Aplica o tokenizador
	df = regex_tokenizer.transform(df)

	# Grava no log
	grava_log("Log - Removendo Stop Words.", bucket)

	# Cria o objeto para remover stop words
	remover = StopWordsRemover(inputCol="words", outputCol="filtered")

	# Aplica o objeto e remove stop words
	feature_data = remover.transform(df)

	# Grava no log
	grava_log("Log - Aplicando HashingTF.", bucket)

	# Cria e aplica o processador de texto
	hashingTF = HashingTF(inputCol="filtered", outputCol="rawfeatures", numFeatures=250)
	HTFfeaturizedData = hashingTF.transform(feature_data)

	# Grava no log
	grava_log("Log - Aplicando IDF.", bucket)

	# Cria e aplica o processador de texto
	idf = IDF(inputCol="rawfeatures", outputCol="features")
	idfModel = idf.fit(HTFfeaturizedData)
	TFIDFfeaturizedData = idfModel.transform(HTFfeaturizedData)
	
	# Ajusta o nome dos objetos
	TFIDFfeaturizedData.name = 'TFIDFfeaturizedData'
	HTFfeaturizedData = HTFfeaturizedData.withColumnRenamed("rawfeatures","features")
	HTFfeaturizedData.name = 'HTFfeaturizedData' 

	# Grava no log
	grava_log("Log Aplicando Word2Vec.", bucket)

	# Cria e aplica o processador de texto
	word2Vec = Word2Vec(vectorSize=250, minCount=5, inputCol="filtered", outputCol="features")
	model = word2Vec.fit(feature_data)
	W2VfeaturizedData = model.transform(feature_data)

	# Grava no log
	grava_log("Log Padronizando os Dados com MinMaxScaler.", bucket)

	# Cria e aplica o padronizador
	scaler = MinMaxScaler(inputCol="features", outputCol="scaledFeatures")
	scalerModel = scaler.fit(W2VfeaturizedData)
	scaled_data = scalerModel.transform(W2VfeaturizedData)
	
	# Ajusta o nome dos objetos
	W2VfeaturizedData = scaled_data.select('sentiment','review','label','scaledFeatures')
	W2VfeaturizedData = W2VfeaturizedData.withColumnRenamed('scaledFeatures','features')
	W2VfeaturizedData.name = 'W2VfeaturizedData'

	# Grava no log
	grava_log("Log - Salvando os Dados Limpos e Transformados.", bucket)

	# Define o caminho para salvar o resultado
	path = f"s3://{nome_bucket}/dados/" if ambiente_execucao_EMR else 'dados/'
	s3_path = 'dados/'

	# Upload para o bucket S3
	upload_dados_processados_bucket(HTFfeaturizedData, path + 'HTFfeaturizedData', s3_path + 'HTFfeaturizedData' , bucket, ambiente_execucao_EMR)
	upload_dados_processados_bucket(TFIDFfeaturizedData, path + 'TFIDFfeaturizedData', s3_path + 'TFIDFfeaturizedData', bucket, ambiente_execucao_EMR)
	upload_dados_processados_bucket(W2VfeaturizedData, path + 'W2VfeaturizedData', s3_path + 'W2VfeaturizedData', bucket, ambiente_execucao_EMR)

	return HTFfeaturizedData, TFIDFfeaturizedData, W2VfeaturizedData


	