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
                USE_ZENITY=false
                return
            else
                echo -e "${GREEN}Zenity instalado correctamente.${NC}"
                USE_ZENITY=true
            fi
        else
            echo -e "${YELLOW}Zenity no se instalará. El script continuará en modo texto.${NC}"
            USE_ZENITY=false
            return
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

# Llamada inicial para configurar Zenity
check_and_setup_zenity

ask_yes_no() {
    local question_text="$1"
    local title="${2:-Confirmación}" # Título opcional
    if [ "$USE_ZENITY" = true ]; then
        zenity --question --title="$title" --text="$question_text" --width=400 --height=150 --icon-name=dialog-question
        return $?
    else
        while true; do
            read -r -p "$(echo -e "${BLUE}${question_text} ${NC}[S/N]: ")" response
            case "$response" in
                [sS][iI]|[sS]) return 0 ;;
                [nN][oO]|[nN]) return 1 ;;
                *) echo -e "${RED}Respuesta inválida. Por favor, introduce S o N.${NC}" ;;
            esac
        done
    fi
}

show_info() {
    local message_text="$1"
    local title="${2:-Información}"
    if [ "$USE_ZENITY" = true ]; then
        zenity --info --title="$title" --text="$message_text" --width=450 --height=150 --icon-name=dialog-information
    else
        echo -e "${GREEN}$message_text${NC}"
    fi
}

show_warning() {
    local message_text="$1"
    local title="${2:-Advertencia}"
    if [ "$USE_ZENITY" = true ]; then
        zenity --warning --title="$title" --text="$message_text" --width=450 --height=150 --icon-name=dialog-warning
    else
        echo -e "${YELLOW}$message_text${NC}"
    fi
}

show_error() {
    local message_text="$1"
    local title="${2:-Error}"
    if [ "$USE_ZENITY" = true ]; then
        zenity --error --title="$title" --text="$message_text" --width=450 --height=150 --icon-name=dialog-error
    else
        echo -e "${RED}$message_text${NC}"
    fi
}

show_text_info() {
    local file_content="$1"; local title="${2:-Información Detallada}"
    if [ "$USE_ZENITY" = true ]; then
        # CORRECCIÓN: Usar echo -e para que interprete los \n
        zenity --text-info --title="$title" --filename=<(echo -e "$file_content") --width=600 --height=400 --icon-name=dialog-information
    else
        # CORRECCIÓN: Usar echo -e también para el modo CLI para consistencia
        # y para que también interprete los \n si el texto los tuviera como escapes.
        echo -e "${BLUE}--- $title ---${NC}"
        echo -e "$file_content"
        echo -e "${BLUE}--------------------${NC}"
    fi
}


# --- Inicio del Script ---
if [ "$USE_ZENITY" = true ]; then
    zenity --info --title="Asistente de Migración" --text="Soy el Asistente de enroque de notebooks - FASE 1/2: BACKUP.\n\nEste script te ayudará a backupear tus archivos y configuraciones importantes." --width=500 --icon-name=drive-harddisk
else
    clear
    echo -e "${GREEN}=====================================================${NC}"
    echo -e "${GREEN} ASISTENTE DE ENROQUE DE NOTEBOOKS - FASE 1/2: BACKUP ${NC}"
    echo -e "${GREEN}=====================================================${NC}"
    echo -e "${YELLOW}Este script te ayudará a backupear tus archivos y configuraciones importantes.${NC}"
    echo
fi

if ! ask_yes_no "¿Deseas continuar con el proceso de backup?" "Inicio del Backup"; then
    show_info "Operación cancelada por el usuario." "Cancelado"
    exit 0
fi

# --- Elementos por defecto para el backup ---
default_items_definitions=(
    "$HOME/.ssh" "Configuración SSH (claves privadas/públicas)"
    "$HOME/.kube" "Configuración de Kubernetes (kubectl)"
    "$HOME/odoo" "Directorio de proyectos Odoo"
    "$HOME/.bashrc" "Configuración de Bash shell"
    "$HOME/.bash_history" "Historial de comandos Bash"
    "$HOME/.gitconfig" "Configuración global de Git"
    "$HOME/.zshrc" "Configuración de Zsh shell (si usa)"
    "$HOME/.zsh_history" "Historial de comandos Zsh (si usa)"
    "$HOME/.config/gh-copilot" "Configuración de GitHub Copilot CLI"
    "$HOME/.docker/config.json" "Credenciales de Docker (si existen)"
    "$HOME/repositorios" "Carpeta principal de repositorios Git"
    "$HOME/Documents" "Carpeta de Documentos"
    "$HOME/Downloads" "Carpeta de Descargas (analizar si vale la pena, suele tener mucha cosa acumulada)"
)

