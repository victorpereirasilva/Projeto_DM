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

2. Construir a imagem Docker:
   docker build -t projeto_dm:latest .

3. Executar o contêiner:
   docker run --env-file .env -it projeto_dm:latest

