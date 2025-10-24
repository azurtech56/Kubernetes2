#!/bin/bash
################################################################################
# Fichier de configuration pour Kubernetes HA Setup
# Compatible avec: Ubuntu 20.04/22.04/24.04 - Debian 12/13
# Auteur: azurtech56
# Version: 1.0
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

# ═══════════════════════════════════════════════════════════════════════════
# MASTERS - Configuration flexible
# ═══════════════════════════════════════════════════════════════════════════
# Par défaut : 3 masters (configuration HA recommandée)
# Pour ajouter plus de masters, copiez le bloc et incrémentez le numéro
# Exemple pour un 4ème master :
#   export MASTER4_IP="192.168.0.204"
#   export MASTER4_HOSTNAME="k8s01-4"
#   export MASTER4_FQDN="${MASTER4_HOSTNAME}.${DOMAIN_NAME}"
#   export MASTER4_PRIORITY="98"
# ═══════════════════════════════════════════════════════════════════════════

# Master 1 (Premier master - MASTER keepalived)
export MASTER1_IP="192.168.0.201"
export MASTER1_HOSTNAME="k8s01-1"
export MASTER1_FQDN="${MASTER1_HOSTNAME}.${DOMAIN_NAME}"
export MASTER1_PRIORITY="101"

# Master 2 (BACKUP keepalived)
export MASTER2_IP="192.168.0.202"
export MASTER2_HOSTNAME="k8s01-2"
export MASTER2_FQDN="${MASTER2_HOSTNAME}.${DOMAIN_NAME}"
export MASTER2_PRIORITY="100"

# Master 3 (BACKUP keepalived)
#export MASTER3_IP="192.168.0.203"
#export MASTER3_HOSTNAME="k8s01-3"
#export MASTER3_FQDN="${MASTER3_HOSTNAME}.${DOMAIN_NAME}"
#export MASTER3_PRIORITY="99"

# Pour ajouter un 4ème master, décommentez les lignes ci-dessous :
# export MASTER4_IP="192.168.0.204"
# export MASTER4_HOSTNAME="k8s01-4"
# export MASTER4_FQDN="${MASTER4_HOSTNAME}.${DOMAIN_NAME}"
# export MASTER4_PRIORITY="98"

# Pour ajouter un 5ème master, décommentez les lignes ci-dessous :
# export MASTER5_IP="192.168.0.205"
# export MASTER5_HOSTNAME="k8s01-5"
# export MASTER5_FQDN="${MASTER5_HOSTNAME}.${DOMAIN_NAME}"
# export MASTER5_PRIORITY="97"

# ═══════════════════════════════════════════════════════════════════════════
# WORKERS - Configuration flexible
# ═══════════════════════════════════════════════════════════════════════════
# Par défaut : 3 workers (minimum recommandé pour production)
# Pour ajouter plus de workers, copiez le bloc et incrémentez le numéro
# Exemple pour un 4ème worker :
#   export WORKER4_IP="192.168.0.214"
#   export WORKER4_HOSTNAME="k8s-worker-4"
#   export WORKER4_FQDN="${WORKER4_HOSTNAME}.${DOMAIN_NAME}"
# ═══════════════════════════════════════════════════════════════════════════

# Worker 1
export WORKER1_IP="192.168.0.203"
export WORKER1_HOSTNAME="k8s-worker-1"
export WORKER1_FQDN="${WORKER1_HOSTNAME}.${DOMAIN_NAME}"

# Worker 2
export WORKER2_IP="192.168.0.204"
export WORKER2_HOSTNAME="k8s-worker-2"
export WORKER2_FQDN="${WORKER2_HOSTNAME}.${DOMAIN_NAME}"

# Worker 3
#export WORKER3_IP="192.168.0.213"
#export WORKER3_HOSTNAME="k8s-worker-3"
#export WORKER3_FQDN="${WORKER3_HOSTNAME}.${DOMAIN_NAME}"

# Pour ajouter un 4ème worker, décommentez les lignes ci-dessous :
# export WORKER4_IP="192.168.0.214"
# export WORKER4_HOSTNAME="k8s-worker-4"
# export WORKER4_FQDN="${WORKER4_HOSTNAME}.${DOMAIN_NAME}"

