#!/bin/bash

# --- Configuración de Colores (para fallback a CLI) ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Variable Global para Zenity ---
USE_ZENITY=false

# --- Funciones Auxiliares ---
check_and_setup_zenity() {
    if ! command -v zenity &> /dev/null; then
        echo -e "${YELLOW}Zenity (para diálogos gráficos) no está instalado.${NC}"
        read -r -p "$(echo -e "${BLUE}¿Deseas intentar instalar Zenity ahora? Esto mejorará la interfaz del script. [S/N]: ${NC}")" response
        if [[ "$response" =~ ^[sS]$ ]]; then
            sudo apt update && sudo apt install -y zenity
            if ! command -v zenity &> /dev/null; then
                echo -e "${RED}No se pudo instalar Zenity. El script continuará en modo texto.${NC}"
                USE_ZENITY=false; return
            else
                echo -e "${GREEN}Zenity instalado correctamente.${NC}"
                USE_ZENITY=true
            fi
        else
            echo -e "${YELLOW}Zenity no se instalará. El script continuará en modo texto.${NC}"
            USE_ZENITY=false; return
        fi
    else
        USE_ZENITY=true
    fi
    if [ "$USE_ZENITY" = true ] && [ -z "$DISPLAY" ]; then
        echo -e "${YELLOW}No se detectó un entorno gráfico (DISPLAY no está configurado). Zenity no funcionará.${NC}"
        echo -e "${YELLOW}Cambiando a modo texto.${NC}"
        USE_ZENITY=false
    fi
}

check_and_setup_zenity

