#!/bin/bash

# --- Configuración de Colores ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Funciones Auxiliares ---
ask_yes_no() {
    while true; do
        read -r -p "$(echo -e "${BLUE}$1 ${NC}[S/N]: ")" response
        case "$response" in
            [sS][iI]|[sS]) return 0 ;;
            [nN][oO]|[nN]) return 1 ;;
            *) echo -e "${RED}Respuesta inválida. Por favor, introduce S o N.${NC}" ;;
        esac
    done
}

check_command_installed() {
    command -v "$1" &> /dev/null
}

install_package() {
    local cmd_name="$1"
    local pkg_name="$2"
    local friendly_name="$3"

    if ! check_command_installed "$cmd_name"; then
        echo -e "${YELLOW}La herramienta '${friendly_name}' ($cmd_name) no parece estar instalada.${NC}"
        if ask_yes_no "¿Deseas intentar instalar el paquete '$pkg_name' ahora? (requiere sudo)"; then
            sudo apt update && sudo apt install -y "$pkg_name"
            if ! check_command_installed "$cmd_name"; then
                echo -e "${RED}La instalación de '$pkg_name' falló o no proveyó el comando '$cmd_name'.${NC}"
                echo -e "${RED}Por favor, instálala manualmente y considera re-ejecutar esta sección del script si es necesario.${NC}"
                return 1
            else
                echo -e "${GREEN}'$friendly_name' instalado correctamente.${NC}"
            fi
        else
            echo -e "${YELLOW}Instalación de '${friendly_name}' omitida.${NC}"
            return 1
        fi
    fi
    return 0
}


# --- Inicio del Script ---
clear
echo -e "${GREEN}==========================================================${NC}"
echo -e "${GREEN} ASISTENTE DE MIGRACIÓN DE EQUIPO - FASE 2: RESTAURACIÓN ${NC}"
echo -e "${GREEN}==========================================================${NC}"
echo
echo "Este script te ayudará a restaurar tus archivos desde el backup y"
echo "a configurar herramientas esenciales en tu nueva notebook."
echo

if ! ask_yes_no "¿Estás listo para comenzar la configuración?"; then
    echo -e "${YELLOW}Operación cancelada.${NC}"
    exit 0
fi

# --- PASO 1: Restaurar Backup ---
echo
echo -e "${BLUE}--- PASO 1: Restaurar Archivos desde el Backup ---${NC}"
DEFAULT_BACKUP_PATH="$HOME/${USER}_*backup.tar.gz" # Intenta encontrarlo con un patrón
SUGGESTED_BACKUP_FILE=$(ls -t $HOME/${USER}_*backup.tar.gz 2>/dev/null | head -n 1)

if [ -n "$SUGGESTED_BACKUP_FILE" ] && [ -f "$SUGGESTED_BACKUP_FILE" ]; then
    echo -e "${YELLOW}Se encontró un posible archivo de backup: $SUGGESTED_BACKUP_FILE${NC}"
    if ask_yes_no "¿Usar este archivo para la restauración?"; then
        backup_filepath="$SUGGESTED_BACKUP_FILE"
    else
        read -r -p "$(echo -e "${BLUE}Introduce la ruta completa de tu archivo de backup (ej: $HOME/mi_backup.tar.gz): ${NC}")" backup_filepath
    fi
else
    read -r -p "$(echo -e "${BLUE}Introduce la ruta completa de tu archivo de backup (ej: $HOME/mi_backup.tar.gz): ${NC}")" backup_filepath
fi

backup_filepath_expanded="${backup_filepath/#\~/$HOME}"

if [ ! -f "$backup_filepath_expanded" ]; then
    echo -e "${RED}Archivo de backup no encontrado en '$backup_filepath_expanded'.${NC}"
    echo -e "${YELLOW}Por favor, asegúrate de haberlo transferido a esta máquina y verifica la ruta.${NC}"
    # Opción de omitir restauración y continuar con otros pasos:
    if ! ask_yes_no "¿Deseas continuar con los siguientes pasos de configuración sin restaurar un backup?"; then
        exit 1
    fi