# Pour ajouter un 5ème worker, décommentez les lignes ci-dessous :
# export WORKER5_IP="192.168.0.215"
# export WORKER5_HOSTNAME="k8s-worker-5"
# export WORKER5_FQDN="${WORKER5_HOSTNAME}.${DOMAIN_NAME}"

# Pour ajouter un 6ème worker, décommentez les lignes ci-dessous :
# export WORKER6_IP="192.168.0.216"
# export WORKER6_HOSTNAME="k8s-worker-6"
# export WORKER6_FQDN="${WORKER6_HOSTNAME}.${DOMAIN_NAME}"

# Pour ajouter un 7ème worker, décommentez les lignes ci-dessous :
# export WORKER7_IP="192.168.0.217"
# export WORKER7_HOSTNAME="k8s-worker-7"
# export WORKER7_FQDN="${WORKER7_HOSTNAME}.${DOMAIN_NAME}"

# Pour ajouter un 8ème worker, décommentez les lignes ci-dessous :
# export WORKER8_IP="192.168.0.218"
# export WORKER8_HOSTNAME="k8s-worker-8"
# export WORKER8_FQDN="${WORKER8_HOSTNAME}.${DOMAIN_NAME}"

# Pour ajouter un 9ème worker, décommentez les lignes ci-dessous :
# export WORKER9_IP="192.168.0.219"
# export WORKER9_HOSTNAME="k8s-worker-9"
# export WORKER9_FQDN="${WORKER9_HOSTNAME}.${DOMAIN_NAME}"

# Pour ajouter un 10ème worker, décommentez les lignes ci-dessous :
# export WORKER10_IP="192.168.0.220"
# export WORKER10_HOSTNAME="k8s-worker-10"
# export WORKER10_FQDN="${WORKER10_HOSTNAME}.${DOMAIN_NAME}"

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

# ⚠️ SÉCURITÉ: Mot de passe VRRP (8 caractères max recommandé)
# ⚠️ CHANGEZ CE MOT DE PASSE AVANT TOUTE UTILISATION EN PRODUCTION !
# Pour générer un mot de passe fort: generate_secure_password 8
export VRRP_PASSWORD="K8s_HA_Pass"

# ID du routeur virtuel (doit être unique sur le réseau)
export VRRP_ROUTER_ID="51"

# Intervalle d'annonce en secondes
export VRRP_ADVERT_INT="1"

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURATION KUBERNETES
# ═══════════════════════════════════════════════════════════════════════════

# Version de Kubernetes (format: MAJEUR.MINEUR.PATCH)
# Exemples: "1.32.2", "1.31.5", "1.30.8"
# Note: Le repository utilisera automatiquement MAJEUR.MINEUR (ex: v1.32)
export K8S_VERSION="1.32.2"

# Version du repository (extraite automatiquement de K8S_VERSION)
# Format: MAJEUR.MINEUR (ex: "1.32" depuis "1.32.2")
export K8S_REPO_VERSION=$(echo "$K8S_VERSION" | cut -d'.' -f1,2)

# Subnet pour les pods (réseau interne Calico)
export POD_SUBNET="11.0.0.0/16"

# Subnet pour les services
export SERVICE_SUBNET="10.0.0.0/16"

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

# ⚠️ SÉCURITÉ: Mot de passe bootstrap Rancher
# ⚠️ CHANGEZ CE MOT DE PASSE AVANT TOUTE UTILISATION EN PRODUCTION !
# Pour générer un mot de passe fort: generate_secure_password 16
export RANCHER_PASSWORD="admin"

# Source TLS (rancher, letsEncrypt, secret)
export RANCHER_TLS_SOURCE="rancher"

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURATION MONITORING
# ═══════════════════════════════════════════════════════════════════════════

# ⚠️ SÉCURITÉ: Mot de passe Grafana admin
# ⚠️ CHANGEZ CE MOT DE PASSE AVANT TOUTE UTILISATION EN PRODUCTION !
# Pour générer un mot de passe fort: generate_secure_password 16
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
# URLs DES MANIFESTS
# ═══════════════════════════════════════════════════════════════════════════

# Calico CNI manifest URL
# Pour une version spécifique : https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
export CALICO_MANIFEST_URL="https://docs.projectcalico.org/manifests/calico.yaml"