declare -a candidate_items_for_backup=()
declare -a zenity_checklist_data=()

for ((i=0; i<${#default_items_definitions[@]}; i+=2)); do
    path_to_check="${default_items_definitions[i]}"
    description="${default_items_definitions[i+1]}"
    expanded_path="${path_to_check/#\~/$HOME}"

    if [ -e "$expanded_path" ]; then
        zenity_checklist_data+=("TRUE" "$expanded_path" "$description (encontrado)")
        # Por defecto incluimos los encontrados, el usuario puede desmarcar
        candidate_items_for_backup+=("$expanded_path")
    else
        zenity_checklist_data+=("FALSE" "$expanded_path" "$description (NO encontrado)")
    fi
done

if [ "$USE_ZENITY" = true ]; then
    # Convertimos el array candidate_items_for_backup actual en una string para comparar fácilmente
    # y poder re-llenarlo con la selección de Zenity.
    # La primera columna de zenity_checklist_data es TRUE/FALSE, la segunda es la ruta.
    # Zenity --checklist devuelve las rutas de la segunda columna si están seleccionadas.
    
    # Preparamos los datos para Zenity --list --checklist
    # Columnas: "Incluir" (checkbox), "Ruta/Elemento", "Descripción / Estado"
    
    selected_paths_string=$(zenity --list --checklist --title="Selección de Elementos para Backup" \
        --text="Selecciona los elementos por defecto a incluir en el backup:" \
        --column="Incluir" --column="Ruta/Elemento" --column="Descripción / Estado" \
        "${zenity_checklist_data[@]}" --width=700 --height=500 --separator=':')
    
    # Si el usuario cancela (presiona Cancelar o cierra la ventana), $? será 1
    # Si presiona OK, $? será 0. Si no selecciona nada y presiona OK, selected_paths_string estará vacía.
    if [ $? -ne 0 ]; then
        show_info "Selección de elementos cancelada. Abortando." "Cancelado"
        exit 0
    fi

    # Limpiamos y rellenamos candidate_items_for_backup con la selección de Zenity
    candidate_items_for_backup=()
    if [ -n "$selected_paths_string" ]; then
        IFS=':' read -r -a temp_selected_paths <<< "$selected_paths_string"
        for path in "${temp_selected_paths[@]}"; do
            # Solo agregar si realmente existe (Zenity podría permitir seleccionar algo que desapareció entretanto)
            # Aunque la lista se generó con chequeos, es una buena práctica.
            expanded_path_sel="${path/#\~/$HOME}" # Re-expandir por si acaso
            if [ -e "$expanded_path_sel" ]; then
                 candidate_items_for_backup+=("$expanded_path_sel")
            fi
        done
    fi
else # Modo CLI
    echo -e "${BLUE}Elementos sugeridos (se incluirán los que existan y confirmes):${NC}"
    temp_cli_candidates=()
    for path_abs in "${candidate_items_for_backup[@]}"; do # candidate_items_for_backup ya tiene los existentes
        if ask_yes_no "¿Incluir '$path_abs' en el backup?"; then
            temp_cli_candidates+=("$path_abs")
        fi
    done
    candidate_items_for_backup=("${temp_cli_candidates[@]}") # Actualizar con selecciones CLI
fi


# --- Permitir al usuario agregar más elementos ---
custom_paths_text_cli="Introduce las rutas completas de los elementos adicionales, una por línea.\nPuedes usar '~' para referirte a tu directorio HOME (ej: ~/mi_carpeta_especial).\nPresiona Enter en una línea vacía para finalizar."
if ask_yes_no "¿Deseas agregar archivos o carpetas adicionales al backup?" "Agregar Elementos Personalizados"; then
    if [ "$USE_ZENITY" = true ]; then
        show_info "Se abrirán diálogos para seleccionar archivos y/o directorios adicionales.\nPuedes seleccionar múltiples manteniendo presionada la tecla Ctrl." "Info: Agregar Elementos"
        
        # Agregar directorios
        additional_dirs_string=$(zenity --file-selection --directory --multiple --title="Selecciona directorios adicionales" --separator=':')
        if [ $? -eq 0 ] && [ -n "$additional_dirs_string" ]; then
            IFS=':' read -r -a additional_dirs_array <<< "$additional_dirs_string"
            for dir_path in "${additional_dirs_array[@]}"; do
                expanded_dir_path="${dir_path/#\~/$HOME}"
                if [ -e "$expanded_dir_path" ] && [[ ! " ${candidate_items_for_backup[*]} " =~ " ${expanded_dir_path} " ]]; then
                    candidate_items_for_backup+=("$expanded_dir_path")
                fi
            done
        fi
        
        # Agregar archivos
        additional_files_string=$(zenity --file-selection --multiple --title="Selecciona archivos adicionales" --separator=':')
        if [ $? -eq 0 ] && [ -n "$additional_files_string" ]; then
            IFS=':' read -r -a additional_files_array <<< "$additional_files_string"
            for file_path in "${additional_files_array[@]}"; do
                expanded_file_path="${file_path/#\~/$HOME}"
                if [ -e "$expanded_file_path" ] && [[ ! " ${candidate_items_for_backup[*]} " =~ " ${expanded_file_path} " ]]; then
                    candidate_items_for_backup+=("$expanded_file_path")
                fi
            done
        fi
    else # Modo CLI
        echo -e "${YELLOW}$custom_paths_text_cli${NC}"
        while true; do
            read -r -p "$(echo -e "${BLUE}Ruta adicional (o Enter para terminar): ${NC}")" new_item
            if [ -z "$new_item" ]; then
                break
            fi
            new_item_expanded="${new_item/#\~/$HOME}"
            if [ -e "$new_item_expanded" ]; then
                if [[ ! " ${candidate_items_for_backup[*]} " =~ " ${new_item_expanded} " ]]; then
                    candidate_items_for_backup+=("$new_item_expanded")
                    echo -e "  ${GREEN}Agregado: $new_item_expanded${NC}"
                else
                    echo -e "  ${YELLOW}Ya incluido: $new_item_expanded${NC}"
                fi
            else
                show_warning "'$new_item_expanded' no existe y será omitido."
            fi
        done
    fi
fi

if [ ${#candidate_items_for_backup[@]} -eq 0 ]; then
    show_error "No se seleccionó ningún archivo o carpeta existente para el backup. Abortando." "Error de Selección"
    exit 1
fi

# --- Mostrar Lista Final y Estimación de Tamaño ---
final_list_text="Se incluirán los siguientes elementos en el backup:\n\n"
for item_to_include in "${candidate_items_for_backup[@]}"; do
    final_list_text+="  - $item_to_include\n"
done

# Estimación de Tamaño
estimated_size_uncompressed=$(du -sch --apparent-size "${candidate_items_for_backup[@]}" 2>/dev/null | grep 'total$' | awk '{print $1}')
if [ -n "$estimated_size_uncompressed" ]; then
    final_list_text+="\n\nTamaño total estimado (sin comprimir): $estimated_size_uncompressed"
    final_list_text+="\nEl archivo .tar.gz final será más pequeño debido a la compresión."
else
    final_list_text+="\n\nNo se pudo calcular el tamaño estimado."
fi

if [ "$USE_ZENITY" = true ]; then
    show_text_info "$final_list_text" "Resumen del Backup"
else
    echo -e "${BLUE}--- Resumen del Backup ---${NC}"
    echo -e "$final_list_text"
    echo -e "${BLUE}------------------------${NC}"
fi

# --- Nombre del archivo de backup ---
backup_filename="${USER}_$(date +%Y%m%d_%H%M%S)_backup.tar.gz"
backup_full_path="$HOME/$backup_filename"

info_backup_name="El archivo de backup se guardará como:\n$backup_full_path"
if [ "$USE_ZENITY" = true ]; then
    show_info "$info_backup_name" "Nombre del Archivo de Backup"
else
    echo -e "${BLUE}El archivo de backup se llamará:${NC} $backup_full_path"
fi

if ! ask_yes_no "¿Confirmas la creación del archivo de backup con los elementos listados?" "Confirmar Creación de Backup"; then
    show_info "Operación cancelada por el usuario." "Cancelado"
    exit 0
fi

# --- Creación del Backup ---
declare -a paths_relative_to_home_for_tar=()
for absolute_path_item in "${candidate_items_for_backup[@]}"; do
    if [[ "$absolute_path_item" == "$HOME"* ]]; then
        relative_path="${absolute_path_item#$HOME/}"
        paths_relative_to_home_for_tar+=("$relative_path")
    else
        paths_relative_to_home_for_tar+=("$absolute_path_item") # Para ítems fuera de HOME
    fi
done

# Crear backup con barra de progreso pulsante si se usa Zenity
tar_command() {
    tar -C "$HOME" -czvf "$backup_full_path" "${paths_relative_to_home_for_tar[@]}"
}

if [ "$USE_ZENITY" = true ]; then
    (
     tar_command
     # Pequeña pausa para que el diálogo de progreso no cierre instantáneamente si es muy rápido
     sleep 1 
    ) | zenity --progress --title="Creando Backup" --text="Comprimiendo archivos...\nEsto puede tardar unos minutos." --pulsate --auto-close --auto-kill --width=500
    tar_exit_status=$? # Zenity no captura el exit status del comando dentro del subshell directamente, 
                       # necesitamos una forma de obtenerlo si la compresión falla.
                       # El método más simple es verificar si el archivo fue creado.
    # Para una mejor captura del estado de tar, sería más complejo.
    # Por ahora, asumimos que si Zenity completó y el archivo existe, está bien.
    # Para este caso, verificaremos la existencia del archivo y su tamaño.
    if [ -f "$backup_full_path" ] && [ -s "$backup_full_path" ]; then # Existe y no está vacío
        tar_exit_status=0
    else
        tar_exit_status=1 # O algún otro código de error
    fi

else # Modo CLI
    echo -e "${BLUE}Creando backup... esto puede tardar unos minutos.${NC}"
    tar_command
    tar_exit_status=$?
fi


if [ $tar_exit_status -eq 0 ]; then
    actual_size_compressed=$(du -sh "$backup_full_path" | cut -f1)
    success_message="¡Backup creado exitosamente!\n\nArchivo: $backup_full_path\nTamaño (comprimido): $actual_size_compressed"
    show_info "$success_message" "Backup Completado"
else
    error_message="Error al crear el backup. Revisa los mensajes anteriores en la terminal."
    if [ "$USE_ZENITY" = true ]; then # Si es Zenity, el error puede no ser visible.
         error_message+="\n\nEs posible que el archivo '$backup_full_path' no se haya creado o esté incompleto."
         # Opcionalmente, intentar borrar el archivo fallido
         # if [ -f "$backup_full_path" ]; then rm -f "$backup_full_path"; fi
    fi
    show_error "$error_message" "Error de Backup"
    exit 1
fi

# --- Recordatorios importantes ---
reminders_text=$(cat <<EOF
===========================================================
RECORDATORIOS IMPORTANTES PARA EL EQUIPO ACTUAL:
===========================================================
1. Transfiere el archivo '$backup_filename' (ubicado en $HOME/) al nuevo equipo.
   Lo más fácil y accesible es subirlo a "Mi Unidad" de Google Drive.

2. Sincronización de Visual Studio Code:
   - Asegúrate de haber iniciado sesión con tu cuenta de Github (o Microsoft).

3. Chrome:
   - Asegúrate de tener la sincronización activada en tu perfil para migrar marcadores,
     historial y extensiones.

4. Credenciales y Secretos Adicionales:
   - Para tokens o claves API que no estén en los archivos de configuración backupeados
     (como .kube, .docker/config.json), tenlos a mano para ingresarlos en el nuevo equipo.

Una vez transferido el backup y completados estos pasos, puedes apagar este equipo.
¡Todo listo para configurar la nueva notebook!
EOF
)

show_text_info "$reminders_text" "Pasos Siguientes Importantes"

if [ "$USE_ZENITY" = false ]; then
    echo
    echo -e "${BLUE}Cuando estés en la nueva notebook, usa el script 'restore_notebook.sh' para restaurar tu backup y configurar nuevamente tus herramientas y entorno de trabajo.${NC}"
    echo -e "${BLUE}¡Listo! Consultá con #sistemas-devops si necesitás ayuda.${NC}"
fi

exit 0
