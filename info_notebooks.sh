#!/bin/bash

# --- Forzar formato numérico estándar para evitar errores con comas decimales ---
export LC_NUMERIC="C"

# Script UNIVERSAL y COMPATIBLE (v5) que genera un informe de sistema en un archivo JSON.
# Corrige el parsing de los slots de RAM para máxima compatibilidad.
# Requiere 'jq'. Uso: sudo ./info_notebooks.sh

if [ "$EUID" -ne 0 ]; then
  echo "{\"error\": \"Este script debe ser ejecutado con sudo.\"}" >&2
  exit 1
fi
if ! command -v jq &> /dev/null; then
  echo "{\"error\": \"El comando 'jq' no está instalado. Por favor, ejecútalo: sudo apt install jq\"}" >&2
  exit 1
fi

serial_number=$(dmidecode -s system-serial-number)
if [ -z "$serial_number" ] || [[ "$serial_number" == *" "* ]]; then
    output_filename="info_report.json"
else
    output_filename="info_${serial_number}.json"
fi

system_model=$(dmidecode -s system-product-name)
uptime_p=$(uptime -p | sed 's/up //')
load_avg_raw=$(uptime | awk -F'load average: ' '{print $2}')
load_avg_1m=$(echo $load_avg_raw | awk -F', ' '{print $1}')
load_avg_5m=$(echo $load_avg_raw | awk -F', ' '{print $2}')
load_avg_15m=$(echo $load_avg_raw | awk -F', ' '{print $3}')
cpu_model=$(lscpu | grep "Model name:" | sed 's/Model name:[ \t]*//')
cpu_threads=$(lscpu | grep "^CPU(s):" | sed 's/CPU(s):[ \t]*//')

TEMPERATURE_THRESHOLD=65.0
high_temp_alert="null"
temps_raw=$(cat /sys/class/hwmon/hwmon*/temp*_input 2>/dev/null)
readings=()
is_high=false
for temp in $temps_raw; do
    temp_c=$(awk -v t="$temp" 'BEGIN {printf "%.1f", t/1000}')
    readings+=("$temp_c")
    if (( $(echo "$temp_c > $TEMPERATURE_THRESHOLD" | bc -l) )); then
        is_high=true
    fi
done
if $is_high; then
    high_temp_readings=$(printf '%s\n' "${readings[@]}" | jq -R . | jq -s .)
    high_temp_alert=$(jq -n --argjson r "$high_temp_readings" '{ "alert": "Temperatura elevada detectada (superior a 65.0°C)", "readings_celsius": $r }')
fi

disk_usage_root=$(df -P / | tail -n 1 | awk '{print $5}')
storage_info=$(lsblk -b -J -o NAME,TYPE,SIZE,MODEL)

ram_line=$(free -b | grep "^Mem:")
ram_total_gib=$(echo "$ram_line" | awk '{printf "%.2f", $2/1073741824}')
ram_used_gib=$(echo "$ram_line" | awk '{printf "%.2f", $3/1073741824}')
ram_available_gib=$(echo "$ram_line" | awk '{printf "%.2f", $7/1073741824}')

swap_line=$(free -b | grep "^Swap:")
swap_total_gib=$(echo "$swap_line" | awk '{printf "%.2f", $2/1073741824}')
swap_used_gib=$(echo "$swap_line" | awk '{printf "%.2f", $3/1073741824}')
swap_free_gib=$(echo "$swap_line" | awk '{printf "%.2f", $4/1073741824}')

max_capacity=$(dmidecode -t memory | grep "Maximum Capacity" | awk -F': ' '{print $2}')
total_slots=$(dmidecode -t memory | grep "Number Of Devices" | awk -F': ' '{print $2}')

