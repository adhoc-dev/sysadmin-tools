#!/bin/bash

# Función para verificar si AnyDesk está instalado
is_anydesk_installed() {
    if ! command -v anydesk &> /dev/null
    then
        return 1
    else
        return 0
    fi
}

# Función para instalar AnyDesk
install_anydesk() {
    echo "Instalando AnyDesk..."

    # Descargar AnyDesk
    wget https://download.anydesk.com/linux/anydesk_6.3.0-1_amd64.deb -O anydesk.deb

    # Instalar AnyDesk
    sudo dpkg -i anydesk.deb

    # Resolver dependencias faltantes
    sudo apt-get install -f -y

    # Eliminar archivo de descarga
    rm anydesk.deb

    echo "AnyDesk instalado."
}

# Verificar si AnyDesk está instalado
if is_anydesk_installed; then
    echo "👀 AnyDesk ya está instalado."
else
    # Instalar AnyDesk si no está instalado
    install_anydesk
fi

# Mostrar el ID de AnyDesk
echo "🏁 Tomar nota del identificador para conectarse a AnyDesk:"
anydesk --get-id
