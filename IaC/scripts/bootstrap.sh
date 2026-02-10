# Projeto 2 - Deploy do Stack de Treinamento Distribuído de Machine Learning com PySpark no Amazon EMR
# Script de Preparação do Ambiente Python

# Download do Miniconda (interpretador da Linguagem Python)
wget --quiet https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh \
    && /bin/bash ~/miniconda.sh -b -p $HOME/conda

# Configura o miniconda no PATH
echo -e '\nexport PATH=$HOME/conda/bin:$PATH' >> $HOME/.bashrc && source $HOME/.bashrc

# Instala os pacotes via pip 
pip install --upgrade pip
python3 -m pip install boto3 
python3 -m pip install pendulum 
python3 -m pip install findspark
python3 -m pip install numpy 
python3 -m pip install python-dotenv 
python3 -m pip install scikit-learn 

# Cria as pastas
mkdir $HOME/pipeline
mkdir $HOME/logs

