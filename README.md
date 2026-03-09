# 🚀 Projeto DM — Solução de Engenharia de Dados na AWS

![Python](https://img.shields.io/badge/Python-3.10+-blue?logo=python&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-1.7+-7B42BC?logo=terraform&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-20.x+-2496ED?logo=docker&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900?logo=amazon-aws&logoColor=white)
![Spark](https://img.shields.io/badge/Apache_Spark-EMR-E25A1C?logo=apachespark&logoColor=white)
![LGPD](https://img.shields.io/badge/LGPD-Compliance-green)

---

## I. Objetivo do Case

Este projeto foi desenvolvido como resposta ao desafio da **Academia Santander de Engenharia de Dados**, com o objetivo de projetar e implementar uma **solução completa de Engenharia de Dados** capaz de lidar com grande volume de dados, abrangendo os seguintes tópicos:

- Extração de dados de múltiplas fontes
- Ingestão em lote (batch) e contínua
- Armazenamento escalável na nuvem
- Observabilidade e monitoramento do pipeline
- Segurança, conformidade com a LGPD e mascaramento de dados sensíveis
- Arquitetura de dados escalável (Data Lake na AWS)
- Escalabilidade horizontal e vertical

A solução utiliza **Infraestrutura como Código (IaC)** com Terraform para garantir reprodutibilidade total do ambiente, e **Docker** para isolar e padronizar a execução de todos os componentes.

---

## II. Arquitetura de Solução e Arquitetura Técnica

### 2.1 Visão Geral da Arquitetura

A solução segue uma arquitetura **Lambda**, combinando processamento em batch e em tempo real, com camadas bem definidas de ingestão, armazenamento, processamento e consumo.

```
┌─────────────────────────────────────────────────────────────────┐
│                        FONTES DE DADOS                          │
│        [ CSV ]     [ APIs Públicas ]     [ Dados Simulados ]    │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      CAMADA DE INGESTÃO                         │
│                                                                 │
│   Batch : Scripts Python (p_processamento.py) + AWS Glue ETL   │
│   Streaming : AWS Kinesis Data Streams                          │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              CAMADA DE ARMAZENAMENTO — Data Lake S3             │
│                                                                 │
│   RAW  ──►  PROCESSED  ──►  CURATED                            │
│   Bruto     Limpo/Mascarado  Pronto p/ análise                  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              CAMADA DE PROCESSAMENTO — Amazon EMR               │
│                                                                 │
│   Apache Spark (PySpark) — Treinamento de Modelos ML            │
│   LogisticRegression — HashingTF — TF-IDF — Word2Vec           │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│               CAMADA DE SEGURANÇA E CONFORMIDADE                │
│                                                                 │
│   AWS KMS (criptografia)  │  IAM (controle de acesso)          │
│   p_masking.py (LGPD)     │  CloudTrail (auditoria)            │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                   CAMADA DE OBSERVABILIDADE                     │
│                                                                 │
│   CloudWatch Logs + Metrics + Alarms + Dashboard                │
│   SNS (alertas por e-mail)  │  CloudTrail (auditoria LGPD)     │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Arquitetura Técnica — Componentes e Justificativas

| Componente | Tecnologia | Justificativa |
|---|---|---|
| IaC | Terraform 1.7+ | Reprodutibilidade, versionamento e suporte nativo à AWS |
| Containerização | Docker 20.x+ | Ambiente isolado, portável, independente de SO |
| Armazenamento | Amazon S3 | Escalabilidade ilimitada, integração nativa com analytics AWS |
| ETL Batch | AWS Glue + PySpark | Serverless, integrado ao S3 e Athena, sem gestão de servidores |
| Processamento ML | Amazon EMR + Spark | Processamento distribuído de grande volume com PySpark |
| Catálogo de Dados | AWS Glue Data Catalog | Descoberta automática de schema, integrado ao Athena |
| Criptografia | AWS KMS | Rotação automática de chaves, conformidade com LGPD |
| Controle de Acesso | AWS IAM | Princípio do menor privilégio por serviço |
| Monitoramento | AWS CloudWatch | Logs, métricas, alarmes e dashboard centralizados |
| Auditoria | AWS CloudTrail | Rastreamento completo de acessos — obrigatório pela LGPD |
| Alertas | AWS SNS | Notificações por e-mail em caso de falhas no pipeline |

### 2.3 Estrutura do Repositório

```
Projeto_DM/
├── .gitignore                          # Exclui tfstate, credenciais e logs
├── README.md                           # Este documento
│
└── IaC/
    └── terraform/
        ├── config.tf                   # Backend S3 + provider AWS
        ├── main.tf                     # Orquestra todos os módulos
        ├── variables.tf                # Declaração de variáveis
        ├── terraform.tfvars            # Valores das variáveis (não versionar)
        ├── security_groups.tf          # Grupos de segurança do EMR
        ├── .terraform.lock.hcl         # Lock de versões dos providers
        │
        ├── modules/
        │   ├── kms/                    # Criptografia KMS (executa primeiro)
        │   │   ├── main.tf
        │   │   ├── variables.tf
        │   │   └── outputs.tf
        │   ├── s3/                     # Data Lake: RAW / PROCESSED / CURATED
        │   │   ├── main.tf
        │   │   ├── variables.tf
        │   │   └── outputs.tf
        │   ├── iam/                    # Roles para EMR e Glue
        │   │   ├── main.tf
        │   │   ├── variables.tf
        │   │   └── outputs.tf
        │   ├── emr/                    # Cluster Spark para ML
        │   │   ├── main.tf
        │   │   └── variables.tf
        │   ├── glue/                   # ETL + Data Catalog + Workflow
        │   │   ├── main.tf
        │   │   ├── variables.tf
        │   │   └── outputs.tf
        │   └── monitoring/             # CloudWatch + CloudTrail + SNS
        │       ├── main.tf
        │       ├── variables.tf
        │       └── outputs.tf
        │
        ├── pipeline/                   # Scripts Python enviados ao S3
        │   ├── projeto.py              # Orquestrador principal (Spark)
        │   ├── p_processamento.py      # Limpeza e transformação de dados
        │   ├── p_ml.py                 # Treinamento dos modelos ML
        │   ├── p_upload_s3.py          # Upload de dados e modelos para S3
        │   ├── p_masking.py            # Mascaramento de dados sensíveis (LGPD)
        │   └── p_log.py                # Sistema de logs
        │
        ├── scripts/
        │   └── bootstrap.sh            # Prepara ambiente Python nos nós EMR
        │
        └── dados/
            └── dataset.csv             # Dataset de reviews para processamento
```

---

## III. Explicação sobre o Case Desenvolvido

### 3.1 Extração de Dados

A solução processa dados de reviews em formato CSV (`dataset.csv`), carregados pelo `p_processamento.py` via PySpark diretamente do S3. O pipeline suporta extensão para outras fontes como APIs públicas e bancos de dados, bastando adicionar novos scripts na pasta `pipeline/`.

### 3.2 Ingestão de Dados

A ingestão segue a arquitetura **Lambda** com duas vias:

**Batch:** Scripts Python com PySpark são submetidos ao cluster EMR via `spark-submit`. O AWS Glue complementa com jobs ETL agendados que executam diariamente às 03:00 UTC, orquestrados pelo Glue Workflow.

**Streaming:** O módulo `monitoring` provisiona a infraestrutura de observabilidade que monitora o fluxo contínuo de dados na camada RAW.

### 3.3 Armazenamento de Dados

O Data Lake é organizado em três camadas no **Amazon S3**, seguindo o padrão Medalhão:

| Camada | Prefixo S3 | Conteúdo |
|---|---|---|
| Bronze / RAW | `raw/` | Dados brutos, preservados integralmente |
| Silver / PROCESSED | `processed/` | Dados limpos, tipados e mascarados |
| Gold / CURATED | `curated/` | Modelos ML e dados prontos para consumo |

Criptografia KMS aplicada em repouso. Lifecycle rules gerenciam retenção automaticamente (LGPD).

### 3.4 Observabilidade

Três pilares implementados via módulo `monitoring`:

**Logs:** Grupos CloudWatch dedicados para pipeline, Glue e EMR, com retenção de 30 dias.

**Métricas e Alarmes:** Três alarmes automáticos monitoram falhas no Glue, ausência de ingestão no S3 e instabilidade no cluster EMR. Notificações enviadas por e-mail via SNS.

**Dashboard:** CloudWatch Dashboard centraliza métricas em tempo real dos jobs Glue, volume S3 e estado do cluster EMR.

**Auditoria:** CloudTrail registra todos os acessos de leitura e escrita no bucket principal — rastreabilidade completa exigida pela LGPD.

### 3.5 Segurança de Dados e LGPD

**Criptografia:** Todos os buckets S3 usam SSE-KMS com rotação automática anual de chaves. Dados em trânsito protegidos por TLS.

**Controle de Acesso:** IAM Roles separadas para EMR e Glue, cada uma com permissões mínimas necessárias. Acesso público bloqueado em todos os buckets.

**Conformidade LGPD:** Retenção por lifecycle rules, auditoria via CloudTrail, mascaramento antes da camada PROCESSED.

### 3.6 Mascaramento de Dados

O script `p_masking.py` implementa cinco técnicas de mascaramento via UDFs Spark:

| Tipo de Dado | Técnica | Exemplo |
|---|---|---|
| CPF | Tokenização parcial | `123.456.789-00` → `***.***.789-**` |
| Nome | Pseudonimização (hash SHA-256) | `João Silva` → `ID_a3f1b2c4` |
| E-mail | Hash SHA-256 completo | `joao@email.com` → `a3f1b2c4...` |
| Telefone | Mascaramento parcial | `(11) 99999-9999` → `(11) ****-9999` |
| Dados financeiros | Substituição por faixas | `1500.00` → `1001-2000` |

O mascaramento é aplicado na transição RAW → PROCESSED via função `aplica_mascaramento()`.

### 3.7 Arquitetura de Dados

O **AWS Glue Data Catalog** cataloga automaticamente o schema das três camadas via Crawlers agendados. O **Amazon Athena** permite consultas SQL diretamente sobre os dados no S3 sem mover dados.

O Glue Workflow encadeia os jobs: ETL (03:00 UTC) → Curadoria/ML (dispara após ETL com sucesso).

### 3.8 Escalabilidade

**Horizontal:** AWS Glue escala workers automaticamente (DPUs). EMR adiciona nós via Auto Scaling. S3 escala ilimitadamente.

**Vertical:** Tipos de instância EMR e número de workers Glue configuráveis via `terraform.tfvars` sem alterar código.

**Particionamento:** Dados particionados por `ano/mês/dia` no S3, reduzindo custo e tempo de consultas no Athena em até 90%.

---

## IV. Melhorias e Considerações Finais

### 4.1 Checklist de Entregáveis

| Requisito do Case | Status |
|---|---|
| Extração de Dados (CSV + simulados) | ✅ |
| Ingestão Batch (EMR + Glue ETL) | ✅ |
| Armazenamento em Data Lake S3 (3 camadas) | ✅ |
| Observabilidade (CloudWatch + CloudTrail + SNS) | ✅ |
| Segurança e LGPD (KMS + IAM + lifecycle) | ✅ |
| Mascaramento de Dados (p_masking.py) | ✅ |
| Arquitetura Medalhão + Glue Data Catalog | ✅ |
| Escalabilidade (Glue DPUs + EMR Auto Scaling) | ✅ |
| IaC com Terraform (6 módulos) | ✅ |
| Reprodutibilidade com Docker | ✅ |
| Pipeline ML com PySpark (LR + TF-IDF + W2V) | ✅ |

### 4.2 Melhorias Futuras

- **Data Quality:** Implementar validações com **Great Expectations** em cada camada do Data Lake
- **CI/CD:** Expandir GitHub Actions com `terraform plan` automático em PRs
- **Data Lineage:** Rastreabilidade de origem com **AWS Glue Data Lineage**
- **Cost Optimization:** S3 Intelligent-Tiering para dados com acesso variável
- **Streaming Real:** Integrar **AWS Kinesis** para ingestão em tempo real completa
- **Visualização:** Conectar camada CURATED ao **Amazon QuickSight**

### 4.3 Considerações Finais

Este projeto demonstra uma arquitetura moderna de Engenharia de Dados na AWS, priorizando três princípios:

1. **Reprodutibilidade** — Docker + Terraform permitem replicar o ambiente completo em qualquer máquina com um único comando
2. **Segurança por design** — LGPD integrada desde a ingestão: KMS, IAM, mascaramento e auditoria são parte da infraestrutura, não um complemento
3. **Escalabilidade nativa** — Serviços serverless e gerenciados (Glue, S3, EMR) escalam conforme a demanda sem intervenção manual

---

## 🚀 Como Executar

### Pré-requisitos

- [Docker](https://docs.docker.com/get-docker/) instalado
- Conta AWS ativa com permissões para S3, EMR, Glue, CloudWatch, KMS e IAM
- AWS Account ID disponível

### Passo a passo

**1. Clone o repositório**
```bash
git clone https://github.com/victorpereirasilva/Projeto_DM.git
cd Projeto_DM
```

**2. Configure suas variáveis**

Edite `IaC/terraform/terraform.tfvars` substituindo `SEU_ACCOUNT_ID` pelo seu Account ID real:
```hcl
name_bucket  = "projeto-dm-123456789012"
name_emr     = "projeto-dm-emr-123456789012"
alarm_email  = "seu@email.com"
```

Edite também `IaC/terraform/config.tf`:
```hcl
bucket = "proj-dm-terraform-123456789012"
```

**3. Build da imagem Docker**
```bash
docker build -t dm-terraform-image:p .
```

**4. Execute o container**

Linux/macOS:
```bash
docker run -dit --name dm-p \
  -v $(pwd)/IaC:/iac \
  dm-terraform-image:p /bin/bash
```

Windows (PowerShell):
```powershell
docker run -dit --name dm-p `
  -v ${PWD}/IaC:/iac `
  dm-terraform-image:p /bin/bash
```

**5. Acesse o container e configure as credenciais AWS**
```bash
docker exec -it dm-p /bin/bash
aws configure
```

**6. Crie o bucket de backend do Terraform**
```bash
aws s3 mb s3://proj-dm-terraform-SEU_ACCOUNT_ID --region us-east-2
```

**7. Inicialize e aplique a infraestrutura**
```bash
cd /iac/terraform
terraform init
terraform plan
terraform apply
```

**8. Confirme a inscrição SNS**

Verifique seu e-mail e confirme a inscrição no tópico SNS para receber alertas.

**9. Acompanhe o pipeline**

Acesse o [Console AWS](https://console.aws.amazon.com) → CloudWatch Dashboard → `projeto-dm-pipeline-dashboard`.

---

## 🔒 Segurança

> ⚠️ O arquivo `terraform.tfvars` está no `.gitignore` e **nunca deve ser versionado** com valores reais.
> ⚠️ As credenciais AWS são obtidas via `aws configure` ou IAM Role — **nunca insira chaves no código**.

---

## 👤 Autor

**Victor Pereira Silva**
[![GitHub](https://img.shields.io/badge/GitHub-victorpereirasilva-181717?logo=github)](https://github.com/victorpereirasilva)

---

*Projeto desenvolvido para o desafio de Engenharia de Dados da Academia Santander.*