else
    echo -e "${YELLOW}Se extraerá el contenido de '$backup_filepath_expanded' en tu directorio HOME ($HOME).${NC}"
    echo -e "${RED}ADVERTENCIA: Esto podría SOBRESCRIBIR archivos de configuración existentes${NC}"
    echo -e "${RED}(como .bashrc, .gitconfig, .ssh/, .kube/, etc.) si ya existen en este equipo nuevo.${NC}"
    if ask_yes_no "¿Estás seguro de continuar con la extracción?"; then
        tar -xzvf "$backup_filepath_expanded" -C "$HOME"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Backup restaurado exitosamente en $HOME.${NC}"
            echo -e "${YELLOW}Es posible que necesites reiniciar tu terminal o ejecutar 'source ~/.bashrc' (o ~/.zshrc) para que los cambios en la shell surtan efecto.${NC}"
            
            # Recordatorio permisos SSH
            if [ -d "$HOME/.ssh" ]; then
                echo -e "${BLUE}Ajustando permisos para ~/.ssh...${NC}"
                chmod 700 "$HOME/.ssh"
                chmod 600 "$HOME/.ssh/id_rsa" 2>/dev/null # Común, pero puede no existir
                chmod 644 "$HOME/.ssh/id_rsa.pub" 2>/dev/null # Común
                chmod 644 "$HOME/.ssh/known_hosts" 2>/dev/null
                chmod 600 "$HOME/.ssh/config" 2>/dev/null # Si existe
                echo -e "${GREEN}Permisos básicos de ~/.ssh ajustados. Verifica si tienes otros archivos de clave privada.${NC}"
            fi
        else
            echo -e "${RED}Error al extraer el backup. Revisa los mensajes anteriores.${NC}"
        fi
    else
        echo -e "${YELLOW}Extracción del backup omitida por el usuario.${NC}"
    fi
fi
echo

# --- PASO 2: Configuración de Herramientas ---
echo -e "${BLUE}--- PASO 2: Configuración de Herramientas Esenciales ---${NC}"

# VS Code Sync
echo -e "${YELLOW}Recordatorio Visual Studio Code:${NC}"
echo -e " - Abre VS Code."
echo -e " - Inicia sesión con tu cuenta de Github (o Microsoft)."
echo -e " - Esto debería sincronizar tus extensiones, configuraciones, temas y atajos."
if ask_yes_no "¿Quieres intentar abrir VS Code ahora? (Debe estar instalado)"; then
    if check_command_installed "code"; then
        code & # El & lo manda a background
    else
        echo -e "${RED}Comando 'code' no encontrado. Por favor, instala VS Code (ej: desde Ubuntu Software o .deb de su web) y ábrelo manualmente.${NC}"
    fi
fi
echo

# Rancher Login
if ask_yes_no "¿Deseas configurar el acceso a Rancher (ra.adhoc.ar)?"; then
    if install_package "rancher" "rancher-cli" "Rancher CLI"; then # 'rancher' es el comando usual, paquete 'rancher-cli'
        echo -e "${BLUE}Obtén tu Bearer Token desde ${GREEN}https://ra.adhoc.ar${NC} (API & Keys -> Crear Token).${NC}"
        read -r -p "$(echo -e "${BLUE}Pega tu Bearer Token aquí: ${NC}")" rancher_token
        if [ -n "$rancher_token" ]; then
            rancher login https://ra.adhoc.ar/v3 --token "$rancher_token" --skip-verify # skip-verify si usan certs autofirmados, quitar si no
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Login a Rancher exitoso.${NC}"
                RANCHER_CONTEXT_NAME="adhocprod" # Asumiendo que este es el nombre del contexto/cluster
                echo -e "${BLUE}Intentando seleccionar el contexto/cluster de Rancher: '$RANCHER_CONTEXT_NAME'.${NC}"
                # El comando `r2 cluster adhocprod` parece un alias. El comando estándar de rancher-cli es `rancher context switch`
                # Primero listamos contextos para que el usuario vea
                echo "Contextos disponibles en Rancher:"
                rancher context list
                if rancher context switch "$RANCHER_CONTEXT_NAME"; then
                     echo -e "${GREEN}Contexto '$RANCHER_CONTEXT_NAME' seleccionado en Rancher.${NC}"
                else
                     echo -e "${RED}No se pudo seleccionar el contexto '$RANCHER_CONTEXT_NAME'.${NC}"
                     echo -e "${YELLOW}Puedes intentar manualmente con 'rancher context switch <nombre_del_contexto_correcto>'.${NC}"
                     echo -e "${YELLOW}Si 'r2' es un script de 'team-tools', podrás usarlo después de clonar ese repositorio.${NC}"
                fi
            else
                echo -e "${RED}Error durante el login a Rancher. Verifica el token y la URL.${NC}"
            fi
        else
            echo -e "${YELLOW}Token de Rancher no proporcionado. Omitiendo login.${NC}"
        fi
    fi
fi
echo

