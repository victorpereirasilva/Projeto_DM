# Projeto DM - Script de Preparação do Ambiente Python
# Executado automaticamente em todos os nós do cluster EMR antes do job iniciar

# Download do Miniconda (interpretador da Linguagem Python)
wget --quiet https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh \
    && /bin/bash ~/miniconda.sh -b -p $HOME/conda

# Configura o miniconda no PATH
echo -e '\nexport PATH=$HOME/conda/bin:$PATH' >> $HOME/.bashrc && source $HOME/.bashrc

# Atualiza o pip
pip install --upgrade pip

# Instala as dependências do projeto
python3 -m pip install boto3
python3 -m pip install pendulum
python3 -m pip install findspark
python3 -m pip install numpy
python3 -m pip install python-dotenv
python3 -m pip install scikit-learn

# Cria as pastas necessárias para execução do pipeline
mkdir -p $HOME/pipeline
mkdir -p $HOME/logs
mkdir -p $HOME/dados
