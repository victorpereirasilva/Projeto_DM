# Geração de Log

# Importa o módulo os para interagir com o sistema operacional
import os

# Importa o módulo os.path para manipulação de caminhos de arquivo
import os.path

# Importa datetime da biblioteca padrão (não exige instalação em runtime,
# o que garante funcionamento tanto no EMR quanto no AWS Glue)
from datetime import datetime, timezone

# Importa o módulo traceback para rastrear exceções
import traceback


# Descobre um diretório de logs gravável no ambiente atual
# Local: ./logs   |   EMR: /home/hadoop/logs   |   Glue: /tmp/logs
def _diretorio_de_logs():

    # Ordem de preferência dos diretórios base
    candidatos = [".", "/home/hadoop", "/tmp"]

    for base in candidatos:
        caminho = os.path.join(base, "logs")
        try:
            # Cria o diretório se ainda não existir
            os.makedirs(caminho, exist_ok=True)

            # Confirma que o diretório é gravável
            if os.access(caminho, os.W_OK):
                return caminho
        except OSError:
            continue

    # Último recurso: usa o /tmp diretamente
    return "/tmp"


# Define a função grava_log que recebe um texto e um objeto bucket como parâmetros
def grava_log(texto, bucket=None):

    # Diretório onde o arquivo de log será gravado
    path = _diretorio_de_logs()

    # Obtém o momento atual em UTC
    agora = datetime.now(timezone.utc)

    # Formata a data atual para o nome do arquivo de log
    data_arquivo = agora.strftime("%Y%m%d")

    # Formata a data e hora atuais para registrar no log
    data_hora_log = agora.strftime("%Y-%m-%d %H:%M:%S")

    # Monta o nome do arquivo de log com o caminho, a data e o sufixo -log_spark.txt
    nome_arquivo = os.path.join(path, data_arquivo + "-log_spark.txt")

    # Inicializa a variável texto_log como uma string vazia
    texto_log = ""

    # Tenta abrir o arquivo de log em modo append se já existir, ou cria um novo
    try:

        # Verifica se o arquivo já existe
        if os.path.isfile(nome_arquivo):

            # Abre o arquivo em modo de adição
            arquivo = open(nome_arquivo, "a")

            # Adiciona uma nova linha se o arquivo já existir
            texto_log = texto_log + "\n"

        else:

            # Cria um novo arquivo se ele não existir
            arquivo = open(nome_arquivo, "w")

    # Captura qualquer exceção durante a tentativa de abrir o arquivo
    except Exception:
        print("Erro na tentativa de acessar o arquivo para criar os logs")

        # Relança a exceção com o traceback para diagnóstico
        raise Exception(traceback.format_exc())

    # Adiciona a data, hora e o texto do log à variável texto_log
    texto_log = texto_log + "[" + data_hora_log + "] - " + str(texto)

    # Escreve o log no arquivo
    arquivo.write(texto_log)

    # Imprime o texto do log (capturado automaticamente pelo CloudWatch Logs)
    print(texto)

    # Fecha o arquivo após a escrita
    arquivo.close()

    # Carrega o arquivo de log para o bucket, se um bucket foi informado.
    # Uma falha no upload do log nunca pode derrubar o pipeline.
    if bucket is not None:
        try:
            bucket.upload_file(nome_arquivo, "logs/" + data_arquivo + "-log_spark.txt")
        except Exception:
            print("Aviso: nao foi possivel enviar o arquivo de log para o S3.")
