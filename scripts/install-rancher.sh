#!/bin/bash
################################################################################
# Script d'installation de Rancher
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
echo -e "${GREEN}  Installation de Rancher${NC}"
echo -e "${GREEN}========================================${NC}"

# Configuration
DEFAULT_HOSTNAME="rancher.home.local"
DEFAULT_PASSWORD="admin"

echo -e "${BLUE}Configuration Rancher:${NC}"
echo ""
read -p "Hostname Rancher [${DEFAULT_HOSTNAME}]: " HOSTNAME
HOSTNAME=${HOSTNAME:-$DEFAULT_HOSTNAME}

read -p "Mot de passe bootstrap [${DEFAULT_PASSWORD}]: " BOOTSTRAP_PASSWORD
BOOTSTRAP_PASSWORD=${BOOTSTRAP_PASSWORD:-$DEFAULT_PASSWORD}

echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Hostname: ${HOSTNAME}"
echo "  Password: ${BOOTSTRAP_PASSWORD}"
echo ""
read -p "Confirmer? [y/N]: " confirm

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${RED}Installation annulée${NC}"
    exit 1
fi

echo -e "${YELLOW}[1/5] Installation de cert-manager...${NC}"
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.0/cert-manager.yaml

echo -e "${GREEN}✓ cert-manager installé${NC}"

echo -e "${YELLOW}[2/5] Attente du démarrage de cert-manager...${NC}"
kubectl wait --for=condition=Ready pods -l app=cert-manager -n cert-manager --timeout=180s || true
kubectl wait --for=condition=Ready pods -l app=webhook -n cert-manager --timeout=180s || true
kubectl wait --for=condition=Ready pods -l app=cainjector -n cert-manager --timeout=180s || true

echo -e "${GREEN}✓ cert-manager démarré${NC}"

echo -e "${YELLOW}[3/5] Ajout du repository Helm Rancher...${NC}"
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update

echo -e "${GREEN}✓ Repository ajouté${NC}"

echo -e "${YELLOW}[4/5] Installation de Rancher via Helm...${NC}"
kubectl create namespace cattle-system || true

helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=${HOSTNAME} \
  --set bootstrapPassword=${BOOTSTRAP_PASSWORD} \
  --set ingress.tls.source=rancher

echo -e "${GREEN}✓ Rancher installé${NC}"

echo -e "${YELLOW}[5/5] Exposition de Rancher via LoadBalancer...${NC}"

# Attendre que le deployment soit prêt
kubectl wait --for=condition=Available deployment/rancher -n cattle-system --timeout=300s || true

kubectl expose deployment rancher \
  --type=LoadBalancer \
  --name=rancher-lb \
  --namespace=cattle-system \
  --port=80 \
  --target-port=80 || echo "Service HTTP déjà existant"

kubectl expose deployment rancher \
  --type=LoadBalancer \
  --name=rancher-lb-https \
  --namespace=cattle-system \
  --port=443 \
  --target-port=443 || echo "Service HTTPS déjà existant"

echo -e "${GREEN}✓ Services LoadBalancer créés${NC}"

echo ""
echo -e "${YELLOW}Récupération du mot de passe...${NC}"
sleep 5
PASSWORD=$(kubectl get secret --namespace cattle-system bootstrap-secret -o jsonpath="{.data.bootstrapPassword}" 2>/dev/null | base64 -d || echo "${BOOTSTRAP_PASSWORD}")

echo ""
echo -e "${YELLOW}Informations de connexion:${NC}"
kubectl get svc -n cattle-system | grep rancher-lb

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Rancher installé avec succès !${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Connexion à Rancher:${NC}"
echo "  URL: https://${HOSTNAME}"
echo "  Identifiant: admin"
echo "  Mot de passe: ${PASSWORD}"
echo ""
echo -e "${YELLOW}Note: Ajoutez l'IP du LoadBalancer dans votre /etc/hosts:${NC}"
echo "  <IP_LOADBALANCER> ${HOSTNAME}"
echo ""
echo -e "${YELLOW}Vérification des pods:${NC}"
kubectl get pods -n cattle-system
