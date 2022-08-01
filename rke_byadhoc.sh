#!/bin/bash
#
# Script automágico para trabajar con la nueva infraestructura (Rancher2.x + Kubernetes en GCP)
# Inspirado en código de https://github.com/azacchino
# Repositorio: https://github.com/adhoc-dev/sysadmin-tools/blob/main/rke_byadhoc.sh

r2_help () {
    echo "R2, el nuevo comando para trabajar con Rancher2 y Kubernetes by Adhoc! 🚀"
    echo "=================="
    echo "🤖 Lista de comandos:"
    echo "connect: Acceder con bash a una base agregando el nombre del deploy / pod. Uso: r2 connect test-adhoc-31-12-1"
    echo "logs: Para ver los logs activos de una base. Uso: r2 logs test-adhoc-31-12-1"
    echo "describe: Muestra detalles de un recurso o grupo. Uso: r2 describe cotesma"
    echo "gcp: Devuelve la URL para acceder a la consola > Pod (métricas, logs). Uso: r2 gcp symmetria"
    echo "reg: Devuelve la URL para acceder a los logs desde GCP > Logs históricos. Uso: r2 reg perfit"
    echo "redeploy: Cierra y reinicia cada contenedor del pod, no hay downtime ni reinicia valores del workload. Uso: r2 redeploy test-demo-retail-22-07-1"
}

r2_connect () {
    rancher2 kubectl exec -ti -n $1 deploy/$1-adhoc-odoo -- bash
}

r2_logs () {
    rancher2 kubectl -n $1 logs -f -n $1 --selector app.kubernetes.io/instance=$1
}

r2_describe () {
    rancher2 kubectl describe -n $1 deploy/$1-adhoc-odoo
}

r2_gcp () {
    echo https://console.cloud.google.com/kubernetes/deployment/us-east1-b/adhocprod/$1/$1-adhoc-odoo/overview?project=nubeadhoc
}

r2_clean () {
    kubectl get pods --all-namespaces | grep Terminated | while read namespace pod rest; do kubectl delete pod $pod -n $namespace; done
}

r2_reg () {
    echo "https://console.cloud.google.com/logs/query;query=resource.type%3D%22k8s_container%22%0Aresource.labels.namespace_name%3D%22$1%22?project=nubeadhoc"
}

r2_redeploy () {
    kubectl rollout restart deployment $1-adhoc-odoo -n $1
}

case $1 in
  connect)
    r2_connect $2
    ;;
  logs)
    r2_logs $2
    ;;
  describe)
    r2_describe $2
    ;;
  gcp)
    r2_gcp $2
    ;;
  clean)
    r2_clean
    ;;
  reg)
    r2_reg $2
    ;;
  redeploy)
    r2_redeploy $2
    ;;
  *)
    r2_help
    ;;
esac
