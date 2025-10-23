#!/bin/bash
################################################################################
# Fichier de configuration pour Kubernetes HA Setup
# Modifiez les valeurs ci-dessous selon votre environnement
################################################################################

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURATION RÉSEAU
# ═══════════════════════════════════════════════════════════════════════════

# Nom de domaine (utilisé pour tous les FQDN)
export DOMAIN_NAME="home.local"

# IP Virtuelle (VIP) pour la haute disponibilité
export VIP="192.168.0.200"
export VIP_HOSTNAME="k8s"
export VIP_FQDN="${VIP_HOSTNAME}.${DOMAIN_NAME}"

# Masters
export MASTER1_IP="192.168.0.201"
export MASTER1_HOSTNAME="k8s01-1"
export MASTER1_FQDN="${MASTER1_HOSTNAME}.${DOMAIN_NAME}"
export MASTER1_PRIORITY="101"

export MASTER2_IP="192.168.0.202"
export MASTER2_HOSTNAME="k8s01-2"
export MASTER2_FQDN="${MASTER2_HOSTNAME}.${DOMAIN_NAME}"
export MASTER2_PRIORITY="100"

export MASTER3_IP="192.168.0.203"
export MASTER3_HOSTNAME="k8s01-3"
export MASTER3_FQDN="${MASTER3_HOSTNAME}.${DOMAIN_NAME}"
export MASTER3_PRIORITY="99"

# Workers (configurez selon vos besoins)
export WORKER1_IP="192.168.0.211"
export WORKER1_HOSTNAME="k8s-worker-1"
export WORKER1_FQDN="${WORKER1_HOSTNAME}.${DOMAIN_NAME}"

export WORKER2_IP="192.168.0.212"
export WORKER2_HOSTNAME="k8s-worker-2"
export WORKER2_FQDN="${WORKER2_HOSTNAME}.${DOMAIN_NAME}"

export WORKER3_IP="192.168.0.213"
export WORKER3_HOSTNAME="k8s-worker-3"
export WORKER3_FQDN="${WORKER3_HOSTNAME}.${DOMAIN_NAME}"

# Nombre de workers (modifiez selon votre configuration)
export WORKER_COUNT=3

# Interface réseau (détectée automatiquement si vide)
# Exemples: ens33, ens18, enp0s3, eth0
export NETWORK_INTERFACE="${NETWORK_INTERFACE:-auto}"

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURATION METALLB
# ═══════════════════════════════════════════════════════════════════════════

# Plage d'adresses IP pour MetalLB Load Balancer
export METALLB_IP_START="192.168.0.210"
export METALLB_IP_END="192.168.0.230"
export METALLB_IP_RANGE="${METALLB_IP_START}-${METALLB_IP_END}"

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURATION KEEPALIVED
# ═══════════════════════════════════════════════════════════════════════════

# Mot de passe VRRP (8 caractères max recommandé)
export VRRP_PASSWORD="K8s_HA_Pass"

# ID du routeur virtuel (doit être unique sur le réseau)
export VRRP_ROUTER_ID="51"

# Intervalle d'annonce en secondes
export VRRP_ADVERT_INT="1"

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURATION KUBERNETES
# ═══════════════════════════════════════════════════════════════════════════

# Version de Kubernetes
export K8S_VERSION="1.32.2"

# Subnet pour les pods (réseau interne Calico)
export POD_SUBNET="11.0.0.0/16"

# Subnet pour les services
export SERVICE_SUBNET="10.0.0.1/16"

# Port de l'API Server
export API_SERVER_PORT="6443"

# Socket CRI (Container Runtime Interface)
export CRI_SOCKET="/var/run/containerd/containerd.sock"

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURATION RANCHER
# ═══════════════════════════════════════════════════════════════════════════

# Hostname pour Rancher (utilise DOMAIN_NAME)
export RANCHER_SUBDOMAIN="rancher"
export RANCHER_HOSTNAME="${RANCHER_SUBDOMAIN}.${DOMAIN_NAME}"

# Mot de passe bootstrap Rancher
export RANCHER_PASSWORD="admin"

# Source TLS (rancher, letsEncrypt, secret)
export RANCHER_TLS_SOURCE="rancher"

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURATION MONITORING
# ═══════════════════════════════════════════════════════════════════════════

# Mot de passe Grafana admin
export GRAFANA_PASSWORD="prom-operator"

