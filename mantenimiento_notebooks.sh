#!/bin/bash
###################################################################################################
# Script de mantenimiento y actualización para notebooks Ubuntu/Debian
# Repositorio: https://github.com/adhoc-dev/sysadmin-tools
# Autor original: TedLeRoy (adaptado por Diego Bollini)
# Compañía: adhoc.com.ar
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
RANCHER_URL="https://github.com/rancher/cli/releases/download/v2.10.1/rancher-linux-amd64-v2.10.1.tar.gz"

# Mensaje de presentación
HEADER="
GRACIAS POR EJECUTAR ESTE PROGRAMA DE AUTO-MANTENIMIENTO DE EQUIPOS.
TE MERECES ESTO 🎁👏🤗
Es un script simple para actualizar y limpiar notebooks de Adhoc (Ubuntu/Debian).
No hay garantía ni mantenimiento fuera del alcance de Adhoc S.A.
"

# Función: Verificar si se ejecuta como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "${red}Este script debe ejecutarse con privilegios de root (usa sudo).${normal}"
        exit 1
    fi
}

# Función: Mostrar mensaje de presentación
display_header() {
    echo "${green}$HEADER${normal}"
}

# Función: Verificar y crear token de inscripción para Chrome
check_token() {
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
update_repos() {
    echo -e "${green}###################################"
    echo "#     Actualizando repositorios   #"
    echo "###################################${normal}"
    apt-get update | tee "$UPDATE_LOG"
}

# Función: Actualizar sistema y paquetes
upgrade_system() {
    echo -e "${green}####################################"
    echo "# Actualizando sistema operativo   #"
    echo "####################################${normal}"
    apt-get upgrade -y | tee -a "$UPDATE_LOG"
    apt-get install unattended-upgrades -y | tee -a "$UPDATE_LOG"
    snap refresh | tee -a "$UPDATE_LOG"
    apt-get install -y screenfetch dmidecode cowsay
}

# Función: Limpiar caché y paquetes
clean_system() {
    echo -e "${green}#####################################"
    echo "#    Limpieza de caché y paquetes   #"
    echo "#####################################${normal}"
    apt-get clean -y | tee -a "$UPDATE_LOG"
    apt-get autoclean -y | tee -a "$UPDATE_LOG"
    apt-get autoremove -y | tee -a "$UPDATE_LOG"
}

# Función: Actualizar el binario de Rancher CLI si está instalado
update_rancher() {
    # Verifica si está instalado rancher o rancher2
    local BIN_NAME
    if command -v rancher2 >/dev/null 2>&1; then
        BIN_NAME="rancher2"
    elif command -v rancher >/dev/null 2>&1; then
        BIN_NAME="rancher"
    else
        echo -e "${yellow}Rancher CLI no está instalado. Saltando actualización de Rancher.${normal}"
        return
    fi

    local RANCHER_BIN="/usr/local/bin/${BIN_NAME}"
    echo -e "${green}#############################################"
    echo "#      Actualizando Rancher CLI             #"
    echo "#############################################${normal}"
    
    local TMP_DIR
    TMP_DIR=$(mktemp -d)
    
    # Descargar usando wget o curl, según disponibilidad
    if command -v wget >/dev/null 2>&1; then
        wget -qO "$TMP_DIR/rancher.tar.gz" "$RANCHER_URL"
    elif command -v curl >/dev/null 2>&1; then
        curl -sSL "$RANCHER_URL" -o "$TMP_DIR/rancher.tar.gz"
    else
        echo "${red}No se encontró wget ni curl para descargar Rancher CLI.${normal}"
        return
    fi

    if [ $? -ne 0 ]; then
        echo "${red}Error al descargar Rancher CLI.${normal}"
        rm -rf "$TMP_DIR"
        return
    fi

    # Listamos el contenido del tar para buscar el binario que termine en "rancher"
    local BINARY_RELATIVE
    BINARY_RELATIVE=$(tar -tzf "$TMP_DIR/rancher.tar.gz" | grep -E 'rancher$' | head -n1)

    # Extraemos el tarball
    tar -xzf "$TMP_DIR/rancher.tar.gz" -C "$TMP_DIR"

    if [ -n "$BINARY_RELATIVE" ] && [ -f "$TMP_DIR/$BINARY_RELATIVE" ]; then
        cp "$TMP_DIR/$BINARY_RELATIVE" "$RANCHER_BIN"
        chmod +x "$RANCHER_BIN"
        echo -e "${green}Rancher CLI actualizado exitosamente en $RANCHER_BIN.${normal}"
    else
        echo "${red}No se encontró el binario de Rancher después de la extracción.${normal}"
    fi
    rm -rf "$TMP_DIR"
}

# Función: Ejecutar docker image prune si Docker está instalado
prune_docker() {
    if command -v docker >/dev/null 2>&1; then
        echo -e "${green}#############################################"
        echo "#   Ejecutando docker image prune (imágenes sin uso)  #"
        echo "#############################################${normal}"
        docker image prune -f
        if [ $? -eq 0 ]; then
            echo -e "${green}Docker image prune ejecutado correctamente.${normal}"
        else
            echo -e "${red}Error al ejecutar docker image prune.${normal}"
        fi
    else
        echo -e "${yellow}Docker no está instalado. Saltando docker image prune.${normal}"
    fi
}

# Función: Mostrar log de actualización y limpiar archivos temporales
show_update_log() {
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

# Función: Mostrar evidencias de ejecución del script
display_evidence() {
    echo "Fecha: $(date)"
    echo "Host: $(hostname)"
    echo "Uptime del sistema: $(uptime -p)"
    echo "Serial del sistema:"
    dmidecode -t system | grep -i 'Serial' 2>/dev/null
    echo "Información del sistema:"
    screenfetch -n | egrep 'OS:|Disk:|CPU:|RAM:'
    # Mostrar estado y capacidad de las baterías
    echo "Estado y capacidad de las baterías:"
    for bat in $(upower -e | grep battery); do
        echo "Batería: $bat"
        upower -i "$bat" | egrep "state|percentage"
    done

    /usr/games/cowsay "¡Gracias por seguir potenciando tu notebook!"
}

# Ejecución del script
check_root
display_header
check_token
update_repos
upgrade_system
clean_system
show_update_log
update_rancher
prune_docker
display_evidence

exit 0