# Docker Login
if ask_yes_no "¿Deseas configurar el login a Docker Hub para el usuario 'adhocsa'?"; then
    if install_package "docker" "docker.io" "Docker"; then # docker.io es el paquete común en Ubuntu
        echo -e "${BLUE}A continuación se te pedirá tu nombre de usuario de Docker y tu Personal Access Token (PAT).${NC}"
        echo -e "${YELLOW}El nombre de usuario general para la organización es: ${GREEN}adhocsa${NC}"
        echo -e "${YELLOW}Tokens PAT por desarrollador (NO LOS COMPARTAS, ESTO ES SOLO UNA GUÍA):${NC}"
        echo "  kz:  dckr_pat_BJhgRkooSNgoK2LJ3wZNTe9TAnU"
        echo "  jok: dckr_pat_h5eU6C1noXObys7ApsqE4VQFM40"
        echo "  mnp: dckr_pat_lTOhLExBE9KDI59WSzonKGZd8cc"
        echo -e "${BLUE}Cuando se te solicite el 'Password', pega TU token PAT personal.${NC}"
        if docker login -u adhocsa; then # Docker pedirá el password (token) interactivamente
            echo -e "${GREEN}Login a Docker Hub para 'adhocsa' exitoso (o ya estabas logueado).${NC}"
        else
            echo -e "${RED}Error durante el login a Docker. Verifica tus credenciales e inténtalo manualmente.${NC}"
        fi
    fi
fi
echo

# Clonar team-tools
TEAM_TOOLS_REPO="git@github.com:ingadhoc/team-tools.git"
TEAM_TOOLS_PATH="$HOME/repositorios/team-tools"
if ask_yes_no "¿Deseas clonar/actualizar el repositorio 'ingadhoc/team-tools' en '$TEAM_TOOLS_PATH'?"; then
    if install_package "git" "git" "Git"; then
        if [ -d "$TEAM_TOOLS_PATH/.git" ]; then
            echo -e "${YELLOW}El directorio $TEAM_TOOLS_PATH ya parece ser un repositorio Git.${NC}"
            if ask_yes_no "¿Intentar actualizarlo con 'git pull'?"; then
                current_dir=$(pwd)
                cd "$TEAM_TOOLS_PATH" || { echo -e "${RED}No se pudo acceder a $TEAM_TOOLS_PATH${NC}"; cd "$current_dir"; }
                git pull
                cd "$current_dir" || exit 1
            fi
        else
            mkdir -p "$(dirname "$TEAM_TOOLS_PATH")"
            echo -e "${BLUE}Clonando $TEAM_TOOLS_REPO en $TEAM_TOOLS_PATH...${NC}"
            if git clone "$TEAM_TOOLS_REPO" "$TEAM_TOOLS_PATH"; then
                echo -e "${GREEN}Repositorio team-tools clonado exitosamente.${NC}"
                echo -e "${YELLOW}Puede que necesites agregar scripts de '$TEAM_TOOLS_PATH/bin' (o similar) a tu \$PATH.${NC}"
                echo -e "${YELLOW}Por ejemplo, editando tu ~/.bashrc o ~/.zshrc y añadiendo: export PATH=\"\$PATH:$TEAM_TOOLS_PATH/bin\"${NC}"
                echo -e "${YELLOW}Luego ejecuta 'source ~/.bashrc' (o ~/.zshrc).${NC}"

                # Si 'r2' es de team-tools, ahora podría estar disponible
                if ask_yes_no "El comando 'r2' podría estar en team-tools. ¿Reintentar seleccionar cluster 'adhocprod' con 'r2 cluster adhocprod'?"; then
                    # Podría necesitar que el PATH se actualice primero
                    echo -e "${BLUE}Intentando ejecutar 'r2 cluster adhocprod'...${NC}"
                    echo -e "${YELLOW}Nota: Si esto falla, puede que necesites primero agregar team-tools al PATH y 'source ~/.bashrc'.${NC}"
                    # Intento ingenuo, puede fallar si no está en PATH y no se ha sourceado nada.
                    if [ -x "$TEAM_TOOLS_PATH/bin/r2" ]; then # Ejemplo de ruta
                        "$TEAM_TOOLS_PATH/bin/r2" cluster adhocprod
                    elif command -v r2 &>/dev/null ; then
                        r2 cluster adhocprod
                    else
                        echo -e "${RED}Comando 'r2' no encontrado directamente. Configura tu PATH.${NC}"
                    fi
                fi
            else
                echo -e "${RED}Error al clonar team-tools.${NC}"
                echo -e "${YELLOW}Verifica que tu clave SSH esté correctamente configurada en GitHub (${GREEN}https://github.com/settings/keys${NC}).${NC}"
                echo -e "${YELLOW}Puedes probar con: ssh -T git@github.com${NC}"
            fi
        fi
    fi
fi
echo