# Namespace pour le monitoring
export MONITORING_NAMESPACE="monitoring"

# ═══════════════════════════════════════════════════════════════════════════
# VERSIONS DES COMPOSANTS
# ═══════════════════════════════════════════════════════════════════════════

# cert-manager version
export CERT_MANAGER_VERSION="v1.17.0"

# Calico version (latest ou version spécifique comme v3.28.0)
export CALICO_VERSION="latest"

# ═══════════════════════════════════════════════════════════════════════════
# FONCTIONS UTILITAIRES
# ═══════════════════════════════════════════════════════════════════════════

# Fonction pour détecter l'interface réseau principale
detect_network_interface() {
    if [ "$NETWORK_INTERFACE" = "auto" ]; then
        NETWORK_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    fi
    echo "$NETWORK_INTERFACE"
}

# Fonction pour générer le fichier /etc/hosts
generate_hosts_entries() {
    cat <<EOF
# Kubernetes HA Cluster
${VIP} ${VIP_FQDN} ${VIP_HOSTNAME}
${MASTER1_IP} ${MASTER1_FQDN} ${MASTER1_HOSTNAME}
${MASTER2_IP} ${MASTER2_FQDN} ${MASTER2_HOSTNAME}
${MASTER3_IP} ${MASTER3_FQDN} ${MASTER3_HOSTNAME}
${WORKER1_IP} ${WORKER1_FQDN} ${WORKER1_HOSTNAME}
${WORKER2_IP} ${WORKER2_FQDN} ${WORKER2_HOSTNAME}
${WORKER3_IP} ${WORKER3_FQDN} ${WORKER3_HOSTNAME}
EOF
}

# Fonction pour afficher la configuration
show_config() {
    cat <<EOF
════════════════════════════════════════════════════════════════
                    CONFIGURATION ACTUELLE
════════════════════════════════════════════════════════════════

Domaine:
  Nom de domaine:   ${DOMAIN_NAME}

Réseau:
  IP Virtuelle:     ${VIP} (${VIP_FQDN})

Masters:
  Master 1:         ${MASTER1_IP} (${MASTER1_FQDN}) - Priority ${MASTER1_PRIORITY}
  Master 2:         ${MASTER2_IP} (${MASTER2_FQDN}) - Priority ${MASTER2_PRIORITY}
  Master 3:         ${MASTER3_IP} (${MASTER3_FQDN}) - Priority ${MASTER3_PRIORITY}

Workers:
  Worker 1:         ${WORKER1_IP} (${WORKER1_FQDN})
  Worker 2:         ${WORKER2_IP} (${WORKER2_FQDN})
  Worker 3:         ${WORKER3_IP} (${WORKER3_FQDN})
  Nombre:           ${WORKER_COUNT}

Interface:
  Réseau:           $(detect_network_interface)

MetalLB:
  Plage IP:         ${METALLB_IP_RANGE}

Kubernetes:
  Version:          ${K8S_VERSION}
  Pod Subnet:       ${POD_SUBNET}
  Service Subnet:   ${SERVICE_SUBNET}
  API Port:         ${API_SERVER_PORT}

Rancher:
  Hostname:         ${RANCHER_HOSTNAME}
  TLS Source:       ${RANCHER_TLS_SOURCE}

Monitoring:
  Namespace:        ${MONITORING_NAMESPACE}

════════════════════════════════════════════════════════════════
EOF
}

# Fonction pour valider la configuration
validate_config() {
    local errors=0

    # Vérifier les IPs
    if ! [[ $VIP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "Erreur: VIP invalide ($VIP)"
        ((errors++))
    fi

    if ! [[ $MASTER1_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "Erreur: MASTER1_IP invalide ($MASTER1_IP)"
        ((errors++))
    fi

    # Vérifier que les IPs sont différentes
    if [ "$VIP" = "$MASTER1_IP" ] || [ "$VIP" = "$MASTER2_IP" ] || [ "$VIP" = "$MASTER3_IP" ]; then
        echo "Erreur: VIP doit être différente des IPs des masters"
        ((errors++))
    fi

    if [ $errors -eq 0 ]; then
        echo "✓ Configuration valide"
        return 0
    else
        echo "✗ $errors erreur(s) dans la configuration"
        return 1
    fi
}

# Exporter toutes les fonctions
export -f detect_network_interface
export -f generate_hosts_entries
export -f show_config
export -f validate_config
