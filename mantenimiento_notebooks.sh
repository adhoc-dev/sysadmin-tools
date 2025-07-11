#!/bin/bash
###################################################################################################
# Script de mantenimiento y actualización para notebooks Ubuntu/Debian
# Repositorio: https://github.com/adhoc-dev/sysadmin-tools
# Autor original: TedLeRoy (adaptado por Diego Bollini)
# Compañía: adhoc.inc
# Tiempo estimado: 10 minutos
###################################################################################################

# Colores para mensajes en consola
red=$(tput setaf 1)
yellow=$(tput setaf 3)
green=$(tput setaf 2)
normal=$(tput sgr0)

# Variables generales
TOKEN_PATH="/etc/opt/chrome/policies/enrollment/CloudManagementEnrollmentToken"
TOKEN_CONTENT="7c58fdad-6f91-43f9-9460-70fd9d5b7542"
UPDATE_LOG="/tmp/update-output.txt"

# Mensaje de presentación
HEADER="
GRACIAS POR EJECUTAR ESTE PROGRAMA DE AUTO-MANTENIMIENTO DE EQUIPOS.
TE MERECES ESTO 🎁👏🤗
Es un script simple para actualizar y limpiar notebooks de Adhoc (Ubuntu/Debian).
No hay garantía ni mantenimiento fuera del alcance de Adhoc S.A.
"

# Función: Verificar si se ejecuta como root
__check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "${red}Este script debe ejecutarse con privilegios de root (usa sudo).${normal}"
        exit 1
    fi
}

# Función: Mostrar mensaje de presentación
__display_header() {
    echo "${green}$HEADER${normal}"
}

# Función: Verificar y crear token de inscripción para Chrome
__check_token() {
    echo -e "${green}###################################################"
    echo "# Verificando existencia del token de inscripción  #"
    echo "###################################################${normal}"
    if [ ! -f "$TOKEN_PATH" ]; then
        echo -e "${red}El token de inscripción no existe. Creándolo ahora...${normal}"
        mkdir -p "$(dirname "$TOKEN_PATH")"
        echo "$TOKEN_CONTENT" > "$TOKEN_PATH"
        echo -e "${green}Token de inscripción creado exitosamente en $TOKEN_PATH.${normal}"
    else
        echo -e "${green}El token de inscripción ya existe en $TOKEN_PATH. No se requiere acción.${normal}"
    fi
}

# Función: Actualizar repositorios
__update_repos() {
    echo -e "${green}###################################"
    echo "#     Actualizando repositorios   #"
    echo "###################################${normal}"
    apt-get update | tee "$UPDATE_LOG"
}

# Función: Actualizar sistema y paquetes
__upgrade_system() {
    echo -e "${green}####################################"
    echo "# Actualizando sistema operativo   #"
    echo "####################################${normal}"
    apt-get upgrade -y | tee -a "$UPDATE_LOG"
    apt-get install unattended-upgrades -y | tee -a "$UPDATE_LOG"
    snap refresh | tee -a "$UPDATE_LOG"
    apt-get install -y screenfetch dmidecode cowsay
}

# Función: Limpiar caché y paquetes
__clean_system() {
    echo -e "${green}#####################################"
    echo "#    Limpieza de caché y paquetes   #"
    echo "#####################################${normal}"
    apt-get clean -y | tee -a "$UPDATE_LOG"
    apt-get autoclean -y | tee -a "$UPDATE_LOG"
    apt-get autoremove -y | tee -a "$UPDATE_LOG"
}

# Función: Ajustar permisos del directorio /tmp (debe ser 1777)
__fix_tmp_permissions() {
    TMP_PERM=$(stat -c "%a" /tmp)
    if [ "$TMP_PERM" -ne 1777 ]; then
        echo "Ajustando permisos en /tmp (actual: $TMP_PERM, se requiere 1777)"
        chmod 1777 /tmp
    fi
}

# Función: Ajustar permisos del archivo de configuración de Rancher CLI
__fix_rancher_config_permissions() {
    if [ -n "$SUDO_USER" ]; then
        USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        CONFIG_FILE="$USER_HOME/.rancher/cli2.json"
        if [ -f "$CONFIG_FILE" ]; then
            echo "Ajustando permisos de $CONFIG_FILE a 600"
            chmod 600 "$CONFIG_FILE"
        fi
    fi
}

