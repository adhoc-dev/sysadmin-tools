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
        # El -e en echo permite interpretar las secuencias de escape para colores
        read -r -p "$(echo -e "${BLUE}$1 ${NC}[S/N]: ")" response
        case "$response" in
            [sS][iI]|[sS]) return 0 ;;
            [nN][oO]|[nN]) return 1 ;;
            *) echo -e "${RED}Respuesta inválida. Por favor, introduce S o N.${NC}" ;;
        esac
    done
}

# --- Inicio del Script ---
clear
echo -e "${GREEN}=====================================================${NC}"
echo -e "${GREEN} ASISTENTE DE MIGRACIÓN DE EQUIPO - FASE 1: BACKUP ${NC}"
echo -e "${GREEN}=====================================================${NC}"
echo -e "${YELLOW}Este script te ayudará a empaquetar tus archivos y configuraciones importantes.${NC}"
echo

if ! ask_yes_no "¿Deseas continuar?"; then
    echo -e "${YELLOW}Cancelado por el usuario.${NC}"
    exit 0
fi
echo

# --- Elementos por defecto para el backup ---
# Asegúrate de que estos sean los que quieres por defecto.
# Todos deben ser rutas absolutas o empezar con ~/
default_items_definitions=(
    "$HOME/.ssh"
    "$HOME/.kube"
    "$HOME/odoo"
    "$HOME/.bashrc"
    "$HOME/.bash_history"
    "$HOME/.gitconfig"
    "$HOME/.zshrc"
    "$HOME/.zsh_history"
    "$HOME/.config/gh-copilot"
    "$HOME/.docker/config.json"
    "$HOME/repositorios" # Carpeta general de repositorios
    "$HOME/Documents"   # Nombre estándar en inglés, puede ser Documentos
    "$HOME/Downloads"    # Nombre estándar en inglés, puede ser Descargas
    # Considera añadir carpetas de proyectos comunes si tienen nombres predecibles
    # "$HOME/Proyectos"
    # "$HOME/workspaces"
)

echo -e "${BLUE}Se verificarán los siguientes elementos sugeridos para el backup:${NC}"
declare -a candidate_items_for_backup=() # Almacena rutas absolutas y expandidas que existen

for item_path_definition in "${default_items_definitions[@]}"; do
    # Expandir tilde explícitamente por si acaso (aunque $HOME ya lo hace)
    expanded_path="${item_path_definition/#\~/$HOME}"

    if [ -e "$expanded_path" ]; then
        echo -e "  - $expanded_path ${GREEN}(encontrado)${NC}"
        candidate_items_for_backup+=("$expanded_path")
    else
        echo -e "  - $expanded_path ${YELLOW}(no encontrado, se omitirá de las sugerencias automáticas)${NC}"
    fi
done
echo

# --- Permitir al usuario agregar más elementos ---
if ask_yes_no "¿Deseas agregar archivos o carpetas adicionales al backup?"; then
    echo -e "${YELLOW}Introduce las rutas completas de los elementos adicionales, una por línea."
    echo -e "Puedes usar '~' para referirte a tu directorio HOME (ej: ~/mi_carpeta_especial)."
    echo -e "Presiona Enter en una línea vacía para finalizar.${NC}"
    while true; do
        read -r -p "$(echo -e "${BLUE}Ruta adicional (o Enter para terminar): ${NC}")" new_item
        if [ -z "$new_item" ]; then
            break
        fi
        new_item_expanded="${new_item/#\~/$HOME}" # Expandir tilde
        if [ -e "$new_item_expanded" ]; then
            # Evitar duplicados si ya estaba en los defaults
            if [[ ! " ${candidate_items_for_backup[*]} " =~ " ${new_item_expanded} " ]]; then
                candidate_items_for_backup+=("$new_item_expanded")
                echo -e "  ${GREEN}Agregado: $new_item_expanded${NC}"
            else
                echo -e "  ${YELLOW}Ya incluido: $new_item_expanded${NC}"
            fi
        else
            echo -e "  ${RED}Advertencia: '$new_item_expanded' no existe y será omitido.${NC}"
        fi
    done
