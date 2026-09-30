# Ambiente de trabalho do Projeto DM: Terraform, AWS CLI e Python.
# A imagem base é fixada em uma versão: "latest" tornaria o build
# irreproduzível — a mesma instrução geraria ambientes diferentes ao
# longo do tempo, justamente o que a Infraestrutura como Código evita.
FROM ubuntu:24.04

# Mantenedor da imagem
LABEL maintainer="Victor Pereira Silva"
LABEL description="Ambiente para provisionar e operar o Data Lake do Projeto DM"

# Evita prompts interativos durante a instalação de pacotes
ENV DEBIAN_FRONTEND=noninteractive

# Desliga o pager do AWS CLI v2.
# Por padrão ele manda a saída para o `less`, que não existe numa imagem
# enxuta — e o comando falha na exibição, com um erro que parece de
# credencial e não é. Em uso não interativo o pager não serve para nada.
ENV AWS_PAGER=""

# Atualiza os pacotes do sistema e instala as dependências necessárias.
# python3 está incluído para permitir gerar o dataset dentro do container,
# sem exigir Python instalado na máquina do usuário.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        wget \
        unzip \
        curl \
        git \
        ca-certificates \
        openssh-client \
        iputils-ping \
        python3 \
        python3-pip && \
    rm -rf /var/lib/apt/lists/*

# Versão do Terraform.
# 1.10+ é necessário para o bloqueio de estado nativo do backend S3
# (use_lockfile), que dispensa a tabela DynamoDB.
ENV TERRAFORM_VERSION=1.10.5

# Baixa e instala o Terraform
RUN wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    unzip -q terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    mv terraform /usr/local/bin/ && \
    rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# Instala o AWS CLI v2
RUN curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip" && \
    unzip -q /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/awscliv2.zip /tmp/aws

# Dependências Python dos scripts auxiliares (gerador do dataset, produtor
# Kinesis). Declaradas em requirements.txt para que a instalação seja
# reproduzível e não dependa de comando digitado à mão.
COPY requirements.txt /tmp/requirements.txt
RUN python3 -m pip install --no-cache-dir --break-system-packages -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

# Ponto de montagem do código de infraestrutura
RUN mkdir /iac
VOLUME /iac
WORKDIR /iac

# Comando padrão ao iniciar o container
CMD ["/bin/bash"]
