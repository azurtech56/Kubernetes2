#!/bin/bash
################################################################################
# Script de configuration pour les nœuds Worker Kubernetes
# Compatible avec: Ubuntu 20.04/22.04/24.04
# Auteur: azurtech56
# Version: 2.0 - Idempotent
################################################################################

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Configuration Worker Kubernetes${NC}"
echo -e "${GREEN}========================================${NC}"

# Vérifier si l'utilisateur est root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Ce script doit être exécuté en tant que root${NC}"
   exit 1
fi

# Charger la configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Charger les bibliothèques v2.0
if [ -f "$SCRIPT_DIR/lib/idempotent.sh" ]; then
    source "$SCRIPT_DIR/lib/idempotent.sh"
    init_idempotent
fi

# Charger bibliothèques v2.1
if [ -f "$SCRIPT_DIR/lib/performance.sh" ]; then
    source "$SCRIPT_DIR/lib/performance.sh"
    init_cache
    start_timer "worker_setup"
fi

if [ -f "$SCRIPT_DIR/lib/dry-run.sh" ]; then
    source "$SCRIPT_DIR/lib/dry-run.sh"
    init_dry_run
fi

if [ -f "$SCRIPT_DIR/lib/notifications.sh" ]; then
    source "$SCRIPT_DIR/lib/notifications.sh"
    notify_install_start "Worker node"
fi

if [ -f "$SCRIPT_DIR/lib/error-codes.sh" ]; then
    source "$SCRIPT_DIR/lib/error-codes.sh"
fi

if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
else
    # Valeurs par défaut si config.sh n'existe pas
    CLUSTER_NODES_NETWORK="192.168.0.0/24"
    POD_NETWORK="11.0.0.0/16"
fi

echo -e "${YELLOW}[1/1] Configuration du firewall pour Worker...${NC}"
echo "  Réseau nœuds: ${CLUSTER_NODES_NETWORK}"
echo "  Réseau pods: ${POD_NETWORK}"

# Temporairement désactiver set -e pour les commandes UFW
set +e

if type -t setup_ufw_rule_idempotent &>/dev/null; then
    # Mode idempotent
    setup_ufw_rule_idempotent 22 tcp "SSH"
    setup_ufw_rule_idempotent 80 tcp "HTTP"
    setup_ufw_rule_idempotent 443 tcp "HTTPS"
    setup_ufw_rule_idempotent 9090 tcp "Prometheus"
    setup_ufw_rule_idempotent 9093 tcp "Alertmanager"
    setup_ufw_rule_idempotent 10250 tcp "Kubelet API"
    setup_ufw_rule_idempotent "30000:32767" tcp "NodePort Services"
    setup_ufw_network_rule_idempotent "${POD_NETWORK}" "from"
    setup_ufw_network_rule_idempotent "${POD_NETWORK}" "to"
    setup_ufw_network_rule_idempotent "${CLUSTER_NODES_NETWORK}" "from"
    enable_ufw_idempotent
else
    # Mode standard (fallback si lib-idempotent non disponible)
    ufw allow 22/tcp            # SSH (IMPORTANT!)
    ufw allow 80/tcp            # HTTP (LoadBalancer - Rancher, Grafana)
    ufw allow 443/tcp           # HTTPS (LoadBalancer - Rancher, Grafana)
    ufw allow 9090/tcp          # Prometheus
    ufw allow 9093/tcp          # Alertmanager
    ufw allow 10250/tcp         # Kubelet API
    ufw allow 30000:32767/tcp   # NodePort Services
    ufw allow from ${POD_NETWORK}  # Calico pod network
    ufw allow to ${POD_NETWORK}    # Calico pod network
    ufw allow from ${CLUSTER_NODES_NETWORK}  # Communication inter-nœuds
    ufw --force enable
    ufw reload
    echo -e "${GREEN}✓ Firewall configuré pour Worker${NC}"
fi

# Réactiver set -e pour les commandes suivantes
set -e

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Configuration Worker terminée !${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Prochaine étape:${NC}"
echo "  - Utilisez la commande 'kubeadm join' générée par le master"
echo "  - Exemple:"
echo "    sudo kubeadm join k8s:6443 --token <token> \\"
echo "        --discovery-token-ca-cert-hash sha256:<hash>"

# === v2.1 Performance & Notifications ===
if type -t stop_timer &>/dev/null; then
    stop_timer "worker_setup"
fi

if type -t notify_install_success &>/dev/null; then
    notify_install_success "Worker node"
fi

if type -t dry_run_summary &>/dev/null; then
    dry_run_summary
fi
# === Fin v2.1 ===
