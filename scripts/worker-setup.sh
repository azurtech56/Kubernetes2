#!/bin/bash
################################################################################
# Script de configuration pour les nœuds Worker Kubernetes
# Compatible avec: Ubuntu 20.04/22.04/24.04
# Auteur: azurtech56
# Version: 1.0
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

echo -e "${YELLOW}[1/1] Configuration du firewall pour Worker...${NC}"
ufw allow 10250/tcp         # Kubelet API
ufw allow 30000:32767/tcp   # NodePort Services
ufw --force enable
ufw reload
echo -e "${GREEN}✓ Firewall configuré pour Worker${NC}"

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
