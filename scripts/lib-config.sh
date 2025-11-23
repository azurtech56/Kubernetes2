#!/bin/bash
################################################################################
# Librairie partagée pour chargement et validation de configuration
# Utilisée par tous les scripts du cluster Kubernetes HA
# Auteur: azurtech56
# Version: 1.0
################################################################################

# Couleurs pour affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# FONCTION: Charger et valider la configuration Kubernetes
# ============================================================================
load_kubernetes_config() {
    local config_dir="${1:-.}"
    local config_file="$config_dir/config.sh"

    echo -e "${BLUE}▶ Chargement de la configuration...${NC}"

    # Charger le fichier config.sh s'il existe
    if [ -f "$config_file" ]; then
        echo -e "${BLUE}  Source: ${config_file}${NC}"
        if ! source "$config_file" 2>/dev/null; then
            echo -e "${RED}✗ Erreur lors du chargement de ${config_file}${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}  ⚠ ${config_file} non trouvé, utilisation des defaults${NC}"
        set_default_kubernetes_config
    fi

    # Valider les variables critiques
    if ! validate_kubernetes_config; then
        echo -e "${RED}✗ Configuration invalide${NC}"
        return 1
    fi

    echo -e "${GREEN}✓ Configuration chargée et validée${NC}"
    return 0
}

# ============================================================================
# FONCTION: Définir les valeurs par défaut
# ============================================================================
set_default_kubernetes_config() {
    # Réseau
    export DOMAIN_NAME="${DOMAIN_NAME:-home.local}"
    export VIP="${VIP:-192.168.0.200}"
    export VIP_HOSTNAME="${VIP_HOSTNAME:-k8s}"
    export CLUSTER_NODES_NETWORK="${CLUSTER_NODES_NETWORK:-192.168.0.0/24}"

    # Kubernetes
    export K8S_VERSION="${K8S_VERSION:-1.33.0}"
    export K8S_REPO_VERSION=$(echo "$K8S_VERSION" | cut -d'.' -f1,2)
    export POD_SUBNET="${POD_SUBNET:-11.0.0.0/16}"
    export SERVICE_SUBNET="${SERVICE_SUBNET:-10.0.0.0/16}"
    export API_SERVER_PORT="${API_SERVER_PORT:-6443}"

    # Masters
    export MASTER1_IP="${MASTER1_IP:-192.168.0.201}"
    export MASTER1_HOSTNAME="${MASTER1_HOSTNAME:-k8s-master}"
    export MASTER1_PRIORITY="${MASTER1_PRIORITY:-101}"

    # MetalLB
    export METALLB_IP_START="${METALLB_IP_START:-192.168.0.220}"
    export METALLB_IP_END="${METALLB_IP_END:-192.168.0.240}"

    # keepalived
    export VRRP_PASSWORD="${VRRP_PASSWORD:-K8sHA}"
    export VRRP_INTERFACE="${VRRP_INTERFACE:-eth0}"
    export VRRP_ADVERT_INT="${VRRP_ADVERT_INT:-1}"

    # Timeouts
    export KUBECTL_WAIT_TIMEOUT="${KUBECTL_WAIT_TIMEOUT:-300s}"
    export KUBECTL_WAIT_TIMEOUT_SHORT="${KUBECTL_WAIT_TIMEOUT_SHORT:-180s}"
    export KUBECTL_WAIT_TIMEOUT_QUICK="${KUBECTL_WAIT_TIMEOUT_QUICK:-90s}"

    # Versions des composants
    export CERT_MANAGER_VERSION="${CERT_MANAGER_VERSION:-v1.17.0}"
    export CALICO_VERSION="${CALICO_VERSION:-latest}"
    export STORAGE_PROVISIONER_VERSION="${STORAGE_PROVISIONER_VERSION:-v0.0.30}"

    # URLs
    export CALICO_MANIFEST_URL="${CALICO_MANIFEST_URL:-https://docs.projectcalico.org/manifests/calico.yaml}"

    # ETCD
    export ETCD_CA_FILE="${ETCD_CA_FILE:-/etc/kubernetes/pki/etcd/ca.crt}"
    export ETCD_CERT_FILE="${ETCD_CERT_FILE:-/etc/kubernetes/pki/etcd/peer.crt}"
    export ETCD_KEY_FILE="${ETCD_KEY_FILE:-/etc/kubernetes/pki/etcd/peer.key}"
    export ETCD_CLIENT_PORT="${ETCD_CLIENT_PORT:-2379}"
}

# ============================================================================
# FONCTION: Valider la configuration Kubernetes
# ============================================================================
validate_kubernetes_config() {
    local required_vars=(
        "K8S_VERSION"
        "VIP"
        "VIP_HOSTNAME"
        "DOMAIN_NAME"
        "MASTER1_IP"
        "MASTER1_HOSTNAME"
        "METALLB_IP_START"
        "METALLB_IP_END"
    )

    local is_valid=true

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            echo -e "${RED}✗ Variable requise non définie: ${var}${NC}"
            is_valid=false
        fi
    done

    # Validation spécifiques
    if ! validate_kubernetes_version "$K8S_VERSION"; then
        is_valid=false
    fi

    if ! validate_ip_address "$VIP"; then
        echo -e "${RED}✗ VIP invalide: ${VIP}${NC}"
        is_valid=false
    fi

    if ! validate_ip_address "$MASTER1_IP"; then
        echo -e "${RED}✗ MASTER1_IP invalide: ${MASTER1_IP}${NC}"
        is_valid=false
    fi

    if [ "$is_valid" = false ]; then
        return 1
    fi

    return 0
}

