#!/bin/bash
################################################################################
# Script d'installation de Calico CNI
# Compatible avec: Kubernetes 1.32.2
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
echo -e "${GREEN}  Installation de Calico CNI${NC}"
echo -e "${GREEN}========================================${NC}"

# Charger la configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    echo -e "${BLUE}Chargement de la configuration depuis config.sh...${NC}"
    source "$SCRIPT_DIR/config.sh"
else
    echo -e "${YELLOW}Avertissement: config.sh non trouvé, utilisation des valeurs par défaut${NC}"
    CALICO_VERSION="latest"
    CALICO_MANIFEST_URL="https://docs.projectcalico.org/manifests/calico.yaml"
    KUBECTL_WAIT_TIMEOUT="300s"
fi

echo -e "${BLUE}Version Calico: ${CALICO_VERSION}${NC}"
echo -e "${BLUE}Manifest URL: ${CALICO_MANIFEST_URL}${NC}"
echo ""

echo -e "${YELLOW}[1/2] Téléchargement et application du manifest Calico...${NC}"
kubectl apply -f "${CALICO_MANIFEST_URL}"

echo -e "${GREEN}✓ Manifest Calico appliqué${NC}"

echo -e "${YELLOW}[2/2] Attente du démarrage des pods Calico...${NC}"
echo "Cela peut prendre quelques minutes..."

# Attendre que les pods calico soient prêts
kubectl wait --for=condition=Ready pods -l k8s-app=calico-node -n kube-system --timeout=${KUBECTL_WAIT_TIMEOUT} || true
kubectl wait --for=condition=Ready pods -l k8s-app=calico-kube-controllers -n kube-system --timeout=${KUBECTL_WAIT_TIMEOUT} || true

echo -e "${GREEN}✓ Calico démarré${NC}"

echo ""
echo -e "${YELLOW}Vérification de l'installation:${NC}"
kubectl get pods -n kube-system | grep calico
echo ""
kubectl get nodes

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Calico installé avec succès !${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Les nœuds devraient maintenant être en état 'Ready'${NC}"
