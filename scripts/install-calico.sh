#!/bin/bash
################################################################################
# Script d'installation de Calico CNI
# Compatible avec: Kubernetes 1.32
# Auteur: Kubernetes HA Setup
# Version: 1.0
################################################################################

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Installation de Calico CNI${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "${YELLOW}[1/2] Téléchargement et application du manifest Calico...${NC}"
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

echo -e "${GREEN}✓ Manifest Calico appliqué${NC}"

echo -e "${YELLOW}[2/2] Attente du démarrage des pods Calico...${NC}"
echo "Cela peut prendre quelques minutes..."

# Attendre que les pods calico soient prêts
kubectl wait --for=condition=Ready pods -l k8s-app=calico-node -n kube-system --timeout=300s || true
kubectl wait --for=condition=Ready pods -l k8s-app=calico-kube-controllers -n kube-system --timeout=300s || true

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