# --- Lógica de Hardware de RAM (Método v5, más robusto) ---
ram_slots_json="["
# Obtenemos los "handles" o identificadores únicos de cada dispositivo de memoria instalado
handles=$(dmidecode -t memory | grep -A2 "Memory Device" | grep "Handle" | awk '{print $2}' | sed 's/,//')
first_slot=true
for handle in $handles; do
    # Extraemos el bloque de texto que corresponde solo a ese dispositivo
    device_info=$(dmidecode -t memory | awk -v handle="$handle" '
        BEGIN {RS="Memory Device"; FS="\n"} 
        $0 ~ "Handle " handle {print "Memory Device" $0}'
    )
    # Si el bloque no contiene un módulo, lo saltamos
    if echo "$device_info" | grep -q "Size: No Module Installed"; then
        continue
    fi
    # Extraemos cada campo de forma independiente del bloque
    locator=$(echo "$device_info" | grep "Locator:" | awk -F': ' '{print $2}')
    size=$(echo "$device_info" | grep "Size:" | awk -F': ' '{print $2}')
    type=$(echo "$device_info" | grep "Type:" | awk -F': ' '{print $2}')
    speed=$(echo "$device_info" | grep "Speed:" | awk -F': ' '{print $2}')
    
    if ! $first_slot; then
        ram_slots_json+=","
    fi
    first_slot=false
    ram_slots_json+=$(jq -n \
                      --arg locator "$locator" \
                      --arg size "$size" \
                      --arg type "$type" \
                      --arg speed "$speed" \
                      '{locator: $locator, size: $size, type: $type, speed: $speed}')
done
ram_slots_json+="]"

installed_ram_sizes=$(echo "$ram_slots_json" | jq -r '.[].size' | sed 's/ GB//g' | awk '{print $1}' | sort -u)
unique_size_count=$(echo "$installed_ram_sizes" | wc -l)
is_asymmetric=false
if [ "$unique_size_count" -gt 1 ]; then
  is_asymmetric=true
fi

# --- Ensamblaje Final con JQ ---
jq -n \
  --arg sn "$serial_number" \
  --arg model "$system_model" \
  --arg uptime "$uptime_p" \
  --arg la1 "$load_avg_1m" \
  --arg la5 "$load_avg_5m" \
  --arg la15 "$load_avg_15m" \
  --arg cpu_model "$cpu_model" \
  --arg cpu_threads "$cpu_threads" \
  --argjson temp_alert "$high_temp_alert" \
  --argjson storage "$storage_info" \
  --arg disk_usage "$disk_usage_root" \
  --arg ram_total "$ram_total_gib" \
  --arg ram_used "$ram_used_gib" \
  --arg ram_avail "$ram_available_gib" \
  --arg swap_total "$swap_total_gib" \
  --arg swap_used "$swap_used_gib" \
  --arg swap_free "$swap_free_gib" \
  --arg max_mem "$max_capacity" \
  --arg num_slots "$total_slots" \
  --argjson asymmetric "$is_asymmetric" \
  --argjson slots "$ram_slots_json" \
  '{
    "report_timestamp": (now | todate),
    "system_info": {
      "model": $model,
      "serial_number": $sn
    },
    "performance": {
      "uptime": $uptime,
      "load_average": {
        "1_min": ($la1 | tonumber),
        "5_min": ($la5 | tonumber),
        "15_min": ($la15 | tonumber)
      },
      "temperature_alert": $temp_alert
    },
    "cpu": {
      "model": $cpu_model,
      "threads": ($cpu_threads | tonumber)
    },
    "storage": {
      "physical_devices": $storage.blockdevices,
      "root_filesystem_usage": $disk_usage
    },
    "memory": {
      "usage": {
        "ram_gib": {
          "total": ($ram_total | tonumber),
          "used": ($ram_used | tonumber),
          "available": ($ram_avail | tonumber)
        },
        "swap_gib": {
          "total": ($swap_total | tonumber),
          "used": ($swap_used | tonumber),
          "free": ($swap_free | tonumber)
        }
      },
      "hardware": {
        "max_capacity_supported": $max_mem,
        "total_slots": ($num_slots | tonumber),
        "asymmetric_configuration_warning": $asymmetric,
        "installed_slots": $slots
      }
    }
  }' > "$output_filename"

echo "✅ Informe guardado exitosamente en el archivo: $output_filename"
