#!/bin/bash
# Script para gestionar swap en Debian/Ubuntu.
# Script v2.2 - Añadida la opción de permitir múltiples swaps.
# Script v3.0: Opción para redimensionar automáticamente /swapfile si es más pequeño. 

# --- Configuración ---
SWAP_SIZE="16G"

# Poner en 'true' para permitir que el script reemplace /swapfile si es más pequeño.
# ¡ADVERTENCIA! Esto desactivará y eliminará el swap existente temporalmente.
RESIZE_IF_SMALLER=true

# Poner en 'true' para crear /swapfile aunque ya exista otro tipo de swap (ej. una partición).
ALLOW_MULTIPLE_SWAP=true

# --- Opciones de Seguridad ---
set -e

# --- Funciones Auxiliares (sin cambios) ---
check_dependencies() {
  local missing_cmds=(); for cmd in swapon mkswap fallocate df free awk grep id rm; do if ! command -v "$cmd" &> /dev/null; then missing_cmds+=("$cmd"); fi; done
  if [ ${#missing_cmds[@]} -ne 0 ]; then echo "❌ Error: Faltan comandos: ${missing_cmds[*]}"; exit 1; fi
}
convert_to_bytes() {
  local size_str=$1; local size_val=$(echo "$size_str" | grep -o '[0-9]*'); local size_unit=$(echo "$size_str" | grep -o '[A-Za-z]' | tr '[:lower:]' '[:upper:]')
  case "$size_unit" in G) echo $((size_val*1024*1024*1024));; M) echo $((size_val*1024*1024));; K) echo $((size_val*1024));; *) echo "$size_val";; esac
}

# --- Verificaciones Previas ---
if [ "$(id -u)" -ne 0 ]; then echo "❌ Error: Ejecutar con sudo. Ejemplo: sudo bash $0"; exit 1; fi
check_dependencies

echo "🔍 Verificando la configuración de swap existente..."
SWAP_INFO=$(swapon --show --noheadings --bytes)

# --- Lógica Principal de Swap ---
if [ -z "$SWAP_INFO" ]; then
  # CASO 1: No hay ningún swap. Proceder a crear.
  echo "👍 No se encontró swap activo. Se procederá a crear /swapfile."
else
  # CASO 2: Ya existe swap.
  if echo "$SWAP_INFO" | grep -q '/swapfile'; then
    # CASO 2a: El swap existente es /swapfile.
    CURRENT_SIZE_BYTES=$(echo "$SWAP_INFO" | grep '/swapfile' | awk '{print $3}')
    REQUIRED_SIZE_BYTES=$(convert_to_bytes "$SWAP_SIZE")

    if [ "$CURRENT_SIZE_BYTES" -lt "$REQUIRED_SIZE_BYTES" ]; then
      # Es más pequeño que el deseado.
      if [ "$RESIZE_IF_SMALLER" = true ]; then
        echo "⚠️  Advertencia: /swapfile existente es más pequeño de lo deseado."
        echo "   -> Procediendo a reemplazarlo automáticamente (RESIZE_IF_SMALLER=true)."
        
        # Comprobación de seguridad: ¿hay espacio para la diferencia?
        AVAILABLE_KB=$(df -k / | awk 'NR==2 {print $4}'); AVAILABLE_BYTES=$((AVAILABLE_KB * 1024))
        NEEDED_BYTES=$((REQUIRED_SIZE_BYTES - CURRENT_SIZE_BYTES))
        if [ "$AVAILABLE_BYTES" -lt "$NEEDED_BYTES" ]; then
            echo "❌ Error: No hay suficiente espacio en disco para ampliar el swap."
            echo "   Espacio adicional requerido: $(($NEEDED_BYTES / 1024 / 1024)) MB."
            exit 1
        fi
        
        echo "   -> Desactivando y eliminando el swap actual..."
        swapoff /swapfile
        rm /swapfile
        
        echo "   -> Creando el nuevo archivo swap de ${SWAP_SIZE}..."
        fallocate -l "$SWAP_SIZE" /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        
        echo "✅ ¡Swap redimensionado y activado con éxito!"
        exit 0 # El trabajo está hecho.
      else
        echo "✅ Info: El archivo /swapfile existe pero es más pequeño que el deseado (${SWAP_SIZE})."
        echo "   -> Para redimensionarlo automáticamente, edita el script y pon RESIZE_IF_SMALLER=true."
        exit 0
      fi
    else
      echo "✅ Info: El archivo /swapfile existente ya cumple o supera el tamaño deseado (${SWAP_SIZE})."
      exit 0
    fi
  else
    # CASO 2b: Existe otro tipo de swap (partición, etc.)
    if [ "$ALLOW_MULTIPLE_SWAP" = false ]; then
      echo "✅ Info: Ya existe otra configuración de swap activa."
      swapon --show
      echo "   -> El script está configurado para no añadir otro swap (ALLOW_MULTIPLE_SWAP=false)."
      exit 0
    else
      echo "⚠️  Advertencia: Se creará /swapfile además del swap ya existente (ALLOW_MULTIPLE_SWAP=true)."
      # Continuar fuera de este bloque if...
    fi
  fi
fi

# --- Creación de Swap (solo se ejecuta si no había swap, o si ALLOW_MULTIPLE_SWAP=true) ---
echo "🔍 Verificando espacio en disco para un archivo de ${SWAP_SIZE}..."
REQUIRED_BYTES=$(convert_to_bytes "$SWAP_SIZE"); AVAILABLE_KB=$(df -k / | awk 'NR==2 {print $4}'); AVAILABLE_BYTES=$((AVAILABLE_KB * 1024))
if [ "$AVAILABLE_BYTES" -lt "$REQUIRED_BYTES" ]; then echo "❌ Error: No hay suficiente espacio en disco."; exit 1; fi
echo "👍 Espacio en disco suficiente."

echo "🔄 Creando archivo swap de ${SWAP_SIZE} en /swapfile..."
fallocate -l "$SWAP_SIZE" /swapfile; chmod 600 /swapfile; mkswap /swapfile; swapon /swapfile

echo "💾 Haciendo el cambio permanente en /etc/fstab...";
# No necesitamos respaldar fstab si solo estamos creando, ya que la lógica de reemplazo no lo toca.
# Además, si ya existía, la línea ya debería estar ahí.
if ! grep -qw '/swapfile' /etc/fstab; then
  echo "   -> Añadiendo entrada a /etc/fstab."
  cp /etc/fstab "/etc/fstab.bak.$(date +%F_%T)" # Respaldar solo si vamos a modificar
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "🎉 ¡El nuevo archivo swap se ha creado y activado correctamente!"
echo "--- Verificación Final ---"; swapon --show; echo ""; free -h; echo "--------------------------"
exit 0