# MetalLB manifest URL
# Version stable officielle (main branch)
export METALLB_MANIFEST_URL="https://raw.githubusercontent.com/metallb/metallb/main/config/manifests/metallb-native.yaml"
# Pour une version spécifique : https://raw.githubusercontent.com/metallb/metallb/v0.14.0/config/manifests/metallb-native.yaml

# ═══════════════════════════════════════════════════════════════════════════
# TIMEOUTS KUBECTL
# ═══════════════════════════════════════════════════════════════════════════
#
# Ces timeouts sont utilisés par tous les scripts d'installation pour assurer
# une cohérence dans l'attente du démarrage des composants Kubernetes.
# Ajustez ces valeurs si votre environnement est plus lent (machines virtuelles,
# réseau lent, ou ressources limitées).

# Timeout long pour composants lourds (Calico, Prometheus, Rancher, etc.)
# Recommandé: 300s (5 min) - Augmentez à 600s (10 min) si environnement lent
export KUBECTL_WAIT_TIMEOUT="300s"

# Timeout court pour composants légers (MetalLB, cert-manager, etc.)
# Recommandé: 180s (3 min) - Augmentez à 300s (5 min) si environnement lent
export KUBECTL_WAIT_TIMEOUT_SHORT="180s"

# Timeout très court pour vérifications rapides (tests webhook, readiness checks)
# Recommandé: 90s (1.5 min) - Augmentez à 120s (2 min) si environnement lent
export KUBECTL_WAIT_TIMEOUT_QUICK="90s"

# Timeout pour les opérations critiques (initialisation cluster, etcd)
# Recommandé: 600s (10 min) - Peut nécessiter jusqu'à 15 min en environnement très lent
export KUBECTL_WAIT_TIMEOUT_CRITICAL="600s"

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

# ═══════════════════════════════════════════════════════════════════════════
# FONCTIONS DE SÉCURITÉ
# ═══════════════════════════════════════════════════════════════════════════

# Fonction pour générer un mot de passe sécurisé
# Usage: generate_secure_password [longueur]
# Exemple: generate_secure_password 16
generate_secure_password() {
    local length="${1:-16}"

    # Vérifier si openssl est disponible
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 "$((length * 3 / 4))" | tr -d '\n' | head -c "$length"
        echo
    # Fallback sur /dev/urandom si openssl n'est pas disponible
    elif [ -r /dev/urandom ]; then
        tr -dc 'A-Za-z0-9!@#$%^&*()_+-=' </dev/urandom | head -c "$length"
        echo
    else
        echo "ERREUR: Impossible de générer un mot de passe sécurisé" >&2
        echo "Installez openssl ou vérifiez l'accès à /dev/urandom" >&2
        return 1
    fi
}

