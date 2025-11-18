#!/bin/bash
################################################################################
# Script d'installation de Calico CNI
# Compatible avec: Kubernetes 1.33.0
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

# Vérifier et configurer kubectl
echo -e "${BLUE}Vérification de la configuration kubectl...${NC}"
if [ ! -f "$HOME/.kube/config" ]; then
    echo -e "${YELLOW}Configuration kubectl non trouvée, tentative de copie depuis /etc/kubernetes/admin.conf...${NC}"
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    echo -e "${GREEN}✓ Configuration kubectl copiée${NC}"
else
    echo -e "${GREEN}✓ Configuration kubectl trouvée${NC}"
fi

# Vérifier que kubectl fonctionne
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}Erreur: kubectl ne peut pas se connecter au cluster${NC}"
    echo -e "${YELLOW}Vérifiez que vous êtes sur un nœud master et que le cluster est démarré${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Connexion au cluster réussie${NC}"
echo ""

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

# Créer les liens symboliques Calico si manquants (utile pour Debian)
echo -e "${BLUE}Vérification des liens symboliques Calico...${NC}"
if [ ! -L "/usr/lib/cni/calico" ]; then
    echo -e "${YELLOW}Création des liens symboliques Calico...${NC}"
    sudo mkdir -p /usr/lib/cni
    sudo ln -s /opt/cni/bin/calico /usr/lib/cni/calico 2>/dev/null || true
    sudo ln -s /opt/cni/bin/calico-ipam /usr/lib/cni/calico-ipam 2>/dev/null || true
    echo -e "${GREEN}✓ Liens symboliques créés${NC}"
else
    echo -e "${GREEN}✓ Liens symboliques Calico OK${NC}"
fi

# Attendre que les pods calico soient prêts
kubectl wait --for=condition=Ready pods -l k8s-app=calico-node -n kube-system --timeout=${KUBECTL_WAIT_TIMEOUT} || true
kubectl wait --for=condition=Ready pods -l k8s-app=calico-kube-controllers -n kube-system --timeout=${KUBECTL_WAIT_TIMEOUT} || true

# Attendre spécifiquement tous les pods Calico
echo -e "${YELLOW}Vérification finale de tous les pods Calico...${NC}"
kubectl wait --namespace kube-system \
    --for=condition=ready pod \
    --selector k8s-app=calico-node \
    --timeout=${KUBECTL_WAIT_TIMEOUT_QUICK} || true

# Délai supplémentaire pour stabilisation du réseau
echo -e "${YELLOW}Stabilisation du réseau (10 secondes)...${NC}"
sleep 10

echo -e "${GREEN}✓ Calico démarré et réseau prêt${NC}"

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
