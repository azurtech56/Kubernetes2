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
if [ -f "$SCRIPT_DIR/../lib/idempotent.sh" ]; then
    source "$SCRIPT_DIR/../lib/idempotent.sh"
    init_idempotent
fi

# Charger bibliothèques v2.1
if [ -f "$SCRIPT_DIR/../lib/performance.sh" ]; then
    source "$SCRIPT_DIR/../lib/performance.sh"
    init_cache
    start_timer "worker_setup"
fi

if [ -f "$SCRIPT_DIR/../lib/dry-run.sh" ]; then
    source "$SCRIPT_DIR/../lib/dry-run.sh"
    init_dry_run
fi

if [ -f "$SCRIPT_DIR/../lib/notifications.sh" ]; then
    source "$SCRIPT_DIR/../lib/notifications.sh"
    notify_install_start "Worker node"
fi

if [ -f "$SCRIPT_DIR/../lib/error-codes.sh" ]; then
    source "$SCRIPT_DIR/../lib/error-codes.sh"
fi

# Charger bibliothèque des règles firewall
if [ -f "$SCRIPT_DIR/../lib/firewall-rules.sh" ]; then
    source "$SCRIPT_DIR/../lib/firewall-rules.sh"
fi

# Charger et valider la configuration
if [ -f "$SCRIPT_DIR/../lib-config.sh" ]; then
    source "$SCRIPT_DIR/../lib-config.sh"

    # Charger configuration avec validation
    if ! load_kubernetes_config "$SCRIPT_DIR"; then
        echo -e "${RED}✗ Erreur: Configuration invalide ou incomplète${NC}"
        exit 1
    fi

    # Vérifier prérequis installation
    if ! validate_install_prerequisites "worker-setup.sh"; then
        echo -e "${RED}✗ Prérequis non satisfaits${NC}"
        echo -e "${YELLOW}Exécutez d'abord: ./common-setup.sh${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Erreur: lib-config.sh manquant${NC}"
    exit 1
fi

echo -e "${YELLOW}[1/1] Configuration du firewall pour Worker...${NC}"
echo "  Réseau nœuds: ${CLUSTER_NODES_NETWORK}"
echo "  Réseau pods: ${POD_NETWORK}"

# Temporairement désactiver set -e pour les commandes UFW (peuvent échouer si UFW non installé)
set +e

if type -t configure_worker_firewall &>/dev/null; then
    configure_worker_firewall "${POD_NETWORK}" "${CLUSTER_NODES_NETWORK}"
    enable_firewall
else
    echo -e "${YELLOW}⚠ lib/firewall-rules.sh non disponible${NC}"
fi

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