# Fonction pour vérifier la force d'un mot de passe
# Usage: check_password_strength "mot_de_passe"
check_password_strength() {
    local password="$1"
    local length=${#password}
    local score=0

    # Critères de force
    [ "$length" -ge 8 ] && ((score++))
    [ "$length" -ge 12 ] && ((score++))
    [ "$length" -ge 16 ] && ((score++))
    echo "$password" | grep -q '[a-z]' && ((score++))
    echo "$password" | grep -q '[A-Z]' && ((score++))
    echo "$password" | grep -q '[0-9]' && ((score++))
    echo "$password" | grep -q '[!@#$%^&*()_+=-]' && ((score++))

    # Évaluation
    if [ "$score" -le 3 ]; then
        echo "FAIBLE"
        return 1
    elif [ "$score" -le 5 ]; then
        echo "MOYEN"
        return 0
    else
        echo "FORT"
        return 0
    fi
}

# Fonction pour afficher un avertissement de sécurité
show_security_warning() {
    echo ""
    echo "⚠️  ═══════════════════════════════════════════════════════════════════"
    echo "⚠️  AVERTISSEMENT DE SÉCURITÉ"
    echo "⚠️  ═══════════════════════════════════════════════════════════════════"
    echo ""
    echo "Les mots de passe par défaut suivants sont FAIBLES et doivent être changés:"
    echo ""
    echo "  - VRRP_PASSWORD     : $(check_password_strength "$VRRP_PASSWORD")"
    echo "  - RANCHER_PASSWORD  : $(check_password_strength "$RANCHER_PASSWORD")"
    echo "  - GRAFANA_PASSWORD  : $(check_password_strength "$GRAFANA_PASSWORD")"
    echo ""
    echo "Pour générer des mots de passe sécurisés, utilisez:"
    echo "  generate_secure_password 8   # Pour VRRP (max 8 caractères)"
    echo "  generate_secure_password 16  # Pour Rancher et Grafana"
    echo ""
    echo "Exemple:"
    echo "  export VRRP_PASSWORD=\"\$(generate_secure_password 8)\""
    echo "  export RANCHER_PASSWORD=\"\$(generate_secure_password 16)\""
    echo "  export GRAFANA_PASSWORD=\"\$(generate_secure_password 16)\""
    echo ""
    echo "⚠️  ═══════════════════════════════════════════════════════════════════"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════
# FONCTIONS UTILITAIRES DE CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════

# Fonction pour obtenir tous les masters configurés (détection dynamique)
get_all_masters() {
    local master_num=1
    local masters_list=""

    while true; do
        local ip_var="MASTER${master_num}_IP"
        local hostname_var="MASTER${master_num}_HOSTNAME"
        local fqdn_var="MASTER${master_num}_FQDN"
        local priority_var="MASTER${master_num}_PRIORITY"

        # Vérifier si la variable existe et n'est pas vide
        if [ -n "${!ip_var}" ]; then
            masters_list="${masters_list}${master_num}:${!ip_var}:${!hostname_var}:${!fqdn_var}:${!priority_var}\n"
            ((master_num++))
        else
            break
        fi
    done

    echo -e "$masters_list"
}

# Fonction pour obtenir le nombre de masters configurés
get_master_count() {
    local count=0
    local master_num=1

    while true; do
        local ip_var="MASTER${master_num}_IP"
        if [ -n "${!ip_var}" ]; then
            ((count++))
            ((master_num++))
        else
            break
        fi
    done

    echo "$count"
}

# Fonction pour obtenir le nombre de workers configurés
get_worker_count() {
    local count=0
    local worker_num=1

    while true; do
        local ip_var="WORKER${worker_num}_IP"
        if [ -n "${!ip_var}" ]; then
            ((count++))
            ((worker_num++))
        else
            break
        fi
    done

    echo "$count"
}

# Fonction pour obtenir tous les workers configurés
get_all_workers() {
    local worker_num=1
    local workers_list=""

    while true; do
        local ip_var="WORKER${worker_num}_IP"
        local hostname_var="WORKER${worker_num}_HOSTNAME"
        local fqdn_var="WORKER${worker_num}_FQDN"

        if [ -n "${!ip_var}" ]; then
            workers_list="${workers_list}${worker_num}:${!ip_var}:${!hostname_var}:${!fqdn_var}\n"
            ((worker_num++))
        else
            break
        fi
    done

    echo -e "$workers_list"
}

# Fonction pour générer le fichier /etc/hosts (dynamique)
generate_hosts_entries() {
    echo "# Kubernetes HA Cluster"
    echo "${VIP} ${VIP_FQDN} ${VIP_HOSTNAME}"

    # Ajouter tous les masters dynamiquement
    local master_num=1
    while true; do
        local ip_var="MASTER${master_num}_IP"
        local hostname_var="MASTER${master_num}_HOSTNAME"
        local fqdn_var="MASTER${master_num}_FQDN"

        if [ -n "${!ip_var}" ]; then
            echo "${!ip_var} ${!fqdn_var} ${!hostname_var}"
            ((master_num++))
        else
            break
        fi
    done

    # Ajouter tous les workers dynamiquement
    local worker_num=1
    while true; do
        local ip_var="WORKER${worker_num}_IP"
        local hostname_var="WORKER${worker_num}_HOSTNAME"
        local fqdn_var="WORKER${worker_num}_FQDN"

        if [ -n "${!ip_var}" ]; then
            echo "${!ip_var} ${!fqdn_var} ${!hostname_var}"
            ((worker_num++))
        else
            break
        fi
    done
}

# Fonction pour afficher la configuration (dynamique)
show_config() {
    echo "════════════════════════════════════════════════════════════════"
    echo "                    CONFIGURATION ACTUELLE"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "Domaine:"
    echo "  Nom de domaine:   ${DOMAIN_NAME}"
    echo ""
    echo "Réseau:"
    echo "  IP Virtuelle:     ${VIP} (${VIP_FQDN})"
    echo ""
    echo "Masters: ($(get_master_count) configurés)"

    # Afficher tous les masters dynamiquement
    local master_num=1
    while true; do
        local ip_var="MASTER${master_num}_IP"
        local fqdn_var="MASTER${master_num}_FQDN"
        local priority_var="MASTER${master_num}_PRIORITY"

        if [ -n "${!ip_var}" ]; then
            echo "  Master ${master_num}:         ${!ip_var} (${!fqdn_var}) - Priority ${!priority_var}"
            ((master_num++))
        else
            break
        fi
    done

    echo ""
    echo "Workers: ($(get_worker_count) configurés)"

    # Afficher tous les workers dynamiquement
    local worker_num=1
    while true; do
        local ip_var="WORKER${worker_num}_IP"
        local fqdn_var="WORKER${worker_num}_FQDN"

        if [ -n "${!ip_var}" ]; then
            echo "  Worker ${worker_num}:         ${!ip_var} (${!fqdn_var})"
            ((worker_num++))
        else
            break
        fi
    done

    echo ""
    echo "Interface:"
    echo "  Réseau:           $(detect_network_interface)"
    echo ""
    echo "MetalLB:"
    echo "  Plage IP:         ${METALLB_IP_RANGE}"
    echo ""
    echo "Kubernetes:"
    echo "  Version:          ${K8S_VERSION}"
    echo "  Pod Subnet:       ${POD_SUBNET}"
    echo "  Service Subnet:   ${SERVICE_SUBNET}"
    echo "  API Port:         ${API_SERVER_PORT}"
    echo ""
    echo "Rancher:"
    echo "  Hostname:         ${RANCHER_HOSTNAME}"
    echo "  TLS Source:       ${RANCHER_TLS_SOURCE}"
    echo ""
    echo "Monitoring:"
    echo "  Namespace:        ${MONITORING_NAMESPACE}"
    echo ""
    echo "════════════════════════════════════════════════════════════════"
}

# Fonction pour valider la configuration (dynamique)
validate_config() {
    local errors=0

    # Vérifier la VIP
    if ! [[ $VIP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "Erreur: VIP invalide ($VIP)"
        ((errors++))
    fi

    # Vérifier dynamiquement toutes les IPs des masters
    local master_num=1
    while true; do
        local ip_var="MASTER${master_num}_IP"

        if [ -n "${!ip_var}" ]; then
            if ! [[ ${!ip_var} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                echo "Erreur: MASTER${master_num}_IP invalide (${!ip_var})"
                ((errors++))
            fi

            # Vérifier que l'IP n'est pas la même que la VIP
            if [ "$VIP" = "${!ip_var}" ]; then
                echo "Erreur: VIP ne doit pas être identique à MASTER${master_num}_IP"
                ((errors++))
            fi

            ((master_num++))
        else
            break
        fi
    done

    # Vérifier dynamiquement toutes les IPs des workers
    local worker_num=1
    while true; do
        local ip_var="WORKER${worker_num}_IP"

        if [ -n "${!ip_var}" ]; then
            if ! [[ ${!ip_var} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                echo "Erreur: WORKER${worker_num}_IP invalide (${!ip_var})"
                ((errors++))
            fi

            ((worker_num++))
        else
            break
        fi
    done

    # Vérifier qu'il y a au moins 1 master
    if [ $(get_master_count) -lt 1 ]; then
        echo "Erreur: Au moins 1 master doit être configuré"
        ((errors++))
    fi

    if [ $errors -eq 0 ]; then
        echo "✓ Configuration valide"
        echo "  - Masters: $(get_master_count)"
        echo "  - Workers: $(get_worker_count)"
        return 0
    else
        echo "✗ $errors erreur(s) dans la configuration"
        return 1
    fi
}

# Exporter toutes les fonctions
export -f detect_network_interface
export -f get_all_masters
export -f get_master_count
export -f get_all_workers
export -f get_worker_count
export -f generate_hosts_entries
export -f show_config
export -f validate_config
