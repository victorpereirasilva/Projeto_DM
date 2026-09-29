"""
Projeto DM - Gerador do dataset simulado de atendimentos ambulatoriais

O case permite explicitamente o uso de dados simulados. Optamos por gerar
o dataset em vez de versionar um CSV de dezenas de megabytes no Git, o que
traz três vantagens:

  1. O repositório fica leve e auditável (o CSV entra no .gitignore)
  2. O volume é parametrizável — a mesma stack roda com 100 mil ou 10 milhões
     de linhas, o que permite demonstrar escalabilidade de verdade
  3. Os dados sensíveis são sintéticos por construção: nenhum dado pessoal
     real trafega pelo pipeline, mesmo em ambiente de desenvolvimento

O domínio escolhido é saúde pública: prever quais pacientes faltam às
consultas ambulatoriais agendadas. É um problema real do SUS, tem dados pessoais
legítimos a proteger sob a LGPD e gera um alvo de classificação binária
bem definido.

Uso:
    python3 gerar_dataset.py                      # 150.000 linhas (padrão)
    python3 gerar_dataset.py --linhas 5000000     # volume de stress test
    python3 gerar_dataset.py --saida outro.csv
"""

import argparse
import csv
import random
from datetime import date, timedelta

# Semente fixa: o dataset é reproduzível entre execuções e entre máquinas
SEMENTE = 42

# -------------------------------------------------------------------
# VOCABULÁRIOS DE APOIO
# Nomes e domínios são fictícios; qualquer coincidência é casual e o
# dado é mascarado pelo pipeline antes de chegar à camada PROCESSED.
# -------------------------------------------------------------------

PRENOMES = [
    "Ana", "Bruno", "Carla", "Diego", "Elaine", "Fabio", "Gabriela", "Heitor",
    "Isabela", "Joao", "Karina", "Lucas", "Mariana", "Nelson", "Olivia",
    "Paulo", "Queila", "Rafael", "Sabrina", "Thiago", "Ursula", "Vinicius",
    "Wesley", "Ximena", "Yasmin", "Zeca", "Beatriz", "Caio", "Daniela", "Eduardo",
]

SOBRENOMES = [
    "Silva", "Santos", "Oliveira", "Souza", "Rodrigues", "Ferreira", "Alves",
    "Pereira", "Lima", "Gomes", "Costa", "Ribeiro", "Martins", "Carvalho",
    "Almeida", "Lopes", "Soares", "Fernandes", "Vieira", "Barbosa",
]

DOMINIOS = ["email.com", "provedor.com.br", "correio.net", "mail.com.br"]

# Municípios fictícios com a UF correspondente
MUNICIPIOS = [
    ("Santa Clara do Norte", "SP"), ("Vila Esperanca", "SP"),
    ("Porto Alegre do Campo", "RS"), ("Serra Verde", "MG"),
    ("Riacho Fundo", "BA"), ("Campo Novo", "PR"),
    ("Boa Vista do Sul", "SC"), ("Lagoa Grande", "PE"),
    ("Morro Alto", "GO"), ("Ponte Nova do Oeste", "MT"),
]

UNIDADES = [
    "UBS Central", "UBS Jardim Aurora", "UBS Sao Jorge", "Policlinica Municipal",
    "Hospital Regional", "Centro de Especialidades", "UBS Vila Nova",
    "Ambulatorio Universitario",
]

ESPECIALIDADES = [
    "Clinica Geral", "Cardiologia", "Dermatologia", "Ortopedia", "Pediatria",
    "Oftalmologia", "Ginecologia", "Endocrinologia", "Neurologia", "Psiquiatria",
]

TIPOS_CONSULTA = ["primeira_consulta", "retorno", "urgencia"]

CANAIS = ["aplicativo", "telefone", "presencial", "encaminhamento_ubs"]


def gera_cpf(rng):
    """Gera um CPF sintético formatado. Não valida dígito verificador
    de propósito: o dado nunca deve ser confundido com um CPF real."""
    numeros = [rng.randint(0, 9) for _ in range(11)]
    d = "".join(str(n) for n in numeros)
    return f"{d[0:3]}.{d[3:6]}.{d[6:9]}-{d[9:11]}"


def gera_telefone(rng):
    """Gera um telefone celular sintético formatado."""
    ddd = rng.choice([11, 21, 31, 41, 51, 61, 71, 81, 85, 91])
    return f"({ddd}) 9{rng.randint(1000, 9999)}-{rng.randint(1000, 9999)}"


