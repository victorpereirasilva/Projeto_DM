# 🚀 Projeto DM — Automação de Infraestrutura com Docker + Terraform + AWS

![Python](https://img.shields.io/badge/Python-3.10+-blue?logo=python&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-1.x-7B42BC?logo=terraform&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-20.x+-2496ED?logo=docker&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900?logo=amazon-aws&logoColor=white)
![Shell](https://img.shields.io/badge/Shell-Script-4EAA25?logo=gnu-bash&logoColor=white)

## 📋 Sobre o Projeto

O **Projeto DM** automatiza a criação e o gerenciamento de ambientes cloud na AWS utilizando Python, Docker e Infraestrutura como Código (IaC) com Terraform. O objetivo é garantir **reprodutibilidade**, **escalabilidade** e **facilidade de manutenção** em pipelines de dados e infraestrutura.

---

## 🏗️ Arquitetura

```
Projeto_DM/
├── IaC/
│   └── terraform/          # Configurações de infraestrutura (HCL)
│       ├── config.tf        # Configurações do provider AWS
│       ├── main.tf          # Recursos principais
│       └── terraform.tfvars # Variáveis de ambiente (não versionar com dados sensíveis)
├── Dockerfile               # Imagem com Terraform + AWS CLI + Python
└── README.md
```

---

## 🛠️ Tecnologias Utilizadas

| Tecnologia | Versão | Finalidade |
|---|---|---|
| Python | 3.10+ | Scripts de automação e lógica principal |
| Docker | 20.x+ | Ambiente isolado e reproduzível |
| Terraform (HCL) | 1.x+ | Infraestrutura como Código na AWS |
| AWS CLI | 2.x+ | Interação com serviços da AWS |
| Shell Script | — | Automação auxiliar |
| GitHub Actions | — | CI/CD |

---

## ✅ Pré-requisitos

Antes de iniciar, certifique-se de ter instalado:

- [Docker](https://docs.docker.com/get-docker/) (versão 20.x ou superior)
- Conta AWS ativa com permissões para criar recursos (S3, etc.)
- Credenciais AWS: **Access Key** e **Secret Key**

> ⚠️ **Não é necessário** instalar Terraform ou AWS CLI localmente — o Dockerfile já inclui ambos no container.

---

## 🚀 Instalação e Uso

### 1. Clone o repositório

```bash
git clone https://github.com/victorpereirasilva/Projeto_DM.git
cd Projeto_DM
```

### 2. Build da imagem Docker

```bash
docker build -t dm-terraform-image:p .
```

### 3. Execute o container

Substitua o caminho abaixo pelo caminho local da pasta `IaC` no seu sistema:

**Linux/macOS:**
```bash
docker run -dit --name dm-p \
  -v $(pwd)/IaC:/iac \
  dm-terraform-image:p /bin/bash
```

**Windows (PowerShell):**
```powershell
docker run -dit --name dm-p `
  -v ${PWD}/IaC:/iac `
  dm-terraform-image:p /bin/bash
```

### 4. Acesse o container

```bash
docker exec -it dm-p /bin/bash
```

### 5. Verifique as versões instaladas

```bash
terraform version
aws --version
```

### 6. Configure as credenciais AWS

```bash
aws configure
```

> Você precisará informar: `AWS Access Key ID`, `AWS Secret Access Key`, `Default region name` e `Default output format`.

### 7. Prepare os arquivos de configuração

Dentro da pasta `/iac`, edite os arquivos:

- **`config.tf`** — Substitua o placeholder pelo seu AWS Account ID
- **`terraform.tfvars`** — Preencha as variáveis necessárias

> 🔒 **Segurança:** Nunca insira credenciais AWS diretamente no código. Utilize variáveis de ambiente ou o `aws configure`. Nunca suba `terraform.tfvars` com dados sensíveis para o repositório.

### 8. Crie o bucket S3 de backend do Terraform

Crie manualmente um bucket S3 com o nome:

```
proj-dm-terraform-<SEU_AWS_ACCOUNT_ID>
```

### 9. Inicialize e aplique o Terraform

```bash
cd /iac
terraform init
terraform plan   # Revise as mudanças antes de aplicar
terraform apply
```

### 10. Acompanhe o pipeline

Acesse o console da AWS e monitore os recursos criados pelo pipeline.

---

## 🔒 Boas Práticas de Segurança

- ❌ Nunca commite arquivos `.tfvars` com valores reais
- ❌ Nunca insira Access Keys ou Secret Keys diretamente em scripts Python ou arquivos de configuração
- ✅ Use variáveis de ambiente (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) ou o `aws configure`
- ✅ Adicione `*.tfvars` e `terraform.tfstate` ao `.gitignore`
- ✅ Considere usar o [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/) para gerenciar segredos

Exemplo de `.gitignore` recomendado:
```
*.tfvars
*.tfstate
*.tfstate.backup
.terraform/
.env
```

---

## 🤝 Contribuindo

Contribuições são bem-vindas! Para contribuir:

1. Faça um fork do projeto
2. Crie uma branch para sua feature: `git checkout -b feature/minha-feature`
3. Commit suas mudanças: `git commit -m 'feat: adiciona minha feature'`
4. Faça push para a branch: `git push origin feature/minha-feature`
5. Abra um Pull Request

---

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

---

## 👤 Autor

**Victor Pereira Silva**  
[![GitHub](https://img.shields.io/badge/GitHub-victorpereirasilva-181717?logo=github)](https://github.com/victorpereirasilva)
