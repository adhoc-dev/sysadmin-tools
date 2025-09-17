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
    echo -e "${green}#####################################"
    echo "#   Verificando permisos de /tmp    #"
    echo "#####################################${normal}"
    
    TMP_PERM=$(stat -c "%a" /tmp)
    echo "Permisos actuales de /tmp: $TMP_PERM"
    
    if [ "$TMP_PERM" != "1777" ]; then
        echo -e "${yellow}Ajustando permisos en /tmp (actual: $TMP_PERM, se requiere 1777)${normal}"
        chmod 1777 /tmp
        echo -e "${green}✅ Permisos de /tmp corregidos${normal}"
    else
        echo -e "${green}✅ Permisos de /tmp correctos (1777)${normal}"
    fi
    
    echo -e "${green}#############################################"
    echo "#     POR FAVOR HACER CAPTURA DE PANTALLA       #"
    echo "#     PARA GUARDAR COMO EVIDENCIA DE LA         #"
    echo "#     EJECUCIÓN DEL SCRIPT                      #"
    echo "#############################################${normal}"
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
    fi
}

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
__display_header
__check_token
__update_repos
__upgrade_system
__clean_system
__show_update_log
#__mantenimiento_docker
__fix_tmp_permissions
__display_evidence

exit 0
