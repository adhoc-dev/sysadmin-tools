#!/bin/bash
# Script v2.2 - Añadida la opción de permitir múltiples swaps.

# --- Configuración ---
SWAP_SIZE="16G"
# Poner en 'true' para crear /swapfile aunque ya exista otro tipo de swap (ej. una partición).
ALLOW_MULTIPLE_SWAP=true

# --- Opciones de Seguridad ---
set -e

# --- (El resto de las funciones auxiliares no cambia) ---
check_dependencies() {
  local missing_cmds=(); for cmd in swapon mkswap fallocate df free awk grep id; do if ! command -v "$cmd" &> /dev/null; then missing_cmds+=("$cmd"); fi; done
  if [ ${#missing_cmds[@]} -ne 0 ]; then echo "❌ Error: Faltan comandos: ${missing_cmds[*]}"; exit 1; fi
}
convert_to_bytes() {
  local size_str=$1; local size_val=$(echo "$size_str" | grep -o '[0-9]*'); local size_unit=$(echo "$size_str" | grep -o '[A-Za-z]' | tr '[:lower:]' '[:upper:]')
  case "$size_unit" in G) echo $((size_val*1024*1024*1024));; M) echo $((size_val*1024*1024));; K) echo $((size_val*1024));; *) echo "$size_val";; esac
}

# --- Verificaciones Previas ---
if [ "$(id -u)" -ne 0 ]; then echo "❌ Error: Ejecutar con sudo."; exit 1; fi
check_dependencies

echo "🔍 Verificando la configuración de swap existente..."
SWAP_INFO=$(swapon --show --noheadings --bytes)

if [ -n "$SWAP_INFO" ]; then
  # Si /swapfile ya existe, salimos siempre para no duplicarlo.
  if echo "$SWAP_INFO" | grep -q '/swapfile'; then
    echo "✅ Info: El archivo /swapfile ya existe. No se realizarán cambios."
    swapon --show
    exit 0
  fi
  
  # Si existe otro swap, verificamos la variable de configuración.
  if [ "$ALLOW_MULTIPLE_SWAP" = false ]; then
    echo "✅ Info: Ya existe otra configuración de swap activa."
    swapon --show
    echo "   -> El script está configurado para no añadir otro swap (ALLOW_MULTIPLE_SWAP=false)."
    echo "   -> Para añadir /swapfile además del existente, edita el script y cambia la variable a 'true'."
    exit 0
  else
    echo "⚠️  Advertencia: Se creará /swapfile además del swap ya existente (ALLOW_MULTIPLE_SWAP=true)."
  fi
fi

# --- (El resto del script de creación, persistencia y verificación no cambia) ---
echo "🔍 Verificando espacio en disco para un archivo de ${SWAP_SIZE}..."
REQUIRED_BYTES=$(convert_to_bytes "$SWAP_SIZE"); AVAILABLE_KB=$(df -k / | awk 'NR==2 {print $4}'); AVAILABLE_BYTES=$((AVAILABLE_KB * 1024))
if [ "$AVAILABLE_BYTES" -lt "$REQUIRED_BYTES" ]; then echo "❌ Error: No hay suficiente espacio en disco."; exit 1; fi
echo "👍 Espacio en disco suficiente."
echo "🔄 Creando archivo swap de ${SWAP_SIZE} en /swapfile..."
fallocate -l "$SWAP_SIZE" /swapfile; chmod 600 /swapfile; mkswap /swapfile; swapon /swapfile
echo "💾 Haciendo el cambio permanente en /etc/fstab..."; cp /etc/fstab "/etc/fstab.bak.$(date +%F_%T)"
if ! grep -q '/swapfile' /etc/fstab; then echo '/swapfile none swap sw 0 0' >> /etc/fstab; fi
echo "🎉 ¡El nuevo archivo swap se ha añadido y activado correctamente!"
echo "--- Verificación Final ---"; swapon --show; echo ""; free -h; echo "--------------------------"
exit 0