# Función: Actualizar el binario de Rancher CLI si está instalado
__update_rancher() {
    if command -v rancher2 >/dev/null 2>&1 || command -v rancher >/dev/null 2>&1; then
        echo -e "${green}#############################################"
        echo "Actualizando Rancher CLI..."
        echo "#############################################${normal}"
        # Obtener versión actual (se prefiere 'rancher' si está disponible)
        if command -v rancher >/dev/null 2>&1; then
            CURRENT_VERSION=$(rancher -v | awk '{print $3}' | tr -d 'v')
        else
            CURRENT_VERSION=$(rancher2 -v | awk '{print $3}' | tr -d 'v')
        fi
        LATEST_VERSION=$(curl -s https://api.github.com/repos/rancher/cli/releases/latest | jq -r '.tag_name' | tr -d 'v')
        DOWNLOAD_URL=$(curl -s https://api.github.com/repos/rancher/cli/releases/latest | \
            jq -r --arg v "$LATEST_VERSION" '.assets[] | select(.name | test("rancher-linux-amd64-v"+$v+"\\.tar\\.gz$")) | .browser_download_url')
        if [[ "$CURRENT_VERSION" != "$LATEST_VERSION" ]]; then
            echo "Descargando Rancher CLI $LATEST_VERSION..."
            cd /tmp/
            wget -q -O rancher.tar.gz "$DOWNLOAD_URL"
            tar -xzf rancher.tar.gz 2>/dev/null
            sudo mv rancher-v$LATEST_VERSION/rancher /usr/local/bin/rancher
            ln -sf /usr/local/bin/rancher /usr/local/bin/rancher2
            rm -rf rancher.tar.gz rancher-v$LATEST_VERSION
            cd -
            echo "Rancher CLI actualizado a la versión $(rancher -v)"
            __fix_rancher_config_permissions
        else
            echo "Rancher CLI ya está actualizado a la última versión"
        fi
    fi
}

# Función: Mantenimiento de Docker (limpiar contenedores, imágenes y volúmenes sin uso)
__mantenimiento_docker() {
    if command -v docker >/dev/null 2>&1; then
        echo -e "${green}#############################################"
        echo "#   Ejecutando mantenimiento de Docker      #"
        echo "#############################################${normal}"
    #    docker container prune -f
        docker image prune -a -f
    #    docker volume prune -a -f
    else
        echo -e "${yellow}Docker no está instalado. Saltando mantenimiento de Docker.${normal}"
    fi
}

# Función: Mostrar log de actualización y limpiar archivos temporales
__show_update_log() {
    if [ -f "$UPDATE_LOG" ]; then
        echo -e "${green}################################################"
        echo "#  Acciones relevantes durante la actualización  #"
        echo "################################################${normal}"
        egrep -wi --color 'warning|error|critical|reboot|restart|autoclean|autoremove' "$UPDATE_LOG" | uniq
        echo -e "${green}#######################################"
        echo "#    Limpiando archivos temporales    #"
        echo "#######################################${normal}"
        rm -f "$UPDATE_LOG"
        apt-get autoremove -y
        echo -e "${green}#############################################"
        echo "#     POR FAVOR HACER CAPTURA DE PANTALLA       #"
        echo "#     PARA GUARDAR COMO EVIDENCIA DE LA         #"
        echo "#     EJECUCIÓN DEL SCRIPT                      #"
        echo "#############################################${normal}"
    fi
}

# >>> INICIO: NUEVA FUNCIÓN <<<
# Función: Configurar alias 'mantenimiento' para el usuario
__setup_alias() {
    # Solo proceder si el script se ejecuta con sudo y la variable SUDO_USER existe
    if [ -n "$SUDO_USER" ]; then
        local USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        local ALIAS_FILE="$USER_HOME/.bash_aliases"
        local ALIAS_COMMAND="alias mantenimiento='sudo bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/adhoc-dev/sysadmin-tools/main/mantenimiento_notebooks.sh)\"'"
        local ALIAS_COMMENT="# Alias para ejecutar el script de mantenimiento de Adhoc"

        echo -e "${green}######################################################"
        echo "# Configurando alias 'mantenimiento' para el usuario $SUDO_USER #"
        echo "######################################################${normal}"

        # Crear el archivo si no existe y establecer el propietario correcto
        if [ ! -f "$ALIAS_FILE" ]; then
            echo "Creando archivo $ALIAS_FILE..."
            touch "$ALIAS_FILE"
            chown "$SUDO_USER:$SUDO_USER" "$ALIAS_FILE"
        fi

        # Comprobar si el alias ya existe en el archivo para no duplicarlo
        if ! grep -qF "alias mantenimiento=" "$ALIAS_FILE"; then
            echo "Agregando el alias 'mantenimiento' a $ALIAS_FILE..."
            # Añadir el alias al final del archivo
            echo -e "\n$ALIAS_COMMENT\n$ALIAS_COMMAND" >> "$ALIAS_FILE"
            # Asegurarse de que el propietario del archivo sea el usuario y no root
            chown "$SUDO_USER:$SUDO_USER" "$ALIAS_FILE"
            echo -e "${green}Alias 'mantenimiento' agregado correctamente.${normal}"
            echo "Para usarlo, abre una nueva terminal o ejecuta: source $ALIAS_FILE"
        else
            echo "El alias 'mantenimiento' ya existe en $ALIAS_FILE. No se requiere acción."
        fi
    fi
}
# >>> FIN: NUEVA FUNCIÓN <<<

# Función: Mostrar evidencias de ejecución del script
__display_evidence() {
    echo "Fecha: $(date)"
    echo "Host: $(hostname)"
    echo "Uptime del sistema: $(uptime -p)"
    echo "Serial del sistema:"
    dmidecode -t system | grep -i 'Serial' 2>/dev/null
    echo "Información del sistema:"
    screenfetch -n | egrep 'OS:|Disk:|CPU:|RAM:'
    # Mostrar el perfil de energía actual si powerprofilesctl está instalado
    if command -v powerprofilesctl >/dev/null 2>&1; then
        echo "Perfil de energía actual:" && powerprofilesctl get
    else
        echo "powerprofilesctl no está disponible."
    fi
    # Mostrar estado y capacidad de las baterías
    echo "Estado y capacidad de las baterías:"
    for bat in $(upower -e | grep battery); do
        echo "Batería: $bat"
        upower -i "$bat" | egrep "state|percentage"
    done

    /usr/games/cowsay "¡Gracias por seguir potenciando tu notebook!"
}

# Ejecución del script
__check_root
__fix_tmp_permissions
__display_header
__check_token
__update_repos
__upgrade_system
__clean_system
__show_update_log
__update_rancher
__setup_alias  # <<< LLAMADA A LA NUEVA FUNCIÓN
#__mantenimiento_docker
__display_evidence

exit 0
