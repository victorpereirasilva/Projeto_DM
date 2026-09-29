# Machine Learning - treinamento e avaliação dos modelos de faltas
#
# Recebe o DataFrame de atributos produzido por p_processamento.py, treina
# os classificadores com validação cruzada, grava os modelos e o quadro de
# métricas na camada CURATED do Data Lake.

from pyspark.ml.classification import LogisticRegression, RandomForestClassifier
from pyspark.ml.evaluation import (
    BinaryClassificationEvaluator,
    MulticlassClassificationEvaluator,
)
from pyspark.ml.tuning import CrossValidator, ParamGridBuilder
from pyspark.sql.functions import col, lit

from p_log import grava_log

# Colunas do quadro consolidado de métricas
COLUNAS_METRICAS = ["modelo", "acuracia", "f1", "auc"]


def _grade_de_parametros(classificador):
    """Define a grade de hiperparâmetros conforme o tipo de classificador."""

    nome = type(classificador).__name__

    if nome == "LogisticRegression":
        return (
            ParamGridBuilder()
            .addGrid(classificador.regParam, [0.0, 0.01, 0.1])
            .addGrid(classificador.maxIter, [20, 50])
            .build()
        )

    if nome == "RandomForestClassifier":
        return (
            ParamGridBuilder()
            .addGrid(classificador.numTrees, [40, 80])
            .addGrid(classificador.maxDepth, [5, 10])
            .build()
        )

    # Sem grade definida: treina o classificador com os parâmetros padrão
    return ParamGridBuilder().build()


def treina_avalia_modelo(spark, classificador, treino, teste, bucket,
                         nome_bucket, ambiente_execucao_EMR):
    """Treina um classificador com validação cruzada e devolve suas métricas.

    Retorna:
        DataFrame de uma linha com modelo, acuracia, f1 e auc
    """

    nome_modelo = type(classificador).__name__

    grava_log(f"Log - Treinando o modelo {nome_modelo}.", bucket)

    # Validação cruzada otimizando a área sob a curva ROC
    validacao_cruzada = CrossValidator(
        estimator=classificador,
        estimatorParamMaps=_grade_de_parametros(classificador),
        evaluator=BinaryClassificationEvaluator(metricName="areaUnderROC"),
        numFolds=3,
        parallelism=2,
    )

    modelo_ajustado = validacao_cruzada.fit(treino)
    melhor_modelo = modelo_ajustado.bestModel

    # Previsões sobre o conjunto de teste
    previsoes = melhor_modelo.transform(teste)

    # Métricas de avaliação
    acuracia = MulticlassClassificationEvaluator(metricName="accuracy").evaluate(previsoes)
    f1 = MulticlassClassificationEvaluator(metricName="f1").evaluate(previsoes)
    auc = BinaryClassificationEvaluator(metricName="areaUnderROC").evaluate(previsoes)

    grava_log(
        f"Log - {nome_modelo} | acuracia: {acuracia:.4f} | f1: {f1:.4f} | auc: {auc:.4f}",
        bucket,
    )

    # Grava o melhor modelo na camada CURATED
    caminho_modelo = (
        f"s3://{nome_bucket}/curated/models/{nome_modelo}"
        if ambiente_execucao_EMR
        else f"dados/curated/models/{nome_modelo}"
    )

    try:
        melhor_modelo.write().overwrite().save(caminho_modelo)
        grava_log(f"Log - Modelo {nome_modelo} salvo em {caminho_modelo}", bucket)
    except Exception as erro:
        grava_log(f"Log - Falha ao salvar o modelo {nome_modelo}: {erro}", bucket)

    # Monta a linha de métricas deste modelo
    return spark.createDataFrame(
        [(nome_modelo, float(acuracia), float(f1), float(auc))],
        schema=COLUNAS_METRICAS,
    )


def cria_modelos_ml(spark, df_features, bucket, nome_bucket, ambiente_execucao_EMR):
    """Treina todos os classificadores e consolida as métricas na camada CURATED.

    Parâmetros:
        df_features : DataFrame com as colunas 'features' e 'label'

    Retorna:
        DataFrame consolidado com as métricas de todos os modelos
    """

    # Classificadores avaliados. Incluir um novo modelo é adicionar um item aqui.
    classificadores = [
        LogisticRegression(featuresCol="features", labelCol="label"),
        RandomForestClassifier(featuresCol="features", labelCol="label", seed=11),
    ]

    # Divisão treino/teste com semente fixa, para resultados reproduzíveis
    treino, teste = df_features.randomSplit([0.7, 0.3], seed=11)

    treino.cache()
    teste.cache()

    grava_log(
        f"Log - Registros de treino: {treino.count()} | de teste: {teste.count()}",
        bucket,
    )

    # -----------------------------------------------------------
    # LINHA DE BASE
    # Com ~76% de comparecimento, um "modelo" que sempre prevê a classe
    # majoritária já acerta 76% das vezes. Sem essa referência explícita,
    # a acurácia dos modelos parece boa e não diz nada. É por isso que a
    # métrica de decisão aqui é a AUC, e não a acurácia.
    # -----------------------------------------------------------
    total_teste = teste.count()
    positivos_teste = teste.where(col("label") == 1).count()
    acuracia_base = max(positivos_teste, total_teste - positivos_teste) / total_teste

    grava_log(
        f"Log - Linha de base (classe majoritaria) | acuracia: {acuracia_base:.4f} | auc: 0.5000",
        bucket,
    )

    resultados = spark.createDataFrame(
        [("Baseline_ClasseMajoritaria", float(acuracia_base), 0.0, 0.5)],
        schema=COLUNAS_METRICAS,
    )

    for classificador in classificadores:

        metricas = treina_avalia_modelo(
            spark,
            classificador,
            treino,
            teste,
            bucket,
            nome_bucket,
            ambiente_execucao_EMR,
        )

        resultados = resultados.union(metricas)

    # Grava o quadro de métricas na camada CURATED, consultável no Athena
    if resultados is not None:

        resultados = resultados.withColumn("versao_execucao", lit("v1"))

        if ambiente_execucao_EMR:
            grava_log("Log - Gravando metricas dos modelos na camada CURATED.", bucket)
            (
                resultados.coalesce(1)
                .write.mode("overwrite")
                .parquet(f"s3://{nome_bucket}/curated/metrics/")
            )
        else:
            resultados.show(truncate=False)

    return resultados
