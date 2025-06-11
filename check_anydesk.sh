#!/bin/bash

# --- Funciones de Instalación ---

# Función para verificar si AnyDesk está instalado
is_anydesk_installed() {
    if command -v anydesk &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Función para agregar la clave GPG del repositorio de manera segura
add_anydesk_key() {
    if [ ! -f /etc/apt/trusted.gpg.d/anydesk.gpg ]; then
        echo "🔑 Agregando la clave GPG del repositorio de AnyDesk..."
        # Usar curl para descargar la clave y gpg para guardarla en el formato correcto
        curl -fsSL https://keys.anydesk.com/repos/DEB-GPG-KEY | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/anydesk.gpg > /dev/null
        echo "   Clave agregada correctamente."
    else
        echo "🔑 La clave GPG de AnyDesk ya existe."
    fi
}

# Función para agregar el repositorio de AnyDesk
add_anydesk_repo() {
    if grep -q "^deb .*anydesk.com" /etc/apt/sources.list.d/*.list; then
        echo "📦 El repositorio de AnyDesk ya está configurado."
    else
        echo "📦 Agregando el repositorio de AnyDesk..."
        echo "deb http://deb.anydesk.com/ all main" | sudo tee /etc/apt/sources.list.d/anydesk-stable.list > /dev/null
        echo "   Repositorio agregado."
    fi
}

# Función para instalar AnyDesk desde el repositorio oficial
install_anydesk() {
    echo "🚀 Instalando AnyDesk desde el repositorio oficial..."
    add_anydesk_key
    add_anydesk_repo
    
    echo "   Actualizando paquetes..."
    sudo apt update
    
    echo "   Instalando anydesk..."
    sudo apt install -y anydesk
    
    # Es una buena práctica asegurarse de que el servicio esté activo y habilitado
    sudo systemctl enable anydesk.service
    sudo systemctl start anydesk.service
    
    echo "✅ AnyDesk instalado correctamente."
}

# --- Nueva Función para Obtener el ID de forma fiable ---

# Función que espera y obtiene el ID de AnyDesk, reintentando si es necesario
get_and_display_id() {
    echo "⏳ Obteniendo el ID de AnyDesk (esperando al servicio)..."
    local id="0"
    local attempts=0
    local max_attempts=15 # Esperar un máximo de 15 segundos

    while [ "$id" = "0" ] && [ $attempts -lt $max_attempts ]; do
        id=$(anydesk --get-id 2>/dev/null || echo "0")
        if [ "$id" = "0" ]; then
            sleep 1
            attempts=$((attempts + 1))
            echo -n "." # Imprime un punto para mostrar que está esperando
        fi
    done
    echo "" # Nueva línea después de los puntos de espera

    if [ "$id" != "0" ]; then
        echo "==============================================="
        echo "✅ ID de AnyDesk obtenido:"
        echo "   ---> $id <---"
        echo "==============================================="
    else
        echo "❌ No se pudo obtener el ID de AnyDesk después de $max_attempts segundos."
        echo "   Por favor, ejecute 'anydesk --get-id' manualmente más tarde."
    fi
}


# --- Script Principal ---

if is_anydesk_installed; then
    echo "👍 AnyDesk ya está instalado."
else
    install_anydesk
fi

# Llamar a la nueva función para obtener y mostrar el ID
get_and_display_id
