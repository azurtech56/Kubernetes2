#!/bin/bash
################################################################################
# Script d'installation de MetalLB Load Balancer
# Compatible avec: Kubernetes 1.32
# Auteur: azurtech56
# Version: 1.0
################################################################################

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Installation de MetalLB${NC}"
echo -e "${GREEN}========================================${NC}"

# Configuration par défaut
DEFAULT_IP_RANGE="192.168.0.210-192.168.0.230"
DEFAULT_INTERFACE="ens33"

echo -e "${BLUE}Configuration MetalLB:${NC}"
echo ""
read -p "Plage d'adresses IP [${DEFAULT_IP_RANGE}]: " IP_RANGE
IP_RANGE=${IP_RANGE:-$DEFAULT_IP_RANGE}

read -p "Interface réseau [${DEFAULT_INTERFACE}]: " INTERFACE
INTERFACE=${INTERFACE:-$DEFAULT_INTERFACE}

echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Plage IP: ${IP_RANGE}"
echo "  Interface: ${INTERFACE}"
echo ""
read -p "Confirmer? [y/N]: " confirm

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${RED}Installation annulée${NC}"
    exit 1
fi

echo -e "${YELLOW}[1/3] Installation de MetalLB...${NC}"
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/config/manifests/metallb-native.yaml

echo -e "${GREEN}✓ MetalLB installé${NC}"

echo -e "${YELLOW}[2/3] Attente du démarrage de MetalLB...${NC}"
kubectl wait --namespace metallb-system \
    --for=condition=ready pod \
    --selector=app=metallb \
    --timeout=90s || true

echo -e "${GREEN}✓ MetalLB démarré${NC}"

echo -e "${YELLOW}[3/3] Configuration de MetalLB...${NC}"

cat > metallb-config.yaml <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: external-ips
  namespace: metallb-system
spec:
  addresses:
  - ${IP_RANGE}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: external-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - external-ips
  interfaces:
  - ${INTERFACE}
EOF

kubectl apply -f metallb-config.yaml

echo -e "${GREEN}✓ MetalLB configuré${NC}"

echo ""
echo -e "${YELLOW}Vérification de l'installation:${NC}"
kubectl get pods -n metallb-system
echo ""
kubectl get ipaddresspools.metallb.io -n metallb-system
kubectl get l2advertisements.metallb.io -n metallb-system

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  MetalLB installé avec succès !${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Test:${NC}"
echo "  kubectl create deployment nginx --image=nginx"
echo "  kubectl expose deployment nginx --port=80 --type=LoadBalancer"
echo "  kubectl get svc nginx"