ask_yes_no() {
    local question_text="$1"; local title="${2:-Confirmación}"
    if [ "$USE_ZENITY" = true ]; then zenity --question --title="$title" --text="$question_text" --width=400 --height=150 --icon-name=dialog-question; return $?; else
        while true; do read -r -p "$(echo -e "${BLUE}${question_text} ${NC}[S/N]: ")" response
            case "$response" in [sS][iI]|[sS]) return 0 ;; [nN][oO]|[nN]) return 1 ;; *) echo -e "${RED}Respuesta inválida.${NC}" ;; esac
        done; fi
}
show_info() {
    local message_text="$1"; local title="${2:-Información}"
    if [ "$USE_ZENITY" = true ]; then zenity --info --title="$title" --text="$message_text" --width=450 --height=150 --icon-name=dialog-information; else echo -e "${GREEN}$message_text${NC}"; fi
}
show_warning() {
    local message_text="$1"; local title="${2:-Advertencia}"
    if [ "$USE_ZENITY" = true ]; then zenity --warning --title="$title" --text="$message_text" --width=450 --height=150 --icon-name=dialog-warning; else echo -e "${YELLOW}$message_text${NC}"; fi
}
show_error() {
    local message_text="$1"; local title="${2:-Error}"
    if [ "$USE_ZENITY" = true ]; then zenity --error --title="$title" --text="$message_text" --width=450 --height=150 --icon-name=dialog-error; else echo -e "${RED}$message_text${NC}"; fi
}
show_text_info() {
    local file_content="$1"; local title="${2:-Información Detallada}"
    if [ "$USE_ZENITY" = true ]; then
        zenity --text-info --title="$title" --filename=<(echo -e "$file_content") --width=600 --height=400 --icon-name=dialog-information
    else
        echo -e "${BLUE}--- $title ---${NC}"
        echo -e "$file_content"
        echo -e "${BLUE}--------------------${NC}"
    fi
}
get_text_input() {
    local prompt_text="$1"; local title="${2:-Entrada de Texto}"; local default_text="${3:-}"
    if [ "$USE_ZENITY" = true ]; then
        zenity --entry --title="$title" --text="$prompt_text" --entry-text="$default_text" --width=450
    else
        read -r -p "$(echo -e "${BLUE}${prompt_text}${NC} (def: $default_text): ")" input_val
        echo "${input_val:-$default_text}"
    fi
}
get_password_input() {
    local prompt_text="$1"; local title="${2:-Entrada Segura}"
    if [ "$USE_ZENITY" = true ]; then
        zenity --password --title="$title" --text="$prompt_text" --width=450
    else # CLI password input
        read -r -s -p "$(echo -e "${BLUE}${prompt_text}:${NC} ")" input_val; echo; echo "$input_val"
    fi
}
select_file() {
    local title="${1:-Seleccionar Archivo}"; local file_filter_name="${2}"; local file_filter_pattern="${3}"
    if [ "$USE_ZENITY" = true ]; then
        if [ -n "$file_filter_name" ] && [ -n "$file_filter_pattern" ]; then
            zenity --file-selection --title="$title" --file-filter="$file_filter_name | $file_filter_pattern"
        else
            zenity --file-selection --title="$title"
        fi
    else
        read -r -p "$(echo -e "${BLUE}Ruta al archivo ($title): ${NC}")" filepath_cli
        echo "$filepath_cli"
    fi
}
select_directory() {
    local title="${1:-Seleccionar Directorio}"
    if [ "$USE_ZENITY" = true ]; then
        zenity --file-selection --directory --title="$title"
    else
        read -r -p "$(echo -e "${BLUE}Ruta al directorio ($title): ${NC}")" dirpath_cli
        echo "$dirpath_cli"
    fi
}
check_command_installed() {
    if [ -z "$1" ]; then return 1; fi
    command -v "$1" &> /dev/null
}
install_package_interactive() {
    local cmd_name="$1"; local pkg_name="$2"; local friendly_name="$3"
    if ! check_command_installed "$cmd_name"; then
        if ask_yes_no "La herramienta '${friendly_name}' ($cmd_name) no parece estar instalada.\n¿Deseas intentar instalar el paquete '$pkg_name' ahora? (requiere sudo)" "Instalar Paquete"; then
            (
              echo "0"; echo "# Actualizando lista de paquetes..."
              sudo apt update
              echo "50"; echo "# Instalando $pkg_name..."
              sudo apt install -y "$pkg_name"
              echo "100"; echo "# ¡Instalación completada!"
              sleep 1
            ) | zenity --progress --title="Instalando $friendly_name" --pulsate --auto-close --auto-kill --width=500  2>/dev/null 
            
            if ! check_command_installed "$cmd_name"; then
                show_error "La instalación de '$pkg_name' falló o no proveyó el comando '$cmd_name'.\nPor favor, instálala manualmente." "Error de Instalación"
                return 1
            else
                show_info "'$friendly_name' instalado correctamente." "Instalación Exitosa"
            fi
        else
            show_warning "Instalación de '${friendly_name}' omitida." "Instalación Omitida"; return 1
        fi
    fi
    return 0
}
# --- Fin Funciones Auxiliares ---

# --- Inicio del Script ---
if [ "$USE_ZENITY" = true ]; then
    zenity --info --title="Asistente de Migración" --text="Bienvenido al Asistente de Migración de Equipo - FASE 2: RESTAURACIÓN.\n\nEste script te ayudará a restaurar tus archivos y configurar herramientas." --width=500 --icon-name=system-software-install
else
    clear
    echo -e "${GREEN}==========================================================${NC}"
    echo -e "${GREEN} ASISTENTE DE MIGRACIÓN DE EQUIPO - FASE 2: RESTAURACIÓN ${NC}"
    echo -e "${GREEN}==========================================================${NC}"
    echo -e "${YELLOW}Este script te ayudará a restaurar tus archivos y configurar herramientas.${NC}"; echo
fi

if ! ask_yes_no "¿Estás listo para comenzar la configuración del nuevo equipo?" "Inicio de Restauración"; then
    show_info "Operación cancelada." "Cancelado"; exit 0
fi

# --- PASO 1: Restaurar Backup ---
backup_filepath_gui=""
backup_filepath_expanded=""