def probabilidade_comparecimento(dias_espera, faltas_anteriores, distancia_km,
                                 tipo_consulta, idade):
    """Modela a chance de o paciente comparecer.

    Não é aleatório puro: o alvo depende das features de forma plausível,
    para que o modelo de Machine Learning tenha sinal real para aprender.

    Os coeficientes foram calibrados para produzir uma taxa de faltas
    em torno de 23%, dentro da faixa observada na literatura sobre consultas
    ambulatoriais da rede pública (tipicamente entre 20% e 30%). Um dataset
    com metade das consultas em falta seria fácil de modelar e implausível
    para qualquer pessoa que conheça o domínio.
    """
    p = 0.99

    # Quanto maior a espera entre o agendamento e a consulta, maior o no-show
    p -= min(dias_espera, 120) * 0.0015

    # Histórico de faltas é o preditor mais forte
    p -= min(faltas_anteriores, 8) * 0.032

    # Distância até a unidade pesa na decisão de comparecer
    p -= min(distancia_km, 60) * 0.0013

    # Urgência quase sempre comparece; retorno tem adesão melhor que a primeira
    if tipo_consulta == "urgencia":
        p += 0.10
    elif tipo_consulta == "retorno":
        p += 0.04

    # Idosos têm adesão maior; adultos jovens, menor
    if idade >= 60:
        p += 0.05
    elif idade <= 25:
        p -= 0.04

    # Mantém a probabilidade dentro de uma faixa realista
    return max(0.05, min(0.98, p))


def gerar(linhas, saida, semente=SEMENTE):
    """Gera o arquivo CSV com o volume solicitado."""

    rng = random.Random(semente)

    # Janela de dois anos de atendimentos
    data_final = date(2026, 6, 30)
    data_inicial = data_final - timedelta(days=730)
    intervalo_dias = (data_final - data_inicial).days

    colunas = [
        "id_atendimento",
        "data_atendimento",
        "nome_paciente",
        "cpf",
        "email",
        "telefone",
        "municipio",
        "uf",
        "unidade_saude",
        "especialidade",
        "tipo_consulta",
        "canal_agendamento",
        "idade",
        "dias_espera",
        "distancia_km",
        "consultas_anteriores",
        "faltas_anteriores",
        "valor_procedimento",
        "compareceu",
    ]

    with open(saida, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(colunas)

        for i in range(1, linhas + 1):

            prenome = rng.choice(PRENOMES)
            sobrenome = rng.choice(SOBRENOMES)
            nome = f"{prenome} {sobrenome}"

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
            compareceu = 1 if rng.random() < p else 0

            data_atendimento = data_inicial + timedelta(
                days=rng.randint(0, intervalo_dias)
            )

            # ~2% de valores nulos propositais, para exercitar a limpeza do ETL
            telefone = gera_telefone(rng) if rng.random() > 0.02 else ""
            email = (
                f"{prenome.lower()}.{sobrenome.lower()}{rng.randint(1, 999)}@{rng.choice(DOMINIOS)}"
                if rng.random() > 0.02
                else ""
            )

            writer.writerow([
                f"ATD{i:09d}",
                data_atendimento.isoformat(),
                nome,
                gera_cpf(rng),
                email,
                telefone,
                municipio,
                uf,
                rng.choice(UNIDADES),
                rng.choice(ESPECIALIDADES),
                tipo_consulta,
                rng.choice(CANAIS),
                idade,
                dias_espera,
                distancia_km,
                consultas_anteriores,
                faltas_anteriores,
                round(rng.uniform(35.0, 4800.0), 2),
                compareceu,
            ])

    print(f"Dataset gerado: {saida} ({linhas} linhas)")


if __name__ == "__main__":

    parser = argparse.ArgumentParser(
        description="Gera o dataset simulado de atendimentos ambulatoriais do Projeto DM"
    )
    parser.add_argument("--linhas", type=int, default=150_000,
                        help="Quantidade de registros a gerar (padrao: 150000)")
    parser.add_argument("--saida", type=str, default="dataset.csv",
                        help="Caminho do arquivo CSV de saida (padrao: dataset.csv)")
    parser.add_argument("--semente", type=int, default=SEMENTE,
                        help="Semente do gerador aleatorio (padrao: 42)")

    args = parser.parse_args()
    gerar(args.linhas, args.saida, args.semente)
