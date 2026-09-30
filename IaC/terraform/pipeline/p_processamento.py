# Processamento - RAW para PROCESSED e engenharia de atributos
#
# Domínio: atendimentos ambulatoriais de saúde pública.
# Alvo de negócio: prever quais pacientes faltam às consultas agendadas.

# Imports
from pyspark.ml import Pipeline
from pyspark.ml.feature import (
    StringIndexer,
    OneHotEncoder,
    VectorAssembler,
    StandardScaler,
)
from pyspark.sql.functions import (
    col,
    current_date,
    lit,
    month,
    sum as spark_sum,
    to_date,
    trim,
    year,
)
from pyspark.sql.types import DoubleType, IntegerType

from p_log import grava_log
from p_masking import aplica_mascaramento

# -------------------------------------------------------------------
# CONTRATO DE DADOS DA CAMADA RAW
# -------------------------------------------------------------------

# Colunas sensíveis e a técnica de mascaramento aplicada a cada uma.
# Colunas ausentes são ignoradas com registro em log, então o mesmo mapa
# atende qualquer nova fonte ingerida na camada RAW.
COLUNAS_SENSIVEIS = {
    "nome_paciente": "nome",
    "cpf": "cpf",
    "cnpj": "cnpj",
    "email": "email",
    "telefone": "telefone",
    "valor_procedimento": "financeiro",
}

# Atributos categóricos usados pelo modelo
COLUNAS_CATEGORICAS = [
    "uf",
    "municipio",
    "unidade_saude",
    "especialidade",
    "tipo_consulta",
    "canal_agendamento",
    # Após o mascaramento esta coluna vira uma faixa de valores (string) e
    # por isso entra no modelo como categórica — a privacidade é preservada
    # sem que o atributo perca poder preditivo.
    "valor_procedimento",
]

# Atributos numéricos usados pelo modelo
COLUNAS_NUMERICAS = [
    "idade",
    "dias_espera",
    "distancia_km",
    "consultas_anteriores",
    "faltas_anteriores",
]

# Coluna alvo da classificação
COLUNA_ALVO = "compareceu"


# -------------------------------------------------------------------
# UTILITÁRIOS
# -------------------------------------------------------------------

def calcula_valores_nulos(df):
    """Retorna [(coluna, qtd_nulos, pct_nulos)] para as colunas com nulos.

    Usa uma única agregação sobre todas as colunas. A versão ingênua —
    um df.where(...).count() por coluna — dispara uma varredura completa
    do dataset por coluna: com 19 colunas e volume alto, são 19 leituras
    do Data Lake apenas para contar nulos.
    """

    resultado = []
    total_linhas = df.count()

    if total_linhas == 0:
        return resultado

    # Uma passada só: conta os nulos de todas as colunas de uma vez
    contagens = df.agg(
        *[
            spark_sum(col(coluna).isNull().cast("int")).alias(coluna)
            for coluna in df.columns
        ]
    ).collect()[0]

    for coluna in df.columns:
        nulos = contagens[coluna] or 0
        if nulos > 0:
            resultado.append((coluna, nulos, (nulos / total_linhas) * 100))

    return resultado


def tipa_colunas(df):
    """Converte as colunas numéricas e a data para os tipos corretos.

    O CSV chega da camada RAW inteiramente como string; sem a tipagem
    explícita o modelo trataria números como categorias — e a camada
    PROCESSED ficaria com um schema diferente conforme quem a escrevesse.
    """

    if "data_atendimento" in df.columns:
        df = df.withColumn("data_atendimento", to_date(col("data_atendimento"), "yyyy-MM-dd"))

    for coluna in ["idade", "consultas_anteriores", "faltas_anteriores"]:
        if coluna in df.columns:
            df = df.withColumn(coluna, col(coluna).cast(IntegerType()))

    for coluna in ["distancia_km", "dias_espera"]:
        if coluna in df.columns:
            df = df.withColumn(coluna, col(coluna).cast(DoubleType()))

    if COLUNA_ALVO in df.columns:
        df = df.withColumn("label", col(COLUNA_ALVO).cast(DoubleType()))

    return df


