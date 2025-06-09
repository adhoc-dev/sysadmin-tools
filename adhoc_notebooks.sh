#!/bin/bash

# ==============================================================================
#
# Notebook Manager - Asistente Unificado de Backup y Restauración
#
# Combina las funcionalidades de backup y restauración en un solo script,
# con diálogos gráficos (si Zenity está disponible) o un fallback a CLI.
#
# Refactorizado para no ejecutar comandos de configuración directamente,
# sino para ofrecerlos al usuario para que los copie y pegue.
#
# ==============================================================================

# --- Configuración de Colores (para fallback a CLI) ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Variable Global para Zenity ---
USE_ZENITY=false

# --- Funciones Auxiliares de Diálogo ---

# Verifica si Zenity está disponible y si hay un entorno gráfico
check_and_setup_zenity() {
    if ! command -v zenity &> /dev/null; then
        echo -e "${YELLOW}Zenity (para diálogos gráficos) no está instalado.${NC}"
        read -r -p "$(echo -e "${BLUE}¿Deseas intentar instalarlo ahora? [S/N]: ${NC}")" response
        if [[ "$response" =~ ^[sS]$ ]]; then
            # Pide contraseña aquí para instalar
            sudo apt update && sudo apt install -y zenity
            if command -v zenity &> /dev/null; then
                echo -e "${GREEN}Zenity instalado correctamente.${NC}"
                USE_ZENITY=true
            else
                echo -e "${RED}No se pudo instalar Zenity. El script continuará en modo texto.${NC}"
                USE_ZENITY=false
            fi
        else
            USE_ZENITY=false
        fi
    else
        USE_ZENITY=true
    fi

    if [ "$USE_ZENITY" = true ] && [ -z "$DISPLAY" ]; then
        echo -e "${YELLOW}No se detectó un entorno gráfico (DISPLAY no configurado). Cambiando a modo texto.${NC}"
        USE_ZENITY=false
    fi
}

# Funciones de diálogo genéricas (usan Zenity si está disponible)
ask_yes_no() {
    local question_text="$1"; local title="${2:-Confirmación}"
    if [ "$USE_ZENITY" = true ]; then zenity --question --title="$title" --text="$question_text" --width=400 --height=150; return $?; else
        while true; do read -r -p "$(echo -e "${BLUE}${question_text} ${NC}[S/N]: ")" r; case "$r" in [sS]) return 0;; [nN]) return 1;; *) echo "Inválido.";; esac; done; fi
}
show_info() {
    if [ "$USE_ZENITY" = true ]; then zenity --info --title="${2:-Información}" --text="$1" --width=450; else echo -e "${GREEN}$1${NC}"; fi
}
show_warning() {
    if [ "$USE_ZENITY" = true ]; then zenity --warning --title="${2:-Advertencia}" --text="$1" --width=450; else echo -e "${YELLOW}$1${NC}"; fi
}
show_error() {
    if [ "$USE_ZENITY" = true ]; then zenity --error --title="${2:-Error}" --text="$1" --width=450; else echo -e "${RED}$1${NC}"; fi
}
show_text_info() {
    local content="$1"; local title="${2:-Información Detallada}"
    if [ "$USE_ZENITY" = true ]; then zenity --text-info --title="$title" --filename=<(echo -e "$content") --width=600 --height=400; else
        echo -e "${BLUE}--- $title ---${NC}\n$content\n${BLUE}--------------------${NC}"; fi
}
select_file() {
    if [ "$USE_ZENITY" = true ]; then zenity --file-selection --title="$1" --file-filter="$2 | $3"; else
        read -r -p "$(echo -e "${BLUE}Ruta al archivo ($1): ${NC}")" p; echo "$p"; fi
}
select_directory() {
    if [ "$USE_ZENITY" = true ]; then zenity --file-selection --directory --title="$1"; else
        read -r -p "$(echo -e "${BLUE}Ruta al directorio ($1): ${NC}")" p; echo "$p"; fi
}
prompt_to_run_command() {
    local description="$1"; local command_to_run="$2"
    local message="Acción manual requerida:\n\n$description\n\nPor favor, copia el siguiente comando y ejecútalo en una terminal:"
    
    if [ "$USE_ZENITY" = true ]; then
        zenity --text-info --title="Comando para Ejecutar" \
               --text="$message" \
               --filename=<(echo "$command_to_run") --width=600 --height=300 --font="Monospace"
    else
        echo -e "${YELLOW}--- Acción Manual Requerida ---${NC}"
        echo -e "${YELLOW}$message${NC}"
        echo -e "${GREEN}\n$command_to_run\n${NC}"
        read -r -p "Presiona Enter cuando hayas ejecutado el comando para continuar..."
    fi
}

