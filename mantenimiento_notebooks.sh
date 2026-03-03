#!/bin/bash
set -euo pipefail

__on_error() {
    local line="$1"
    echo -e "${red:-}${bold:-}❌ Error durante la ejecución (línea ${line}). Revisá la salida previa.${normal:-}"
}

trap '__on_error $LINENO' ERR

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
bold=$(tput bold)
normal=$(tput sgr0)

# Variables generales
TOKEN_PATH="/etc/opt/chrome/policies/enrollment/CloudManagementEnrollmentToken"
TOKEN_CONTENT="7c58fdad-6f91-43f9-9460-70fd9d5b7542"
UPDATE_LOG="/tmp/update-output.txt"
CAPTURE_MODE=1

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

# Función: Parsear argumentos de ejecución
__parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --normal|--full)
                CAPTURE_MODE=0
                ;;
            --capture)
                CAPTURE_MODE=1
                ;;
        esac
        shift
    done
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

# Función: Verificar e instalar Adhoc CLI (adhoccli) y dependencias/repositorios necesarios
__ensure_adhoccli() {
    echo -e "${green}#############################################"
    echo "# Verificando instalación de Adhoc CLI (ad) #"
    echo "#############################################${normal}"

    if command -v ad >/dev/null 2>&1; then
        CURRENT_AD_PATH="$(command -v ad)"
        echo -e "${green}Se detectó Adhoc CLI en:${normal} $CURRENT_AD_PATH"
        if [[ "$CURRENT_AD_PATH" == "/usr/local/bin/ad" ]]; then
            echo -e "${yellow}Advertencia: 'ad' está resolviendo a /usr/local/bin/ad (posible instalación manual antigua).${normal}"
            echo -e "${yellow}Se intentará instalar/actualizar el paquete 'adhoccli' desde APT igualmente.${normal}"
        fi
    else
        echo -e "${yellow}Adhoc CLI no está instalado. Preparando dependencias y repositorios...${normal}"
    fi

    apt-get install -y ca-certificates curl gnupg wget | tee -a "$UPDATE_LOG"

    install -d -m 0755 /usr/share/keyrings

    if [ ! -f /usr/share/keyrings/cloud.google.gpg ]; then
        curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
            | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
    fi
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
        > /etc/apt/sources.list.d/google-cloud-sdk.list

    if [ ! -f /usr/share/keyrings/adhoc-devops.gpg ]; then
        wget -qO - https://apt.dev-adhoc.com/adhoc-devops.asc \
            | gpg --dearmor -o /usr/share/keyrings/adhoc-devops.gpg
    fi
    echo "deb [signed-by=/usr/share/keyrings/adhoc-devops.gpg] https://apt.dev-adhoc.com/ stable main" \
        > /etc/apt/sources.list.d/adhoc.list

    apt-get update | tee -a "$UPDATE_LOG"

    if ! command -v gcloud >/dev/null 2>&1; then
        apt-get install -y google-cloud-cli | tee -a "$UPDATE_LOG"
    fi

    apt-get install -y --only-upgrade adhoccli | tee -a "$UPDATE_LOG" || true
    apt-get install -y adhoccli | tee -a "$UPDATE_LOG"

    if command -v ad >/dev/null 2>&1; then
        UPDATED_AD_PATH="$(command -v ad)"
        echo -e "${green}Adhoc CLI verificado. Ruta actual:${normal} $UPDATED_AD_PATH"

        if [[ "$UPDATED_AD_PATH" == "/usr/local/bin/ad" ]]; then
            echo -e "${yellow}Atención: sigue priorizándose /usr/local/bin/ad.${normal}"
            echo -e "${yellow}Para usar la versión de APT, remover binario manual viejo:${normal} sudo rm -f /usr/local/bin/ad"
        fi
    else
        echo -e "${red}No se pudo verificar la instalación de Adhoc CLI.${normal}"
    fi
}

# Función: Actualizar sistema y paquetes
__upgrade_system() {
    echo -e "${green}####################################"
    echo "# Actualizando sistema operativo   #"
    echo "####################################${normal}"
    apt-get upgrade -y | tee -a "$UPDATE_LOG"
    apt-get install unattended-upgrades -y | tee -a "$UPDATE_LOG"
    if command -v snap >/dev/null 2>&1; then
        snap refresh | tee -a "$UPDATE_LOG"
    else
        echo "snap no está instalado; se omite 'snap refresh'." | tee -a "$UPDATE_LOG"
    fi
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
        egrep -wi --color 'warning|error|critical|reboot|restart|autoclean|autoremove' "$UPDATE_LOG" | uniq || true
        echo -e "${green}#######################################"
        echo "#    Limpiando archivos temporales    #"
        echo "#######################################${normal}"
        rm -f "$UPDATE_LOG"
    fi
}

