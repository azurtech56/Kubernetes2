#!/bin/bash
################################################################################
# Script de configuration pour les nœuds Master Kubernetes
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
echo -e "${GREEN}  Configuration Master Kubernetes${NC}"
echo -e "${GREEN}========================================${NC}"

# Vérifier si l'utilisateur est root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Ce script doit être exécuté en tant que root${NC}"
   exit 1
fi

echo -e "${YELLOW}[1/3] Configuration du firewall pour Master...${NC}"
ufw allow 22/tcp        # SSH (IMPORTANT!)
ufw allow 6443/tcp      # Kubernetes API server
ufw allow 2379/tcp      # etcd client
ufw allow 2380/tcp      # etcd peer
ufw allow 10250/tcp     # Kubelet API
ufw allow 10251/tcp     # kube-scheduler
ufw allow 10252/tcp     # kube-controller-manager
ufw allow 10255/tcp     # Read-only Kubelet API
ufw allow from any to any proto vrrp    # keepalived VRRP
ufw --force enable
ufw reload
echo -e "${GREEN}✓ Firewall configuré pour Master${NC}"

echo -e "${YELLOW}[2/3] Installation de keepalived...${NC}"
apt update
apt install -y keepalived
systemctl enable keepalived
echo -e "${GREEN}✓ keepalived installé${NC}"

echo -e "${YELLOW}[3/3] Installation de Helm...${NC}"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
echo -e "${GREEN}✓ Helm installé${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Configuration Master terminée !${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Prochaines étapes:${NC}"
echo "  1. Configurer keepalived avec setup-keepalived.sh"
echo "  2. Sur le premier master uniquement: exécutez init-cluster.sh"
echo "  3. Sur les autres masters: utilisez la commande kubeadm join générée"
