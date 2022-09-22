#!/bin/bash

###################################################################################################
# Este script está preparado para la actualización, mejora y limpieza de entornos Ubuntu / notebooks
# de la empresa. Además, recoge información sobre los recursos y el estado de los equipos
# con el fin de actualizar nuestra base de datos.
# Repositorio: https://github.com/adhoc-dev/sysadmin-tools/blob/main/script_mantenimiento.sh
# Autor: TedLeRoy (https://github.com/TedLeRoy/ubuntu-update.sh/blob/master/LICENSE.md)
# Adaptación: Diego Bollini
# Compañía: adhoc.com.ar
# Tiempo estimado: 10 minutos
###################################################################################################

# Colores para el texto
red=$( tput setaf 1 );
yellow=$( tput setaf 3 );
green=$( tput setaf 2 );
normal=$( tput sgr 0 );


# Presentación
HEADER="
GRACIAS POR EJECUTAR ESTE PROGRAMA DE AUTO-MANTENIMIENTO DE EQUIPOS.
TE MERECES ESTO 🎁👏🤗
...
Es un script muy simple para actualizar y limpiar notebooks de Adhoc que usan Ubuntu.
No hay ninguna garantía ni mantenimiento fuera del alcance de Adhoc S.A."


# Verificando si se está ejecutando como root

if [[ ${UID} != 0 ]]; then
    echo "${red}
    Este programa se debe ejecutar con poderes, es decir con sudo...
    Por favor anteponer sudo al comando.${normal}
    "
    exit 1
fi

# Mostrando presentación

echo "${red}$HEADER${normal}"


# Actualizar repositorios

echo -e "
\e[32m###################################
#     Actualizando repositorios   #
###################################\e[0m
"
apt-get update | tee /tmp/update-output.txt


# Actualización completa

echo -e "
\e[32m####################################
# Actualizando sistema operativo   #
####################################\e[0m
"
apt-get upgrade -y | tee -a /tmp/update-output.txt
apt-get install unattended-upgrades -y | tee -a /tmp/update-output.txt
snap refresh | tee -a /tmp/update-output.txt
apt-get install screenfetch -y

# Limpieza de caché, repositorios, paquetes

echo -e "
\e[32m#####################################
#    Limpieza de caché y paquetes   #
#####################################\e[0m
"
apt-get clean | tee -a /tmp/update-output.txt
apt-get autoclean | tee -a /tmp/update-output.txt
apt-get autoremove | tee -a /tmp/update-output.txt


# Revisando si quedó algún log en el archivo temporal

if [ -f "/tmp/update-output.txt"  ]

then

# Revisando y mostrando logs que sean relevantes

  echo -e "
\e[32m################################################
#   Mostrando si existen acciones a realizar   #
################################################\e[0m
"
  egrep -wi --color 'warning|error|critical|reboot|restart|autoclean|autoremove' /tmp/update-output.txt | uniq
  echo -e "
\e[32m#######################################
#    Limpiando archivos temporales    #
#######################################\e[0m
"

  rm /tmp/update-output.txt
  echo -e "
\e[32m#######################################
#     POR FAVOR COPIAR Y RESPONDER    #
#     CON EL SIGUIENTE TEXTO...       #
#     ¡GRACIAS!                       #
#######################################\e[0m
"
fi

# Información a recolectar de los equipos

screenfetch -n | egrep 'OS:|Disk:|CPU:|RAM:'
echo "Battery" && upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep capacity
echo "Battery" && upower -i /org/freedesktop/UPower/devices/battery_BAT1 | grep capacity


exit 0
