"""
Projeto DM - Produtor de eventos para o Kinesis Data Streams

Simula a aplicação de agendamento do sistema de saúde publicando eventos
de atendimento em tempo real. Cada evento segue exatamente o mesmo contrato
do lote (mesmas colunas do dataset.csv), de modo que as duas vias da
arquitetura Lambda convergem na camada RAW e são tratadas pelo mesmo ETL.

Os eventos carregam dados pessoais sintéticos em claro — é justamente esse
o ponto: eles chegam crus à camada RAW e só são mascarados na transição
para PROCESSED, como manda a política de privacidade do projeto.

Uso:
    export NOME_BUCKET=projeto-dm-123456789012
    python3 kinesis_producer.py --eventos 500 --intervalo 0.2

Requer credenciais AWS com permissão de kinesis:PutRecord no stream.
"""

import argparse
import json
import os
import random
import sys
import time
from datetime import date, timedelta

import boto3

# Reaproveita os vocabulários e as regras do gerador do dataset em lote,
# garantindo que streaming e batch produzam dados do mesmo domínio.
sys.path.append(os.path.join(os.path.dirname(__file__), "..", "dados"))

try:
    from gerar_dataset import (  # type: ignore
        CANAIS,
        ESPECIALIDADES,
        MUNICIPIOS,
        PRENOMES,
        SOBRENOMES,
        DOMINIOS,
        TIPOS_CONSULTA,
        UNIDADES,
        gera_cpf,
        gera_telefone,
        probabilidade_comparecimento,
    )
except ImportError:
    print(
        "Erro: nao foi possivel importar dados/gerar_dataset.py. "
        "Execute este script a partir da pasta IaC/terraform/pipeline."
    )
    raise


def monta_evento(rng, sequencia):
    """Constrói um evento de atendimento no mesmo formato da camada RAW."""

    prenome = rng.choice(PRENOMES)
    sobrenome = rng.choice(SOBRENOMES)
    municipio, uf = rng.choice(MUNICIPIOS)

    idade = rng.randint(1, 95)
    dias_espera = rng.randint(0, 180)
    distancia_km = round(rng.uniform(0.4, 75.0), 1)
    consultas_anteriores = rng.randint(0, 25)
    faltas_anteriores = rng.randint(0, min(8, consultas_anteriores + 1))
    tipo_consulta = rng.choice(TIPOS_CONSULTA)

    p = probabilidade_comparecimento(
        dias_espera, faltas_anteriores, distancia_km, tipo_consulta, idade
    )

    data_atendimento = date.today() + timedelta(days=rng.randint(0, 60))

    return {
        "id_atendimento": f"STR{int(time.time())}{sequencia:05d}",
        "data_atendimento": data_atendimento.isoformat(),
        "nome_paciente": f"{prenome} {sobrenome}",
        "cpf": gera_cpf(rng),
        "email": f"{prenome.lower()}.{sobrenome.lower()}{rng.randint(1, 999)}@{rng.choice(DOMINIOS)}",
        "telefone": gera_telefone(rng),
        "municipio": municipio,
        "uf": uf,
        "unidade_saude": rng.choice(UNIDADES),
        "especialidade": rng.choice(ESPECIALIDADES),
        "tipo_consulta": tipo_consulta,
        "canal_agendamento": rng.choice(CANAIS),
        "idade": idade,
        "dias_espera": dias_espera,
        "distancia_km": distancia_km,
        "consultas_anteriores": consultas_anteriores,
        "faltas_anteriores": faltas_anteriores,
        "valor_procedimento": round(rng.uniform(35.0, 4800.0), 2),
        "compareceu": 1 if rng.random() < p else 0,
    }


def publica(stream, eventos, intervalo, lote):
    """Publica os eventos no Kinesis Data Streams em lotes."""

    cliente = boto3.client("kinesis")
    rng = random.Random()

    enviados = 0
    buffer = []

    for i in range(1, eventos + 1):

        evento = monta_evento(rng, i)

        buffer.append({
            # A quebra de linha permite que o Firehose entregue um JSON por
            # linha (JSON Lines), formato que o Spark e o Athena leem direto.
            "Data": (json.dumps(evento, ensure_ascii=False) + "\n").encode("utf-8"),

            # A chave de partição distribui os eventos entre os shards.
            # Usar a unidade de saúde mantém os eventos de uma mesma unidade
            # na ordem em que ocorreram.
            "PartitionKey": evento["unidade_saude"],
        })

        # Envia quando o lote fecha ou quando acabam os eventos
        if len(buffer) >= lote or i == eventos:

            resposta = cliente.put_records(StreamName=stream, Records=buffer)
            falhas = resposta.get("FailedRecordCount", 0)
            enviados += len(buffer) - falhas

            if falhas:
                print(f"Aviso: {falhas} registros falharam neste lote.")

            buffer = []
            print(f"Enviados {enviados}/{eventos} eventos.")

        if intervalo > 0:
            time.sleep(intervalo)

    print(f"Concluido: {enviados} eventos publicados no stream {stream}.")


if __name__ == "__main__":

    parser = argparse.ArgumentParser(
        description="Publica eventos simulados de atendimento no Kinesis Data Streams"
    )
    parser.add_argument("--stream", type=str, default=None,
                        help="Nome do stream (padrao: ${NOME_BUCKET}-atendimentos-stream)")
    parser.add_argument("--eventos", type=int, default=500,
                        help="Quantidade de eventos a publicar (padrao: 500)")
    parser.add_argument("--intervalo", type=float, default=0.1,
                        help="Pausa em segundos entre os eventos (padrao: 0.1)")
    parser.add_argument("--lote", type=int, default=25,
                        help="Tamanho do lote enviado por chamada (padrao: 25, maximo 500)")

    args = parser.parse_args()

    nome_stream = args.stream
    if nome_stream is None:
        nome_bucket = os.environ.get("NOME_BUCKET")
        if not nome_bucket:
            parser.error(
                "Informe --stream ou defina a variavel de ambiente NOME_BUCKET."
            )
        nome_stream = f"{nome_bucket}-atendimentos-stream"

    publica(nome_stream, args.eventos, args.intervalo, min(args.lote, 500))
