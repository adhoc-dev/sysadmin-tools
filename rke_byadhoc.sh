#!/bin/bash
#
# Script automágico para trabajar con la nueva infraestructura (Rancher2.x + Kubernetes en GCP)
# Inspirado en magias de https://github.com/azacchino

r2_help () {
    echo "R2, el nuevo comando para trabajar con Rancher2 y Kubernetes by Adhoc!"
    echo "=================="
    echo "Lista de comandos:"
    echo "connect: Acceder con bash a una base agregando el nombre del deploy / pod. Uso: r2 connect test-adhoc-31-12-1"
    echo "logs: Para ver los logs activos de una base. Uso: r2 logs test-adhoc-31-12-1"
}

r2_connect () {
    rancher2 kubectl exec -ti -n $1 deploy/$1-adhoc-odoo -- bash
}

r2_logs () {
    rancher2 kubectl logs -f -n $1 deploy/$1-adhoc-odoo
}


case $1 in
  connect)
    r2_connect $2
    ;;
    logs)
    r2_logs $2
    ;;
  *)
    r2_help
    ;;
esac
