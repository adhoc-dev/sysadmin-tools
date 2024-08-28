#!/bin/bash

# Actualizar los índices de paquetes
echo "Actualizando los índices de paquetes..."
sudo apt update -qq

# Instalar paquetes auxiliares necesarios
echo "Instalando paquetes auxiliares..."
sudo apt install --no-install-recommends -y software-properties-common dirmngr

# Añadir la clave de firma para los repositorios de R
echo "Añadiendo la clave de firma para los repositorios de R..."
wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | sudo tee /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc

# Añadir el repositorio de R 4.0 desde CRAN
echo "Añadiendo el repositorio de R 4.0 desde CRAN..."
sudo add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"

# Instalar R
echo "Instalando R..."
sudo apt install --no-install-recommends -y r-base

# Descargar e instalar RStudio
echo "Descargando e instalando RStudio..."
wget https://download1.rstudio.org/electron/jammy/amd64/rstudio-2024.04.2-764-amd64.deb -O rstudio.deb
sudo apt install -y ./rstudio.deb

# Limpiar
echo "Limpiando archivos temporales..."
rm rstudio.deb

echo "Instalación completada."
