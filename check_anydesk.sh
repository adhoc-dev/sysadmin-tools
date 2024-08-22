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

# Función para agregar la clave GPG del repositorio
add_anydesk_key() {
    if [ ! -f /etc/apt/trusted.gpg.d/anydesk.gpg ]; then
        wget -qO - https://keys.anydesk.com/repos/DEB-GPG-KEY | sudo tee /etc/apt/trusted.gpg.d/anydesk.gpg > /dev/null
        echo "🔑 Clave GPG de AnyDesk agregada."
    else
        echo "🔑 La clave GPG de AnyDesk ya está agregada."
    fi
}

# Función para agregar el repositorio de AnyDesk
add_anydesk_repo() {
    if grep -q "^deb .*anydesk.com" /etc/apt/sources.list.d/*.list; then
        echo "📦 El repositorio de AnyDesk ya está configurado."
    else
        echo "deb http://deb.anydesk.com/ all main" | sudo tee /etc/apt/sources.list.d/anydesk-stable.list
        echo "📦 Repositorio de AnyDesk agregado."
    fi
}

# Función para instalar AnyDesk desde el repositorio oficial
install_anydesk() {
    echo "🚀 Instalando AnyDesk desde el repositorio oficial..."

    # Verificar y agregar la clave GPG del repositorio
    add_anydesk_key

    # Verificar y agregar el repositorio de AnyDesk
    add_anydesk_repo

    # Actualizar la caché de apt
    sudo apt update

    # Instalar AnyDesk
    sudo apt install -y anydesk

    echo "✅ AnyDesk instalado desde el repositorio oficial."
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