temp_backup_path=$(select_file "Selecciona tu archivo de backup (.tar.gz)" "Archivos TAR GZ" "*.tar.gz")
zenity_exit_status=$? 

if [ $zenity_exit_status -eq 0 ] && [ -n "$temp_backup_path" ]; then
    backup_filepath_gui="$temp_backup_path"
    backup_filepath_expanded="${backup_filepath_gui/#\~/$HOME}"

    if [[ "$backup_filepath_expanded" != *.tar.gz ]]; then
        show_error "El archivo seleccionado:\n'$backup_filepath_expanded'\nno parece ser un archivo .tar.gz válido.\n\nPor favor, selecciona un archivo con la extensión .tar.gz." "Extensión de Archivo Inválida"
        backup_filepath_expanded="" 
    elif [ ! -f "$backup_filepath_expanded" ]; then 
        show_error "El archivo de backup especificado no existe en la ruta:\n'$backup_filepath_expanded'" "Archivo no Encontrado"
        backup_filepath_expanded="" 
    fi
else
    show_warning "No se seleccionó ningún archivo de backup o se canceló la selección." "Backup Omitido"
fi

if [ -z "$backup_filepath_expanded" ]; then
    if ! ask_yes_no "¿Deseas continuar con los siguientes pasos de configuración sin restaurar un backup?" "Continuar sin Backup"; then
        show_info "Operación cancelada." "Cancelado"
        exit 1
    fi
fi

if [ -n "$backup_filepath_expanded" ] && [ -f "$backup_filepath_expanded" ]; then
    if ask_yes_no "Se extraerá el contenido de:\n'$backup_filepath_expanded'\n\nEsto será en tu directorio HOME ($HOME) y podría SOBRESCRIBIR archivos existentes.\n\n¿Estás seguro?" "Confirmar Extracción de Backup"; then
        (
         tar -xzvf "$backup_filepath_expanded" -C "$HOME"
         sleep 1 
        ) | zenity --progress --title="Restaurando Backup" --text="Extrayendo archivos...\nEsto puede tardar unos minutos." --pulsate --auto-close --auto-kill --width=500 2>/dev/null
        
        show_info "Extracción del backup completada (o intentada).\nEs posible que necesites reiniciar tu terminal o ejecutar 'source ~/.bashrc' (o ~/.zshrc)." "Backup Restaurado"

        if [ -d "$HOME/.ssh" ]; then
            if ask_yes_no "Se detectó una carpeta ~/.ssh.\n¿Deseas intentar ajustar sus permisos (recomendado)?" "Permisos SSH"; then
                chmod 700 "$HOME/.ssh"; chmod 600 "$HOME/.ssh/id_rsa" 2>/dev/null; chmod 644 "$HOME/.ssh/id_rsa.pub" 2>/dev/null
                chmod 644 "$HOME/.ssh/known_hosts" 2>/dev/null; chmod 600 "$HOME/.ssh/config" 2>/dev/null
                show_info "Permisos básicos de ~/.ssh ajustados." "Permisos SSH"
            fi
        fi
    else
        show_warning "Extracción del backup omitida por el usuario." "Extracción Omitida"
    fi
fi
echo 

# --- PASO 2: Configuración de Herramientas ---
show_info "A continuación, configuraremos algunas herramientas esenciales." "Configuración de Herramientas"

# VS Code Sync
show_text_info "Recordatorio para Visual Studio Code:\n\n1. Abre VS Code.\n2. Inicia sesión con tu cuenta de GitHub o Microsoft.\n3. Esto debería sincronizar tus extensiones, configuraciones, temas y atajos." "VS Code Sync"
if ask_yes_no "¿Quieres intentar abrir VS Code ahora? (Debe estar instalado)"; then
    if check_command_installed "code"; then code & else show_error "Comando 'code' no encontrado. Por favor, instala VS Code." "Error VS Code"; fi
fi