# Odoo Initial Setup
if ask_yes_no "¿Necesitas ejecutar el script 'initial_setup.sh' para alguna instancia de Odoo?"; then
    echo -e "${YELLOW}Este script usualmente se encuentra dentro de cada carpeta de versión de Odoo (ej: ~/odoo/16.0/scripts/initial_setup.sh).${NC}"
    read -r -p "$(echo -e "${BLUE}Introduce la ruta a la carpeta de la versión de Odoo donde ejecutar el script (ej: ~/odoo/16.0): ${NC}")" odoo_instance_path
    odoo_instance_path_expanded="${odoo_instance_path/#\~/$HOME}"
    initial_setup_script="$odoo_instance_path_expanded/scripts/initial_setup.sh"

    if [ -f "$initial_setup_script" ]; then
        echo -e "${BLUE}Se encontró el script: $initial_setup_script${NC}"
        if ask_yes_no "¿Ejecutar este script ahora?"; then
            current_dir=$(pwd)
            cd "$odoo_instance_path_expanded" || { echo -e "${RED}No se pudo acceder a $odoo_instance_path_expanded${NC}"; cd "$current_dir"; }
            echo -e "${BLUE}Ejecutando ./scripts/initial_setup.sh en $(pwd)...${NC}"
            # Algunos scripts esperan ser ejecutados desde su propio directorio
            if ./scripts/initial_setup.sh; then
                echo -e "${GREEN}Script initial_setup.sh ejecutado correctamente.${NC}"
            else
                echo -e "${RED}Error al ejecutar initial_setup.sh. Revisa la salida del script.${NC}"
            fi
            cd "$current_dir" || exit 1
        fi
    else
        echo -e "${RED}Script initial_setup.sh no encontrado en '$initial_setup_script'. Omitiendo.${NC}"
    fi
fi
echo

# --- PASO 3: Software Adicional y Pasos Finales ---
echo -e "${BLUE}--- PASO 3: Software Adicional y Pasos Finales ---${NC}"
echo -e "${YELLOW}Considera instalar otras herramientas que uses frecuentemente.${NC}"
COMMON_TOOLS=("curl" "wget" "jq" "vim" "tree" "htop" "net-tools" "build-essential" "python3-pip" "openjdk-17-jdk" "gnome-tweaks" "dconf-editor") # Añade más según necesidad
echo "Algunas herramientas comunes para desarrolladores Ubuntu:"
for tool in "${COMMON_TOOLS[@]}"; do echo -n " $tool"; done
echo
if ask_yes_no "¿Deseas instalar una selección de estas herramientas comunes ahora? (requiere sudo)"; then
    # Filtrar las que ya están instaladas para no intentar reinstalarlas
    TOOLS_TO_INSTALL=()
    for tool_pkg_name in "${COMMON_TOOLS[@]}"; do
        # Para algunos nombres de comando, el paquete es diferente (ej. openjdk)
        # Esta es una simplificación, `dpkg -s $tool_pkg_name &> /dev/null` sería más preciso para el nombre del paquete
        if ! dpkg -s $tool_pkg_name &> /dev/null && ! command -v $tool_pkg_name &> /dev/null; then # Ver si el paquete o comando existe
             TOOLS_TO_INSTALL+=("$tool_pkg_name")
        fi
    done
    if [ ${#TOOLS_TO_INSTALL[@]} -gt 0 ]; then
        echo -e "${BLUE}Se intentará instalar: ${TOOLS_TO_INSTALL[*]}${NC}"
        sudo apt update
        sudo apt install -y "${TOOLS_TO_INSTALL[@]}"
        echo -e "${GREEN}Instalación de herramientas comunes completada (o intentada).${NC}"
    else
        echo -e "${GREEN}Parece que la mayoría de las herramientas comunes sugeridas ya están instaladas.${NC}"
    fi
fi
echo

echo -e "${GREEN}==========================================================${NC}"
echo -e "${GREEN} CONFIGURACIÓN BÁSICA ASISTIDA COMPLETADA ${NC}"
echo -e "${GREEN}==========================================================${NC}"
echo -e "${YELLOW}Pasos finales y recomendaciones:${NC}"
echo -e "1. ${BLUE}REINICIA TU TERMINAL${NC} o ejecuta ${GREEN}source ~/.bashrc${NC} (o ${GREEN}source ~/.zshrc${NC}) para aplicar todos los cambios de shell."
echo -e "2. ${BLUE}Verifica tus herramientas:${NC} Prueba `git`, `docker`, `rancher`, acceso a Odoo, etc."
echo -e "3. ${BLUE}Configuraciones específicas de proyectos:${NC} Algunos proyectos pueden requerir variables de entorno"
echo -e "   adicionales, bases de datos locales, o configuraciones específicas. Revisa la documentación de cada proyecto."
echo -e "4. ${BLUE}Explora las configuraciones de tu sistema Ubuntu:${NC} Ajusta el dock, temas, atajos de teclado, etc., a tu gusto."
echo
echo -e "${GREEN}¡Bienvenido/a a tu nueva notebook! Que la disfrutes.${NC}"
echo -e "${BLUE}Si tienes problemas, consulta al equipo de #sistemas-devops.${NC}"

exit 0