def _monta_pipeline_atributos(df):
    """Monta o pipeline de engenharia de atributos do Spark ML.

    Categóricas -> StringIndexer -> OneHotEncoder
    Numéricas   -> VectorAssembler -> StandardScaler
    """

    categoricas = [c for c in COLUNAS_CATEGORICAS if c in df.columns]
    numericas = [c for c in COLUNAS_NUMERICAS if c in df.columns]

    estagios = []

    # Indexa e codifica cada atributo categórico
    for coluna in categoricas:
        indexer = StringIndexer(
            inputCol=coluna,
            outputCol=f"{coluna}_idx",
            handleInvalid="keep",
        )
        encoder = OneHotEncoder(
            inputCols=[f"{coluna}_idx"],
            outputCols=[f"{coluna}_ohe"],
            handleInvalid="keep",
        )
        estagios += [indexer, encoder]

    # Junta tudo em um único vetor de atributos
    colunas_vetor = [f"{c}_ohe" for c in categoricas] + numericas

    assembler = VectorAssembler(
        inputCols=colunas_vetor,
        outputCol="features_brutas",
        handleInvalid="skip",
    )

    # Padroniza a escala — essencial para a regressão logística convergir
    scaler = StandardScaler(
        inputCol="features_brutas",
        outputCol="features",
        withMean=False,
        withStd=True,
    )

    estagios += [assembler, scaler]

    return Pipeline(stages=estagios)


# -------------------------------------------------------------------
# TRANSIÇÃO RAW -> PROCESSED
#
# Esta é a ÚNICA implementação da transformação. Tanto o job do Glue
# (glue_job_etl.py) quanto o pipeline do EMR (projeto.py) a utilizam.
#
# A duplicação seria perigosa aqui: os dois caminhos gravam no mesmo
# prefixo da camada PROCESSED, então qualquer divergência — uma coluna
# tipada em um e não no outro, uma máscara aplicada só de um lado —
# produziria schemas conflitantes na mesma tabela do Data Catalog.
# -------------------------------------------------------------------

def le_camada_raw(spark, caminho_raw, bucket=None):
    """Lê o CSV bruto da sub-camada de lote da RAW."""

    grava_log("Log - Importando os dados da camada RAW: " + caminho_raw, bucket)

    df = (
        spark.read
        .option("header", "true")
        .option("escape", '"')
        .csv(caminho_raw)
    )

    grava_log("Log - Total de registros lidos: " + str(df.count()), bucket)

    return df


def le_camada_streaming(spark, caminho_streaming, colunas, bucket=None):
    """Lê os eventos entregues pelo Firehose e os alinha ao schema do lote.

    As duas vias de ingestão gravam em formatos diferentes: o lote em CSV, o
    streaming em JSON Lines comprimido. Para que a convergência seja real, e
    não apenas um destino comum no S3, o streaming é lido aqui e convertido
    para o mesmo schema textual do CSV. A tipagem acontece depois, uma única
    vez, sobre os dois caminhos já unidos.

    Colunas que o evento não trouxer entram nulas, e colunas a mais são
    descartadas: o contrato de dados é o da camada de lote.

    Devolve None quando ainda não existe evento algum. Ausência de streaming
    não é erro — é o estado normal de uma execução que só teve carga em lote.
    """

    grava_log("Log - Procurando eventos na sub-camada de streaming da RAW.", bucket)

    try:
        df = spark.read.json(caminho_streaming)
    except Exception as erro:
        grava_log(f"Log - Sem dados de streaming para unir ({erro}).", bucket)
        return None

    if not df.columns:
        grava_log("Log - Sub-camada de streaming vazia.", bucket)
        return None

    for coluna in colunas:
        if coluna not in df.columns:
            df = df.withColumn(coluna, lit(None))

    df = df.select([col(c).cast("string").alias(c) for c in colunas])

    grava_log("Log - Eventos de streaming lidos: " + str(df.count()), bucket)

    return df


def le_camada_raw_unificada(spark, caminho_batch, caminho_streaming, bucket=None):
    """Une as duas vias de ingestão num único DataFrame.

    É aqui que a arquitetura Lambda se fecha. A partir deste ponto existe um
    caminho de tratamento só — mascaramento, limpeza, tipagem e particionamento
    —, aplicado sobre lote e streaming sem distinção.
    """

    df = le_camada_raw(spark, caminho_batch, bucket)

    if not caminho_streaming:
        return df

    df_streaming = le_camada_streaming(spark, caminho_streaming, df.columns, bucket)

    if df_streaming is None:
        return df

    df = df.unionByName(df_streaming)

    grava_log("Log - Total apos unir lote e streaming: " + str(df.count()), bucket)

    return df


