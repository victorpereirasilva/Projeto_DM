Projeto_DM
==========

Objetivo
-----------
Automatizar a criação e gerenciamento de ambientes utilizando Python, Docker e Infraestrutura como Código (IaC), garantindo reprodutibilidade, escalabilidade e facilidade de manutenção.

Tecnologias Utilizadas
-------------------------
- Python 3.10+ → Scripts principais e lógica de automação
- Docker → Criação de imagens e contêineres
- Terraform (HCL) → Definição de infraestrutura como código
- Shell Scripts → Automação auxiliar
- GitHub Actions → Integração contínua (CI/CD)

Estrutura do Projeto
-----------------------
Projeto_DM/
├─ IaC/
│  └─ terraform/        # Configurações de infraestrutura
├─ src/
│  └─ main.py           # Código principal em Python
├─ Dockerfile           # Definição da imagem Docker
├─ README.md            # Documentação principal

Instalação e Uso
-------------------
1. Clonar o repositório:
   git clone https://github.com/victorpereirasilva/Projeto_DM.git
   cd Projeto_DM

2. Abra o terminal ou prompt de comando e navegue até a pasta onde você colocou os arquivos do projeto (não use espaço ou acento em nome de pasta). Execute o comando abaixo para criar a imagem Docker:

docker build -t dm-terraform-image:p .

3. Execute o comando abaixo para criar o container Docker:

docker run -dit --name dm-p -v D:\PROJETO\Projeto_DM\IaC:/iac dm-terraform-image:p /bin/bash

4. Verifique as versões do Terraform e do AWS CLI com os comandos abaixo

terraform version
aws --version

5. Configure a chave da AWS com o seguinte comando no container docker:
  
aws configure

6. Vá para a pasta iac e execute o terraform init

7. Edite os arquivos config.tf e terraform.tfvars, e coloque seu ID da AWS onde indicado

8. No script projeto.py adicione seu ID da AWS e suas chaves AWS onde indicado

9. Crie manualmente o bucket S3 chamado: proj-dm-terraform-<id-aws>  (substitua <id-aws> pelo seu ID da AWS)

10. Execute:

terraform init
terraform apply

11. Acompanhe a execução do pipeline pela interface da AWS.

