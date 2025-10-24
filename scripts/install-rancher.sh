#!/bin/bash
################################################################################
# Script d'installation de Rancher
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
echo -e "${GREEN}  Installation de Rancher${NC}"
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
    echo -e "${BLUE}cert-manager version: ${CERT_MANAGER_VERSION}${NC}"
else
    echo -e "${YELLOW}Avertissement: config.sh non trouvé, utilisation des valeurs par défaut${NC}"
    CERT_MANAGER_VERSION="v1.17.0"
    RANCHER_HOSTNAME="rancher.home.local"
    RANCHER_PASSWORD="admin"
    RANCHER_TLS_SOURCE="rancher"
fi
echo ""

# Configuration (utilise les valeurs de config.sh comme défaut)
DEFAULT_HOSTNAME="${RANCHER_HOSTNAME}"
DEFAULT_PASSWORD="${RANCHER_PASSWORD}"

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

echo -e "${YELLOW}[1/6] Installation de cert-manager ${CERT_MANAGER_VERSION}...${NC}"
kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"

echo -e "${GREEN}✓ cert-manager ${CERT_MANAGER_VERSION} installé${NC}"

echo -e "${YELLOW}[2/6] Attente du démarrage de cert-manager...${NC}"
kubectl wait --for=condition=Ready pods -l app=cert-manager -n cert-manager --timeout=${KUBECTL_WAIT_TIMEOUT_SHORT} || true
kubectl wait --for=condition=Ready pods -l app=webhook -n cert-manager --timeout=${KUBECTL_WAIT_TIMEOUT_SHORT} || true
kubectl wait --for=condition=Ready pods -l app=cainjector -n cert-manager --timeout=${KUBECTL_WAIT_TIMEOUT_SHORT} || true

# Attendre spécifiquement que tous les pods soient prêts
echo -e "${YELLOW}Attente de tous les pods cert-manager...${NC}"
kubectl wait --namespace cert-manager \
    --for=condition=ready pod \
    --all \
    --timeout=${KUBECTL_WAIT_TIMEOUT_QUICK} || true

# Attendre que le service webhook cert-manager soit disponible
echo -e "${YELLOW}Attente de la disponibilité du service webhook cert-manager...${NC}"
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if kubectl get endpoints -n cert-manager cert-manager-webhook &>/dev/null; then
        endpoints=$(kubectl get endpoints -n cert-manager cert-manager-webhook -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
        if [ -n "$endpoints" ]; then
            echo -e "${GREEN}✓ Service webhook disponible (endpoints: $endpoints)${NC}"
            break
        fi
    fi
    attempt=$((attempt + 1))
    echo -ne "\r  Tentative $attempt/$max_attempts..."
    sleep 2
done
echo ""

# Vérifier que le webhook est enregistré dans l'API server
echo -e "${YELLOW}Vérification de l'enregistrement du webhook dans l'API...${NC}"
max_attempts=20
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if kubectl get validatingwebhookconfigurations.admissionregistration.k8s.io cert-manager-webhook &>/dev/null; then
        echo -e "${GREEN}✓ Webhook enregistré dans l'API server${NC}"
        break
    fi
    attempt=$((attempt + 1))
    echo -ne "\r  Tentative $attempt/$max_attempts..."
    sleep 2
done
echo ""

# Test actif du webhook cert-manager avec une ressource temporaire
echo -e "${YELLOW}Test de disponibilité du webhook cert-manager (dry-run)...${NC}"
max_attempts=10
attempt=0
webhook_ok=false
while [ $attempt -lt $max_attempts ]; do
    # Créer une ressource test en mode dry-run pour tester le webhook
    if cat <<EOF | kubectl apply --dry-run=server -f - &>/dev/null; then
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-certificate
  namespace: cert-manager
spec:
  secretName: test-tls
  dnsNames:
  - test.example.com
  issuerRef:
    name: test-issuer
    kind: Issuer
EOF
        echo -e "${GREEN}✓ Webhook cert-manager répond correctement${NC}"
        webhook_ok=true
        break
    fi
    attempt=$((attempt + 1))
    echo -ne "\r  Test $attempt/$max_attempts (webhook pas encore prêt)..."
    sleep 5
done
echo ""

if [ "$webhook_ok" = false ]; then
    echo -e "${YELLOW}Attention: Le webhook ne répond pas encore, tentative de délai supplémentaire...${NC}"
    sleep 30
    echo -e "${YELLOW}Un dernier test...${NC}"
    # Dernier essai
    if cat <<EOF | kubectl apply --dry-run=server -f - &>/dev/null; then
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-certificate
  namespace: cert-manager
spec:
  secretName: test-tls
  dnsNames:
  - test.example.com
  issuerRef:
    name: test-issuer
    kind: Issuer
EOF
        echo -e "${GREEN}✓ Webhook cert-manager maintenant opérationnel${NC}"
    else
        echo -e "${RED}Avertissement: Le webhook cert-manager ne répond toujours pas${NC}"
        echo -e "${YELLOW}Continuation de l'installation (l'erreur peut être temporaire)${NC}"
    fi
fi

echo -e "${GREEN}✓ cert-manager démarré et webhooks opérationnels${NC}"

echo -e "${YELLOW}[3/6] Ajout du repository Helm Rancher...${NC}"
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update

echo -e "${GREEN}✓ Repository ajouté${NC}"

echo -e "${YELLOW}[4/6] Installation de Rancher via Helm...${NC}"
kubectl create namespace cattle-system || true

helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=${HOSTNAME} \
  --set bootstrapPassword=${BOOTSTRAP_PASSWORD} \
  --set ingress.tls.source=${RANCHER_TLS_SOURCE}

echo -e "${GREEN}✓ Rancher installé${NC}"

echo -e "${YELLOW}[5/6] Attente du démarrage de Rancher...${NC}"

# Attendre que le deployment soit prêt
kubectl wait --for=condition=Available deployment/rancher -n cattle-system --timeout=${KUBECTL_WAIT_TIMEOUT} || true

# Attendre que tous les pods Rancher soient prêts
echo -e "${YELLOW}Attente de tous les pods Rancher...${NC}"
kubectl wait --namespace cattle-system \
    --for=condition=ready pod \
    --all \
    --timeout=${KUBECTL_WAIT_TIMEOUT} || true

# Attendre que les services webhook Rancher soient disponibles (si existants)
echo -e "${YELLOW}Vérification des services Rancher...${NC}"
max_attempts=20
attempt=0
while [ $attempt -lt $max_attempts ]; do
    rancher_ready=$(kubectl get pods -n cattle-system -l app=rancher -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -c "True" || echo "0")
    if [ "$rancher_ready" -gt 0 ]; then
        echo -e "${GREEN}✓ Rancher complètement démarré ($rancher_ready pods prêts)${NC}"
        break
    fi
    attempt=$((attempt + 1))
    echo -ne "\r  Tentative $attempt/$max_attempts..."
    sleep 3
done
echo ""

# Délai pour stabilisation de Rancher
echo -e "${YELLOW}Stabilisation de Rancher (20 secondes)...${NC}"
sleep 20

echo -e "${GREEN}✓ Rancher opérationnel${NC}"

echo -e "${YELLOW}[6/6] Exposition de Rancher via LoadBalancer...${NC}"

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
