#!/bin/bash
# Projeto DM - Preparação do ambiente Python nos nós do cluster EMR
#
# Executado automaticamente em todos os nós antes do job iniciar.
# Interrompe o cluster se qualquer passo falhar: um bootstrap que falha
# em silêncio produz um job que quebra depois, com erro sem relação
# aparente com a causa.
set -euo pipefail

# O EMR 6.x já traz Python 3 e PySpark configurados. Não instalamos outro
# interpretador (Miniconda, por exemplo) para não divergir do Python que o
# Spark usa nos executores.

# Atualiza o pip do interpretador do sistema
sudo python3 -m pip install --upgrade pip

# Dependências do pipeline.
# boto3 acompanha a AMI do EMR, mas é declarado aqui para deixar o
# contrato explícito. A engenharia de atributos e os modelos usam
# exclusivamente pyspark.ml, que já vem no cluster.
sudo python3 -m pip install boto3

# Cria os diretórios usados pelo sistema de logs
mkdir -p "$HOME/logs"
