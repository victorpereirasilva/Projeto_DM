# Mascaramento de Dados Sensíveis - Conformidade LGPD

# Imports
import re
import hashlib
from pyspark.sql import DataFrame
from pyspark.sql import functions as F
from pyspark.sql.types import StringType
from p_log import grava_log

# -------------------------------------------------------------------
# FUNÇÕES DE MASCARAMENTO
# Aplicadas na camada RAW → PROCESSED para garantir que dados
# sensíveis nunca cheguem às camadas de consumo sem tratamento
# -------------------------------------------------------------------

# Mascara CPF: mantém apenas os 3 últimos dígitos visíveis
# Exemplo: 123.456.789-00 → ***.***.789-**
def mascara_cpf(cpf):
    if cpf is None:
        return None
    cpf_limpo = re.sub(r'[^0-9]', '', str(cpf))
    if len(cpf_limpo) != 11:
        return cpf
    return f"***.***.{cpf_limpo[6:9]}-**"

# Mascara CNPJ: mantém apenas os 4 dígitos do meio visíveis
# Exemplo: 12.345.678/0001-90 → **.***.***/****-**
def mascara_cnpj(cnpj):
    if cnpj is None:
        return None
    return re.sub(r'\d', '*', str(cnpj))

# Pseudonimiza nome: substitui por um ID derivado de hash
# Exemplo: João Silva → ID_a3f1b2c4
def pseudonimiza_nome(nome):
    if nome is None:
        return None
    hash_val = hashlib.sha256(str(nome).encode()).hexdigest()[:8]
    return f"ID_{hash_val}"

# Mascara e-mail com hash SHA-256
# Exemplo: joao@email.com → a3f1b2c4d5e6f7a8...
def mascara_email(email):
    if email is None:
        return None
    return hashlib.sha256(str(email).encode()).hexdigest()

# Mascara telefone: mantém DDD e últimos 4 dígitos
# Exemplo: (11) 99999-9999 → (11) ****-9999
def mascara_telefone(telefone):
    if telefone is None:
        return None
    tel_limpo = re.sub(r'[^0-9]', '', str(telefone))
    if len(tel_limpo) == 11:
        return f"({tel_limpo[:2]}) ****-{tel_limpo[7:]}"
    elif len(tel_limpo) == 10:
        return f"({tel_limpo[:2]}) ***-{tel_limpo[6:]}"
    return re.sub(r'\d', '*', str(telefone))

# Mascara dados financeiros: substitui valor por faixa
# Exemplo: 1500.00 → "1001-2000"
def mascara_valor_financeiro(valor):
    if valor is None:
        return None
    try:
        v = float(valor)
        if v <= 0:
            return "0"
        elif v <= 100:
            return "1-100"
        elif v <= 500:
            return "101-500"
        elif v <= 1000:
            return "501-1000"
        elif v <= 2000:
            return "1001-2000"
        elif v <= 5000:
            return "2001-5000"
        elif v <= 10000:
            return "5001-10000"
        else:
            return "10000+"
    except:
        return None

# -------------------------------------------------------------------
# REGISTRO DAS UDFs NO SPARK
# -------------------------------------------------------------------

udf_mascara_cpf              = F.udf(mascara_cpf, StringType())
udf_pseudonimiza_nome        = F.udf(pseudonimiza_nome, StringType())
udf_mascara_email            = F.udf(mascara_email, StringType())
udf_mascara_telefone         = F.udf(mascara_telefone, StringType())
udf_mascara_valor_financeiro = F.udf(mascara_valor_financeiro, StringType())
udf_mascara_cnpj             = F.udf(mascara_cnpj, StringType())

# -------------------------------------------------------------------
# FUNÇÃO PRINCIPAL DE MASCARAMENTO
# Recebe um DataFrame e a lista de colunas sensíveis a mascarar
# -------------------------------------------------------------------

def aplica_mascaramento(spark, df: DataFrame, bucket, colunas_sensiveis: dict) -> DataFrame:
    """
    Aplica mascaramento nas colunas sensíveis de um DataFrame Spark.

    Parâmetros:
        spark              : SparkSession ativa
        df                 : DataFrame de entrada (camada RAW)
        bucket             : objeto S3 para gravação de logs
        colunas_sensiveis  : dicionário no formato {nome_coluna: tipo_mascara}
                             Tipos suportados: 'cpf', 'cnpj', 'nome', 'email',
                                               'telefone', 'financeiro'

    Retorna:
        DataFrame com as colunas sensíveis mascaradas
    """

    grava_log("Log - Iniciando mascaramento de dados sensíveis (LGPD).", bucket)

    # Mapa de tipos de máscara para as UDFs correspondentes
    mapa_udf = {
        "cpf"        : udf_mascara_cpf,
        "cnpj"       : udf_mascara_cnpj,
        "nome"       : udf_pseudonimiza_nome,
        "email"      : udf_mascara_email,
        "telefone"   : udf_mascara_telefone,
        "financeiro" : udf_mascara_valor_financeiro,
    }

    df_mascarado = df

    # Aplica a UDF correspondente em cada coluna sensível
    for coluna, tipo in colunas_sensiveis.items():

        # Verifica se a coluna existe no DataFrame
        if coluna not in df.columns:
            grava_log(f"Log - Coluna '{coluna}' não encontrada no DataFrame. Ignorando.", bucket)
            continue

        # Verifica se o tipo de máscara é suportado
        if tipo not in mapa_udf:
            grava_log(f"Log - Tipo de máscara '{tipo}' não suportado para coluna '{coluna}'. Ignorando.", bucket)
            continue

        # Aplica a máscara
        df_mascarado = df_mascarado.withColumn(coluna, mapa_udf[tipo](F.col(coluna)))
        grava_log(f"Log - Coluna '{coluna}' mascarada com tipo '{tipo}'.", bucket)

    grava_log("Log - Mascaramento concluído com sucesso.", bucket)

    return df_mascarado


# -------------------------------------------------------------------
# EXEMPLO DE USO
# -------------------------------------------------------------------

# Para usar no p_processamento.py, importe e chame assim:
#
# from p_masking import aplica_mascaramento
#
# colunas_sensiveis = {
#     "cpf"      : "cpf",
#     "nome"     : "nome",
#     "email"    : "email",
#     "telefone" : "telefone",
#     "salario"  : "financeiro"
# }
#
# df_mascarado = aplica_mascaramento(spark, df_raw, bucket, colunas_sensiveis)