# Rancher Login
if ask_yes_no "¿Deseas configurar el acceso a Rancher (ra.adhoc.ar)?" "Configurar Rancher"; then
    if install_package_interactive "rancher" "rancher-cli" "Rancher CLI"; then
        rancher_token=$(get_password_input "Obtén tu Bearer Token desde https://ra.adhoc.ar (API & Keys -> Crear Token) y pégalo aquí:" "Token de Rancher")
        if [ -n "$rancher_token" ]; then
            if rancher login https://ra.adhoc.ar/v3 --token "$rancher_token" --skip-verify; then 
                show_info "Login a Rancher exitoso." "Rancher Login"
                RANCHER_CONTEXT_NAME="adhocprod"
                if ask_yes_no "Login exitoso.\n¿Deseas seleccionar el contexto/cluster '$RANCHER_CONTEXT_NAME' en Rancher?" "Rancher Context"; then
                    if rancher context switch "$RANCHER_CONTEXT_NAME"; then show_info "Contexto '$RANCHER_CONTEXT_NAME' seleccionado." "Rancher";
                    else show_error "No se pudo seleccionar el contexto '$RANCHER_CONTEXT_NAME'.\nIntenta manualmente con 'rancher context switch <nombre>'." "Error Rancher Context"; fi
                fi
            else show_error "Error durante el login a Rancher. Verifica el token y la URL." "Error Rancher Login"; fi
        else show_warning "Token de Rancher no proporcionado. Omitiendo login." "Rancher Login Omitido"; fi
    fi
fi

# Docker Login
if ask_yes_no "¿Deseas configurar el login a Docker Hub para el usuario 'adhocsa'?" "Configurar Docker"; then
    if install_package_interactive "docker" "docker.io" "Docker"; then
        docker_user_pat_info="El nombre de usuario general para la organización es: adhocsa\n
                \n
                \nDocker te pedirá el 'Password' interactivamente en la terminal; allí debes pegar TU token PAT personal."
        show_text_info "$docker_user_pat_info" "Información Docker PAT"
        
        if [ "$USE_ZENITY" = true ] && [ -n "$TERMINAL" ]; then
            show_info "Se abrirá una nueva terminal para el login de Docker." "Docker Login"
            $TERMINAL -e "bash -c 'echo \"Iniciando login de Docker para adhocsa...\"; docker login -u adhocsa; echo \"Presiona Enter para cerrar esta terminal.\"; read'"
        elif [ "$USE_ZENITY" = true ]; then
             show_warning "No se pudo determinar tu emulador de terminal. Por favor, abre una terminal manualmente y ejecuta:\n\ndocker login -u adhocsa" "Acción Manual Requerida"
        else 
            echo -e "${BLUE}Iniciando login de Docker para adhocsa...${NC}"
            if docker login -u adhocsa; then show_info "Login a Docker Hub para 'adhocsa' exitoso." "Docker Login"
            else show_error "Error durante el login a Docker." "Error Docker Login"; fi
        fi
    fi
fi

# Clonar team-tools
TEAM_TOOLS_REPO="git@github.com:ingadhoc/team-tools.git"; TEAM_TOOLS_PATH="$HOME/repositorios/team-tools"
if ask_yes_no "¿Deseas clonar/actualizar el repositorio 'ingadhoc/team-tools'\n(en '$TEAM_TOOLS_PATH')?" "Repositorio team-tools"; then
    if install_package_interactive "git" "git" "Git"; then
        if [ -d "$TEAM_TOOLS_PATH/.git" ]; then
            if ask_yes_no "El directorio $TEAM_TOOLS_PATH ya existe.\n¿Intentar actualizarlo con 'git pull'?" "Actualizar team-tools"; then
                (cd "$TEAM_TOOLS_PATH" && git pull) | zenity --progress --title="Actualizando team-tools" --text="Ejecutando git pull..." --pulsate --auto-close --auto-kill 2>/dev/null
                show_info "Comando 'git pull' ejecutado para team-tools." "team-tools"
            fi
        else
            mkdir -p "$(dirname "$TEAM_TOOLS_PATH")"
            (git clone "$TEAM_TOOLS_REPO" "$TEAM_TOOLS_PATH") | zenity --progress --title="Clonando team-tools" --text="Clonando repositorio..." --pulsate --auto-close --auto-kill 2>/dev/null
            if [ -d "$TEAM_TOOLS_PATH/.git" ]; then
                show_info "Repositorio team-tools clonado exitosamente en $TEAM_TOOLS_PATH.\n\nConsidera agregar '$TEAM_TOOLS_PATH/bin' (o similar) a tu \$PATH." "team-tools Clonado"
            else
                show_error "Error al clonar team-tools.\nVerifica tu clave SSH con GitHub (ssh -T git@github.com)." "Error Git Clone"
            fi
        fi
    fi