fi

if [ ${#candidate_items_for_backup[@]} -eq 0 ]; then
    echo -e "${RED}No se seleccionó ningún archivo o carpeta existente para el backup. Abortando.${NC}"
    exit 1
fi

echo
echo -e "${BLUE}Se incluirán los siguientes elementos en el backup:${NC}"
for item_to_include in "${candidate_items_for_backup[@]}"; do
    echo "  - $item_to_include"
done
echo

# --- Estimación de Tamaño (NUEVO) ---
echo -e "${BLUE}Calculando tamaño estimado de los archivos seleccionados (sin comprimir)...${NC}"
# Usamos --apparent-size para obtener el tamaño real de los datos.
# El -h para formato legible, -s para sumario, -c para gran total (aunque -s es suficiente con múltiples args)
# Pasamos la lista de rutas absolutas a du
estimated_size_uncompressed=$(du -sch --apparent-size "${candidate_items_for_backup[@]}" | grep 'total$' | awk '{print $1}')
if [ -n "$estimated_size_uncompressed" ]; then
    echo -e "${YELLOW}Tamaño total estimado (sin comprimir): $estimated_size_uncompressed${NC}"
    echo -e "${YELLOW}El archivo .tar.gz final será más pequeño debido a la compresión.${NC}"
else
    echo -e "${RED}No se pudo calcular el tamaño estimado.${NC}"
fi
echo

# --- Nombre del archivo de backup ---
backup_filename="${USER}_$(date +%Y%m%d_%H%M%S)_backup.tar.gz"
backup_full_path="$HOME/$backup_filename" # Guardar en el HOME del usuario

echo -e "${BLUE}El archivo de backup se llamará:${NC} $backup_full_path"
echo

if ! ask_yes_no "¿Confirmas la creación del archivo de backup con los elementos listados?"; then
    echo -e "${YELLOW}Operación cancelada por el usuario.${NC}"
    exit 0
fi

# --- Creación del Backup ---
echo -e "${BLUE}Creando backup... esto puede tardar unos minutos.${NC}"

# Preparar rutas relativas a $HOME para el comando tar
declare -a paths_relative_to_home_for_tar=()
for absolute_path_item in "${candidate_items_for_backup[@]}"; do
    if [[ "$absolute_path_item" == "$HOME"* ]]; then
        # Obtener la ruta relativa a $HOME. Ej: de /home/user/.ssh -> .ssh
        # De /home/user/docs/file.txt -> docs/file.txt
        relative_path="${absolute_path_item#$HOME/}"
        paths_relative_to_home_for_tar+=("$relative_path")
    else
        # Esto es para manejar rutas que NO están dentro de $HOME.
        # Es un caso menos común para backups de desarrollador y más complejo de restaurar.
        # tar las archivaría con la ruta completa (quitando el / inicial).
        echo -e "${YELLOW}Advertencia: '$absolute_path_item' está fuera de \$HOME. Se archivará con una ruta que podría necesitar ajuste manual al restaurar.${NC}"
        paths_relative_to_home_for_tar+=("$absolute_path_item")
    fi
done

# Usar -C "$HOME" para que las rutas en el tar sean relativas a HOME
# y se restauren correctamente en el HOME del nuevo usuario.
# Solo se pasa a -C las rutas que realmente están en HOME.
# Si hubiera rutas fuera de HOME, necesitarían un manejo diferente, pero
# para este script, nos enfocamos en las que están en HOME.

# Para simplificar y dado que la mayoría de las rutas de desarrollador están en $HOME:
# Si todos los items están en $HOME, podemos hacer un solo tar -C $HOME.
# Si hay mezcla, es más complejo. Asumimos que casi todo es de $HOME.
# Para este script, todas las `default_items_definitions` y lo que agregue el usuario
# se espera que sea manejable desde $HOME o como rutas absolutas que el usuario entiende.

# La forma más robusta si todo está en $HOME o es un subdirectorio:
tar -C "$HOME" -czvf "$backup_full_path" "${paths_relative_to_home_for_tar[@]}"
# NOTA: Si paths_relative_to_home_for_tar contiene rutas absolutas (porque no estaban en $HOME),
# el -C "$HOME" no les afectará de la manera esperada.
# Este script está optimizado para cosas DENTRO del $HOME del usuario.

if [ $? -eq 0 ]; then
    actual_size_compressed=$(du -sh "$backup_full_path" | cut -f1)
    echo -e "${GREEN}¡Backup creado exitosamente en $backup_full_path!${NC}"
    echo -e "${YELLOW}Tamaño del backup (comprimido): $actual_size_compressed${NC}"
else
    echo -e "${RED}Error al crear el backup. Revisa los mensajes anteriores.${NC}"
    # Podrías añadir un `rm -f "$backup_full_path"` aquí si quieres borrar un archivo parcial en caso de error
    exit 1
fi
echo

# --- Recordatorios importantes ---
echo -e "${YELLOW}===========================================================${NC}"
echo -e "${YELLOW} RECORDATORIOS IMPORTANTES PARA EL EQUIPO ACTUAL: ${NC}"
echo -e "${YELLOW}===========================================================${NC}"
echo -e "1. ${BLUE}Transfiere el archivo ${NC}${backup_filename}${BLUE} (ubicado en ${GREEN}$HOME/${NC})${BLUE} al nuevo equipo.${NC}"
echo -e "   Puedes usar: "
echo -e "     - ${GREEN}Google Drive${NC} (opción recomendada por Sistemas)."
echo -e "     - ${GREEN}Un pendrive USB.${NC}"
echo -e "     - ${GREEN}SCP:${NC} Si la nueva notebook está en red y conoces su IP/hostname:"
echo -e "       (Ej: ${GREEN}scp ${backup_full_path} ${USER}@IP_NUEVA_NOTEBOOK:${HOME}/${NC})"
echo
echo -e "2. ${BLUE}Sincronización de Visual Studio Code:${NC}"
echo -e "   - Abre VS Code."
echo -e "   - Asegúrate de haber iniciado sesión con tu cuenta de Github (o Microsoft)."
echo -e "   - Ve a ${GREEN}Archivo > Preferencias > Sincronización de Configuraciones${NC} (Settings Sync)"
echo -e "     y verifica que esté ${GREEN}Activada${NC} y recientemente sincronizada."
echo
echo -e "3. ${BLUE}Navegadores Web (Chrome, Firefox, etc.):${NC}"
echo -e "   - Asegúrate de tener la ${GREEN}sincronización activada${NC} en tu perfil para migrar marcadores,"
echo -e "     historial, contraseñas (si las gestionas ahí) y extensiones."
echo
echo -e "4. ${BLUE}Gestores de Contraseñas (Bitwarden, 1Password, KeePassXC, etc.):${NC}"
echo -e "   - Asegúrate de tener acceso a tu bóveda desde el nuevo equipo (credenciales maestras, archivos de bóveda si es local)."
echo -e "   - ${RED}¡EVITA ANOTAR CONTRASEÑAS EN TEXTO PLANO!${NC}"
echo
echo -e "5. ${BLUE}Credenciales y Secretos Adicionales:${NC}"
echo -e "   - Para tokens o claves API que no estén en los archivos de configuración backupeados"
echo -e "     (como .kube, .docker/config.json), tenlos a mano para ingresarlos en el nuevo equipo."
echo
echo -e "${GREEN}Una vez transferido el backup y completados estos pasos, puedes apagar este equipo.${NC}"
echo -e "${GREEN}¡Listo para configurar la nueva notebook!${NC}"

exit 0