def transforma_raw_para_processed(spark, df, bucket=None):
    """Mascara, limpa, tipa e particiona os dados da camada RAW.

    Retorna o DataFrame pronto para gravação na camada PROCESSED.
    """

    # -----------------------------------------------------------
    # MASCARAMENTO (LGPD)
    # Aplicado imediatamente após a leitura e antes de qualquer
    # gravação: dado pessoal em claro nunca sai da camada RAW.
    # -----------------------------------------------------------
    df = aplica_mascaramento(spark, df, bucket, COLUNAS_SENSIVEIS)

    # -----------------------------------------------------------
    # LIMPEZA
    # -----------------------------------------------------------
    grava_log("Log - Verificando valores nulos.", bucket)

    nulos = calcula_valores_nulos(df)

    if len(nulos) > 0:
        for coluna, qtd, pct in nulos:
            grava_log(f"Coluna {coluna} possui {qtd} nulos ({pct:.2f}%)", bucket)
    else:
        grava_log("Log - Valores ausentes nao foram detectados.", bucket)

    # Normaliza strings vazias vindas do CSV e descarta registros incompletos
    for coluna in df.columns:
        df = df.withColumn(coluna, trim(col(coluna)))

    df = df.replace("", None)

    # As colunas essenciais ao negócio e ao modelo não podem ter nulos
    colunas_obrigatorias = [
        c
        for c in (COLUNAS_CATEGORICAS + COLUNAS_NUMERICAS + [COLUNA_ALVO, "data_atendimento"])
        if c in df.columns
    ]
    df = df.dropna(subset=colunas_obrigatorias)

    grava_log("Log - Total de registros apos a limpeza: " + str(df.count()), bucket)

    # -----------------------------------------------------------
    # TIPAGEM E PARTICIONAMENTO
    # -----------------------------------------------------------
    df = tipa_colunas(df)

    # Partições derivadas da data de negócio.
    # Optamos por ano/mes em vez de ano/mes/dia: com a volumetria atual, o
    # particionamento diário geraria centenas de arquivos pequenos e
    # degradaria a leitura no Athena (problema clássico de small files).
    df = (
        df.withColumn("ano", year(col("data_atendimento")))
          .withColumn("mes", month(col("data_atendimento")))
          .withColumn("data_ingestao", current_date())
    )

    return df


def grava_camada_processed(df, caminho_processed, bucket=None):
    """Grava o DataFrame tratado na camada PROCESSED, particionado por ano/mes."""

    grava_log("Log - Gravando dados limpos e mascarados na camada PROCESSED.", bucket)

    (
        df.write
        .mode("overwrite")
        .partitionBy("ano", "mes")
        .parquet(caminho_processed)
    )

    grava_log("Log - Camada PROCESSED atualizada: " + caminho_processed, bucket)


# -------------------------------------------------------------------
# FUNÇÃO PRINCIPAL — usada pelo pipeline do EMR
# -------------------------------------------------------------------

def limpa_transforma_dados(spark, bucket, nome_bucket, ambiente_execucao_EMR):
    """Executa a transição RAW -> PROCESSED e devolve o DataFrame de atributos.

    Retorna:
        df_features : DataFrame com as colunas 'features' e 'label',
                      pronto para o treinamento em p_ml.py
    """

    # As duas sub-camadas da RAW. Localmente só existe o lote.
    path_batch = (
        f"s3://{nome_bucket}/raw/batch/" if ambiente_execucao_EMR else "dados/dataset.csv"
    )
    path_streaming = (
        f"s3://{nome_bucket}/raw/streaming/" if ambiente_execucao_EMR else None
    )

    path_processed = (
        f"s3://{nome_bucket}/processed/atendimentos/"
        if ambiente_execucao_EMR
        else "dados/processed/atendimentos/"
    )

    # Leitura e transformação — mesmo código executado pelo job do Glue
    df = le_camada_raw_unificada(spark, path_batch, path_streaming, bucket)
    df = transforma_raw_para_processed(spark, df, bucket)

    grava_log("Log - Verificando o balanceamento de classes.", bucket)

    compareceram = df.where(col("label") == 1).count()
    faltaram = df.where(col("label") == 0).count()

    grava_log(f"Log - {compareceram} comparecimentos e {faltaram} faltas.", bucket)

    grava_camada_processed(df, path_processed, bucket)

    # -----------------------------------------------------------
    # ENGENHARIA DE ATRIBUTOS PARA O MODELO
    # -----------------------------------------------------------
    grava_log("Log - Montando o pipeline de atributos do Spark ML.", bucket)

    pipeline_atributos = _monta_pipeline_atributos(df)
    modelo_atributos = pipeline_atributos.fit(df)
    df_features = modelo_atributos.transform(df).select("features", "label")

    # Mantém os dados em memória: serão lidos várias vezes no treinamento
    df_features.cache()

    grava_log("Log - Pipeline de atributos aplicado com sucesso.", bucket)

    # Persiste o modelo de atributos para reuso em inferência
    if ambiente_execucao_EMR:
        modelo_atributos.write().overwrite().save(
            f"s3://{nome_bucket}/curated/models/pipeline_atributos"
        )
        grava_log("Log - Pipeline de atributos salvo na camada CURATED.", bucket)

    return df_features