fi

# Odoo Initial Setup
if ask_yes_no "¿Necesitas ejecutar el script 'initial_setup.sh' para alguna instancia de Odoo?" "Setup de Odoo"; then
    odoo_instance_path_gui=$(select_directory "Selecciona la carpeta de tu instancia de Odoo (ej: ~/odoo/16.0)")
    if [ $? -eq 0 ] && [ -n "$odoo_instance_path_gui" ]; then
        odoo_instance_path_expanded="${odoo_instance_path_gui/#\~/$HOME}"
        initial_setup_script="$odoo_instance_path_expanded/scripts/initial_setup.sh"
        if [ -f "$initial_setup_script" ]; then
            if ask_yes_no "Se encontró: $initial_setup_script\n¿Ejecutar este script ahora?" "Confirmar Setup Odoo"; then
                 if [ "$USE_ZENITY" = true ] && [ -n "$TERMINAL" ]; then
                    show_info "Se abrirá una nueva terminal para ejecutar el setup de Odoo." "Setup Odoo"
                    $TERMINAL -e "bash -c 'cd \"$odoo_instance_path_expanded\" && echo \"Ejecutando ./scripts/initial_setup.sh en $(pwd)...\"; ./scripts/initial_setup.sh; echo; echo \"Script finalizado. Presiona Enter para cerrar esta terminal.\"; read'"
                 elif [ "$USE_ZENITY" = true ]; then
                    show_warning "No se pudo determinar tu emulador de terminal. Por favor, abre una terminal manualmente, navega a '$odoo_instance_path_expanded' y ejecuta:\n\n./scripts/initial_setup.sh" "Acción Manual Requerida"
                 else 
                    (cd "$odoo_instance_path_expanded" && ./scripts/initial_setup.sh)
                    show_info "Script initial_setup.sh ejecutado (o intentado)." "Setup Odoo"
                 fi
            fi
        else show_error "Script initial_setup.sh no encontrado en '$initial_setup_script'." "Error Setup Odoo"; fi
    else show_warning "No se seleccionó carpeta de Odoo." "Setup Odoo Omitido"; fi
fi

# --- PASO 3 ELIMINADO ---

# --- Mensajes Finales ---
final_recommendations=$(cat <<EOF
==========================================================
CONFIGURACIÓN BÁSICA ASISTIDA COMPLETADA
==========================================================
Pasos finales y recomendaciones:
1. REINICIA TU TERMINAL o ejecuta 'source ~/.bashrc' (o 'source ~/.zshrc') para aplicar cambios de shell.
2. Verifica tus herramientas: Prueba 'git', 'docker', 'rancher', acceso a Odoo, etc.
3. Configuraciones específicas de proyectos: Revisa la documentación de cada proyecto.
4. Explora las configuraciones de tu sistema Ubuntu.

¡Bienvenido/a a tu nueva notebook! Que la disfrutes.
Si tienes problemas, consulta al equipo de #sistemas-devops.
EOF
)
show_text_info "$final_recommendations" "Configuración Completada"

exit 0