# Función: Mostrar evidencias de ejecución del script
__display_evidence() {
    echo "Fecha: $(date)"
    echo "Host: $(hostname)"
    echo "Uptime del sistema: $(uptime -p)"
    echo "Serial del sistema:"
    dmidecode -t system | grep -i 'Serial' 2>/dev/null || true
    echo "Información del sistema:"
    screenfetch -n | egrep 'OS:|Disk:|CPU:|RAM:' || true
    # Verificar adhoccli (comando: ad) y su versión
    echo "Adhoc CLI (adhoccli):"
    if command -v ad >/dev/null 2>&1; then
        ADHOCCLI_PATH="$(command -v ad)"
        echo -e " ${red}${bold}Ruta:${normal} $ADHOCCLI_PATH"

        AD_CMD=(ad)
        if [ "$EUID" -eq 0 ] && [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER:-}" != "root" ]; then
            AD_CMD=(sudo -u "$SUDO_USER" ad)
        fi

        ADHOCCLI_VERSION="$("${AD_CMD[@]}" --version 2>&1 | head -n 1 || true)"
        if [ -z "$ADHOCCLI_VERSION" ]; then
            ADHOCCLI_VERSION="$("${AD_CMD[@]}" 2>&1 | head -n 1 || true)"
        fi

        if [ -n "$ADHOCCLI_VERSION" ]; then
            if echo "$ADHOCCLI_VERSION" | grep -qi '^Adhoc Cli v:'; then
                ADHOCCLI_VERSION_VALUE="${ADHOCCLI_VERSION#*: }"
                echo -e " ${red}${bold}Adhoc Cli v:${normal} $ADHOCCLI_VERSION_VALUE"
            else
                echo " $ADHOCCLI_VERSION"
            fi
        else
            if [ "$EUID" -eq 0 ] && [ -z "${SUDO_USER:-}" ]; then
                echo "Ejecutaste como root directo. Para ver adhoccli, corré el script con sudo desde tu usuario normal."
            else
                echo "adhoccli está instalado, pero no devolvió información visible de versión."
            fi
        fi

        ADHOCCLI_APT_VERSION="$(dpkg-query -W -f='${Version}' adhoccli 2>/dev/null || true)"
        if [ -n "$ADHOCCLI_APT_VERSION" ]; then
            echo -e " ${red}${bold}adhoccli (APT):${normal} $ADHOCCLI_APT_VERSION"
        fi

        ADHOCCLI_RUNNING_VERSION="$(echo "$ADHOCCLI_VERSION" | sed -nE 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' | head -n 1 || true)"
        ADHOCCLI_APT_VERSION_SHORT="$(echo "$ADHOCCLI_APT_VERSION" | sed -nE 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' | head -n 1 || true)"

        if [ -n "$ADHOCCLI_RUNNING_VERSION" ] && [ -n "$ADHOCCLI_APT_VERSION_SHORT" ] && [ "$ADHOCCLI_RUNNING_VERSION" != "$ADHOCCLI_APT_VERSION_SHORT" ]; then
            echo -e " ${yellow}${bold}⚠ versión en ejecución distinta a versión APT (${ADHOCCLI_RUNNING_VERSION} vs ${ADHOCCLI_APT_VERSION_SHORT}).${normal}"
            if [[ "$ADHOCCLI_PATH" == "/usr/local/bin/ad" ]]; then
                echo -e " ${yellow}Posible causa: binario manual en /usr/local/bin/ad tiene prioridad en PATH.${normal}"
            fi
        fi
    else
        echo "adhoccli no está instalado (comando 'ad' no encontrado)."
    fi
    # Mostrar el perfil de energía actual si powerprofilesctl está instalado
    if command -v powerprofilesctl >/dev/null 2>&1; then
        echo "Perfil de energía actual:"
        POWER_PROFILE="$(powerprofilesctl get 2>/dev/null | head -n 1 || true)"
        if [ -n "$POWER_PROFILE" ]; then
            echo -e " ${red}${bold}$POWER_PROFILE${normal}"
        else
            echo " no disponible"
        fi
    else
        echo "powerprofilesctl no está disponible."
    fi
    # Mostrar estado y capacidad de las baterías
    echo "Estado y capacidad de las baterías:"
    BATTERY_LIST="$(upower -e | grep battery | grep -v hidpp || true)"
    if [ -z "$BATTERY_LIST" ]; then
        echo "Batería: no detectada"
    fi
    while IFS= read -r bat; do
        [ -z "$bat" ] && continue
        echo "Batería: $bat"
        BAT_STATE="$(upower -i "$bat" | awk -F': *' '/state:/ {print $2; exit}' || true)"
        BAT_PERCENTAGE="$(upower -i "$bat" | awk -F': *' '/percentage:/ {print $2; exit}' || true)"
        printf "    state:               %s\n" "${BAT_STATE:-N/D}"
        printf "    percentage:          %s\n" "${BAT_PERCENTAGE:-N/D}"
    done <<< "$BATTERY_LIST"

    echo "Resumen rápido:"
    ROOT_USED="$(df -h / | awk 'NR==2 {print $5}')"
    ROOT_USED_NUM="${ROOT_USED%\%}"
    if [ -n "$ROOT_USED_NUM" ] && [ "$ROOT_USED_NUM" -ge 90 ]; then
        ROOT_STATUS="${red}${bold}❌ crítico${normal}"
    elif [ -n "$ROOT_USED_NUM" ] && [ "$ROOT_USED_NUM" -ge 80 ]; then
        ROOT_STATUS="${yellow}${bold}⚠️ atención${normal}"
    else
        ROOT_STATUS="${green}${bold}✅ ok${normal}"
    fi

    REBOOT_STATUS="${green}${bold}✅ no${normal}"
    if [ -f /var/run/reboot-required ]; then
        REBOOT_STATUS="${yellow}${bold}⚠️ sí${normal}"
    fi

    printf "  Disco raíz:            %s (%b)\n" "${ROOT_USED:-N/D}" "$ROOT_STATUS"
    printf "  Reinicio pendiente:    %b\n" "$REBOOT_STATUS"
    printf "  Adhoc CLI detectada:   %s\n" "$(command -v ad >/dev/null 2>&1 && echo sí || echo no)"

}

# Ejecución del script
__parse_args "$@"
__check_root
__display_header
__check_token
__update_repos
__ensure_adhoccli
__upgrade_system
__clean_system
__show_update_log
__mantenimiento_docker
__fix_tmp_permissions
if [ "$CAPTURE_MODE" -eq 1 ]; then
    clear
fi
__display_evidence

exit 0