# --- Lógica de Backup ---
run_backup_logic() {
    if ! ask_yes_no "¿Deseas iniciar el proceso para crear un archivo de backup?" "Fase 1: Backup"; then
        show_info "Operación cancelada." "Cancelado"; exit 0
    fi
    
    local default_items_definitions=(
        "$HOME/.ssh" "Configuración SSH (claves)"
        "$HOME/odoo" "Directorio de proyectos Odoo"
        "$HOME/repositorios" "Carpeta principal de repositorios Git"
        "$HOME/.gitconfig" "Configuración global de Git"
        "$HOME/.bashrc" "Configuración de Bash"
        "$HOME/.zshrc" "Configuración de Zsh (si existe)"
        "$HOME/.bash_history" "Historial de Bash"
        "$HOME/.zsh_history" "Historial de Zsh (si existe)"
        "$HOME/Documents" "Carpeta de Documentos"
        "$HOME/Downloads" "Carpeta de Descargas (puede ser grande)"
    )

    declare -a items_to_backup=()
    declare -a zenity_checklist_data=()
    for ((i=0; i<${#default_items_definitions[@]}; i+=2)); do
        # --- CAMBIO REALIZADO AQUÍ ---
        # Simplificado: La variable $path ya contiene la ruta absoluta correcta
        # expandida desde $HOME, no es necesaria más manipulación.
        path="${default_items_definitions[i]}"; desc="${default_items_definitions[i+1]}"
        if [ -e "$path" ]; then
            zenity_checklist_data+=("TRUE" "$path" "$desc")
        else
            zenity_checklist_data+=("FALSE" "$path" "$desc (no encontrado)")
        fi
    done
    
    if [ "$USE_ZENITY" = true ]; then
        selected_paths_string=$(zenity --list --checklist --title="Selección para Backup" \
            --text="Selecciona los elementos a incluir:" \
            --column="Incluir" --column="Ruta" --column="Descripción" \
            "${zenity_checklist_data[@]}" --width=700 --height=500 --separator=':')
        if [ $? -ne 0 ]; then show_info "Selección cancelada." "Cancelado"; exit 0; fi
        if [ -n "$selected_paths_string" ]; then IFS=':' read -r -a items_to_backup <<< "$selected_paths_string"; fi
    else
        echo -e "${BLUE}Confirma los elementos a incluir en el backup:${NC}"
        for ((i=0; i<${#zenity_checklist_data[@]}; i+=3)); do
            if [ "${zenity_checklist_data[i]}" == "TRUE" ]; then
                if ask_yes_no "¿Incluir '${zenity_checklist_data[i+1]}'?"; then
                    items_to_backup+=("${zenity_checklist_data[i+1]}")
                fi
            fi
        done
    fi

    if ask_yes_no "¿Deseas agregar más archivos o carpetas al backup?" "Añadir Elementos"; then
        show_info "Se abrirán diálogos para que selecciones directorios y luego archivos adicionales." "Info"
        while true; do
            dir_path=$(select_directory "Selecciona un directorio adicional (o cancela para pasar a archivos)")
            if [ -z "$dir_path" ]; then break; fi
            if [[ ! " ${items_to_backup[*]} " =~ " ${dir_path} " ]]; then items_to_backup+=("$dir_path"); fi
        done
        while true; do
            file_path=$(select_file "Selecciona un archivo adicional (o cancela para finalizar)")
            if [ -z "$file_path" ]; then break; fi
            if [[ ! " ${items_to_backup[*]} " =~ " ${file_path} " ]]; then items_to_backup+=("$file_path"); fi
        done
    fi

    if [ ${#items_to_backup[@]} -eq 0 ]; then show_error "No se seleccionó ningún elemento. Abortando." "Error"; exit 1; fi

    local final_list="Se incluirán los siguientes elementos:\n\n"
    for item in "${items_to_backup[@]}"; do final_list+="  - $item\n"; done
    local estimated_size=$(du -sch "${items_to_backup[@]}" 2>/dev/null | grep 'total$' | awk '{print $1}')
    final_list+="\n\nTamaño total estimado (sin comprimir): ${estimated_size:-No calculado}"
    show_text_info "$final_list" "Resumen del Backup"

    local backup_filename="${USER}_$(date +%Y%m%d_%H%M%S)_backup.tar.gz"
    local backup_full_path="$HOME/$backup_filename"

    if ! ask_yes_no "El backup se guardará como:\n$backup_full_path\n\n¿Confirmas la creación?" "Confirmar Backup"; then
        show_info "Operación cancelada." "Cancelado"; exit 0
    fi
    
    (tar -czvf "$backup_full_path" -C "$HOME" "${items_to_backup[@]/#/$HOME/}" 2>&1) | \
    (if [ "$USE_ZENITY" = true ]; then zenity --progress --title="Creando Backup" --text="Comprimiendo archivos..." --pulsate --auto-close --auto-kill; else cat; fi)

    if [ -s "$backup_full_path" ]; then
        local compressed_size=$(du -sh "$backup_full_path" | cut -f1)
        show_info "¡Backup creado exitosamente!\n\nArchivo: $backup_full_path\nTamaño: $compressed_size" "Backup Completado"
        local reminders_text="RECORDATORIOS IMPORTANTES:\n\n1. Transfiere '$backup_filename' a tu nuevo equipo (ej. vía Google Drive).\n\n2. Asegúrate de tener la sincronización activada en Chrome y VS Code.\n\n3. Ten a mano cualquier credencial que no esté en archivos de configuración."
        show_text_info "$reminders_text" "Pasos Siguientes"
    else
        show_error "Error al crear el backup. El archivo no se creó o está vacío." "Error de Backup"
    fi
}

# --- Lógica de Restauración ---
run_restore_logic() {
    if ! ask_yes_no "¿Deseas iniciar el proceso para restaurar desde un backup y configurar herramientas?" "Fase 2: Restauración"; then
        show_info "Operación cancelada." "Cancelado"; exit 0
    fi

    # Restaurar Backup
    local backup_path=$(select_file "Selecciona tu archivo de backup (.tar.gz)" "Archivos TAR GZ" "*.tar.gz")
    if [ -z "$backup_path" ]; then
        if ! ask_yes_no "No se seleccionó backup. ¿Continuar solo con la configuración de herramientas?" "Continuar sin Backup"; then
            show_info "Operación cancelada." "Cancelado"; exit 1
        fi
    else
        if [[ ! "$backup_path" == *.tar.gz ]] || [[ ! -f "$backup_path" ]]; then
            show_error "El archivo seleccionado no es un .tar.gz válido o no existe." "Error de Archivo"; exit 1
        fi
        if ask_yes_no "Se extraerá '$backup_path' en tu HOME ($HOME).\nEsto podría SOBRESCRIBIR archivos existentes.\n\n¿Estás seguro?" "Confirmar Extracción"; then
            (tar -xzvf "$backup_path" -C "$HOME") | \
            (if [ "$USE_ZENITY" = true ]; then zenity --progress --title="Restaurando Backup" --pulsate --auto-close; else echo "Extrayendo..."; fi)
            show_info "Extracción del backup completada." "Backup Restaurado"
            
            if [ -d "$HOME/.ssh" ] && (ask_yes_no "Se detectó ~/.ssh. ¿Ajustar sus permisos (recomendado)?"); then
                chmod 700 "$HOME/.ssh"; chmod 600 "$HOME/.ssh/id_rsa" 2>/dev/null; chmod 644 "$HOME/.ssh/id_rsa.pub" 2>/dev/null
                show_info "Permisos de ~/.ssh ajustados." "Permisos SSH"
            fi
        fi
    fi

    show_info "A continuación, te guiaremos para configurar tus herramientas.\n\nSe mostrarán los comandos que debes ejecutar en tu terminal." "Configuración de Herramientas"

    # VS Code Sync
    if ask_yes_no "¿Deseas configurar Visual Studio Code?"; then
        prompt_to_run_command "Abre VS Code para que puedas iniciar sesión y sincronizar tu configuración." "code"
    fi
    
    # Docker Login
    if ask_yes_no "¿Deseas configurar el login de Docker Hub para 'adhocsa'?"; then
        if ! command -v docker &>/dev/null; then
             prompt_to_run_command "Docker no está instalado. Para instalarlo, ejecuta:" "sudo apt update && sudo apt install -y docker.io"
        fi
        show_text_info "En la terminal, se te pedirá tu 'Password'. Pega allí tu Token de Acceso Personal (PAT) de Docker Hub." "Información Docker PAT"
        prompt_to_run_command "Inicia sesión en Docker Hub con el usuario 'adhocsa'." "docker login -u adhocsa"
    fi

    # Clonar team-tools
    local TEAM_TOOLS_REPO="git@github.com:ingadhoc/team-tools.git"
    local TEAM_TOOLS_PATH="$HOME/repositorios/team-tools"
    if ask_yes_no "¿Deseas clonar o actualizar el repositorio 'team-tools'?"; then
        if ! command -v git &>/dev/null; then
             prompt_to_run_command "Git no está instalado. Para instalarlo, ejecuta:" "sudo apt update && sudo apt install -y git"
        fi
        if [ -d "$TEAM_TOOLS_PATH/.git" ]; then
            prompt_to_run_command "El repositorio ya existe. Para actualizarlo, ejecuta:" "cd \"$TEAM_TOOLS_PATH\" && git pull"
        else
            mkdir -p "$(dirname "$TEAM_TOOLS_PATH")"
            prompt_to_run_command "Para clonar el repositorio 'team-tools', ejecuta:" "git clone \"$TEAM_TOOLS_REPO\" \"$TEAM_TOOLS_PATH\""
        fi
    fi

    # Odoo Initial Setup
    if ask_yes_no "¿Necesitas ejecutar el script 'initial_setup.sh' para una instancia de Odoo?"; then
        local odoo_path=$(select_directory "Selecciona la carpeta de tu instancia de Odoo")
        if [ -n "$odoo_path" ]; then
            local setup_script="$odoo_path/scripts/initial_setup.sh"
            if [ -f "$setup_script" ]; then
                prompt_to_run_command "Para configurar tu instancia de Odoo, navega a su directorio y ejecuta el script:" "cd \"$odoo_path\" && ./scripts/initial_setup.sh"
            else
                show_error "El script 'initial_setup.sh' no se encontró en la ruta seleccionada." "Script no Encontrado"
            fi
        fi
    fi

    local final_recommendations="CONFIGURACIÓN ASISTIDA COMPLETADA\n\nRecomendaciones finales:\n1. REINICIA TU TERMINAL o ejecuta 'source ~/.bashrc' (o ~/.zshrc).\n2. Verifica que todas tus herramientas (git, docker, etc.) funcionen como esperas.\n3. Si clonaste repositorios, revisa su configuración específica.\n\n¡Bienvenido/a a tu nueva notebook!"
    show_text_info "$final_recommendations" "Finalizado"
}


# --- Script Principal ---
check_and_setup_zenity
clear

# --- CAMBIO REALIZADO AQUÍ ---
# Agregada una verificación para asegurar que el script no se ejecute como root.
if [ "$(id -u)" -eq 0 ]; then
    # Usar show_error si zenity está disponible, si no, echo a stderr.
    err_msg="Este script no debe ser ejecutado como root (o con sudo).\n\nPor favor, ejecútalo con tu usuario normal.\nEl script solicitará la contraseña solo cuando sea estrictamente necesario."
    if [ "$USE_ZENITY" = true ]; then
        zenity --error --title="Error de Ejecución" --text="$err_msg"
    else
        echo -e "${RED}$err_msg${NC}" >&2
    fi
   exit 1
fi


show_info "Bienvenido al Asistente de Migración de Notebooks." "Bienvenida"

if [ "$USE_ZENITY" = true ]; then
    choice=$(zenity --list --radiolist --title="¿Qué deseas hacer?" --text="Selecciona una opción:" \
        --column="Selección" --column="Acción" --column="Descripción" \
        TRUE "Backup" "Crear un archivo .tar.gz con tus archivos y configuraciones." \
        FALSE "Restore" "Restaurar desde un backup y configurar herramientas." \
        --width=550 --height=250)
else
    echo -e "${BLUE}Selecciona una opción:${NC}"
    echo "1. Backup (Crear un archivo de respaldo)"
    echo "2. Restore (Restaurar desde un respaldo)"
    read -r -p "Opción [1/2]: " cli_choice
    case "$cli_choice" in
        1) choice="Backup" ;;
        2) choice="Restore" ;;
    esac
fi

case "$choice" in
    "Backup")
        run_backup_logic
        ;;
    "Restore")
        run_restore_logic
        ;;
    *)
        show_info "Ninguna opción seleccionada. Saliendo." "Cancelado"
        ;;
esac

exit 0