# ============================================================================
# FONCTION: Valider format version Kubernetes
# ============================================================================
validate_kubernetes_version() {
    local version=$1

    # Format: X.Y.Z (ex: 1.33.0)
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}✗ Format version Kubernetes invalide: ${version}${NC}"
        echo -e "${YELLOW}  Format attendu: X.Y.Z (ex: 1.33.0)${NC}"
        return 1
    fi

    return 0
}

# ============================================================================
# FONCTION: Valider adresse IP
# ============================================================================
validate_ip_address() {
    local ip=$1

    # Regex pour IPv4
    if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 1
    fi

    # Vérifier plages valides
    IFS='.' read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if [ "$octet" -gt 255 ] || [ "$octet" -lt 0 ]; then
            return 1
        fi
    done

    return 0
}

# ============================================================================
# FONCTION: Afficher la configuration actuelle
# ============================================================================
show_kubernetes_config() {
    echo ""
    echo -e "${BLUE}═══ Configuration Kubernetes ═══${NC}"
    echo -e "${YELLOW}Réseau:${NC}"
    echo "  VIP: ${VIP} (${VIP_HOSTNAME}.${DOMAIN_NAME})"
    echo "  Réseau nœuds: ${CLUSTER_NODES_NETWORK}"
    echo "  Réseau pods: ${POD_SUBNET}"
    echo ""
    echo -e "${YELLOW}Kubernetes:${NC}"
    echo "  Version: ${K8S_VERSION}"
    echo "  API Server: ${API_SERVER_PORT}"
    echo ""
    echo -e "${YELLOW}Masters:${NC}"
    echo "  Master 1: ${MASTER1_IP} (${MASTER1_HOSTNAME}.${DOMAIN_NAME})"
    [ -n "$MASTER2_IP" ] && echo "  Master 2: ${MASTER2_IP} (${MASTER2_HOSTNAME}.${DOMAIN_NAME})"
    [ -n "$MASTER3_IP" ] && echo "  Master 3: ${MASTER3_IP} (${MASTER3_HOSTNAME}.${DOMAIN_NAME})"
    echo ""
    echo -e "${YELLOW}MetalLB:${NC}"
    echo "  Pool: ${METALLB_IP_START} - ${METALLB_IP_END}"
    echo ""
}

# ============================================================================
# FONCTION: Extraire version majeure.mineure
# ============================================================================
get_k8s_major_minor() {
    echo "$K8S_VERSION" | cut -d'.' -f1,2
}

# ============================================================================
# FONCTION: Détecter le nombre de masters
# ============================================================================
get_master_count() {
    local count=0
    local i=1

    while true; do
        local ip_var="MASTER${i}_IP"
        if [ -n "${!ip_var}" ]; then
            ((count++))
            ((i++))
        else
            break
        fi
    done

    echo "$count"
}

# ============================================================================
# FONCTION: Afficher avertissement configuration manquante
# ============================================================================
warn_missing_config() {
    echo -e "${YELLOW}⚠ Configuration incomplète${NC}"
    echo -e "${BLUE}Pour configurer les paramètres, éditez:${NC}"
    echo "  nano config.sh"
    echo ""
}

# ============================================================================
# FONCTION: Valider système et prérequis
# ============================================================================
validate_system_prerequisites() {
    local errors=0

    # Vérifier si root
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}✗ Ce script doit être exécuté en tant que root${NC}"
        ((errors++))
    fi

    # Vérifier commandes requises
    local required_commands=(
        "kubeadm"
        "kubectl"
        "kubelet"
        "containerd"
        "curl"
        "wget"
        "git"
    )

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${RED}✗ Commande manquante: ${cmd}${NC}"
            ((errors++))
        fi
    done

    # Vérifier espace disque (minimum 5GB)
    local available_kb=$(df / | tail -1 | awk '{print $4}')
    if [ "$available_kb" -lt 5242880 ]; then  # 5GB en KB
        echo -e "${RED}✗ Espace disque insuffisant (< 5GB disponible)${NC}"
        ((errors++))
    fi

    # Vérifier RAM (minimum 2GB)
    local available_mem_kb=$(free | grep Mem | awk '{print $7}')
    if [ "$available_mem_kb" -lt 2097152 ]; then  # 2GB en KB
        echo -e "${YELLOW}⚠ RAM insuffisante pour Kubernetes (recommandé: 4GB+)${NC}"
    fi

    return $errors
}

# ============================================================================
# FONCTION: Valider configuration d'installation
# ============================================================================
validate_install_prerequisites() {
    local script_name=$1
    local errors=0

    # Ces dépendances doivent être installées
    if [ "$script_name" != "common-setup.sh" ]; then
        local required_packages=(
            "kubeadm"
            "kubectl"
            "kubelet"
            "containerd"
        )

        for pkg in "${required_packages[@]}"; do
            if ! command -v "$pkg" &> /dev/null; then
                echo -e "${RED}✗ Prérequis manquant: ${pkg}${NC}"
                echo -e "${YELLOW}  Exécutez d'abord: ./common-setup.sh${NC}"
                ((errors++))
            fi
        done
    fi

    return $errors
}

# Export des fonctions pour utilisation par source
export -f load_kubernetes_config
export -f set_default_kubernetes_config
export -f validate_kubernetes_config
export -f validate_kubernetes_version
export -f validate_ip_address
export -f show_kubernetes_config
export -f get_k8s_major_minor
export -f get_master_count
export -f warn_missing_config
export -f validate_system_prerequisites
export -f validate_install_prerequisites
