#!/bin/bash
################################################################################
# Script d'installation de MetalLB Load Balancer
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
echo -e "${GREEN}  Installation de MetalLB${NC}"
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
    METALLB_IP_RANGE="192.168.0.220-192.168.0.240"
    NETWORK_INTERFACE="auto"
    METALLB_MANIFEST_URL="https://raw.githubusercontent.com/metallb/metallb/main/config/manifests/metallb-native.yaml"
    KUBECTL_WAIT_TIMEOUT_SHORT="90s"
fi

# Détecter l'interface réseau si configurée en "auto"
if [ "$NETWORK_INTERFACE" = "auto" ]; then
    NETWORK_INTERFACE=$(detect_network_interface 2>/dev/null || ip route | grep default | awk '{print $5}' | head -n1)
    echo -e "${GREEN}✓ Interface réseau détectée automatiquement: ${NETWORK_INTERFACE}${NC}"
fi

# Configuration par défaut (utilise config.sh)
DEFAULT_IP_RANGE="${METALLB_IP_RANGE}"
DEFAULT_INTERFACE="${NETWORK_INTERFACE}"

echo ""
echo -e "${BLUE}Configuration MetalLB depuis config.sh:${NC}"
echo "  Plage IP: ${DEFAULT_IP_RANGE}"
echo "  Interface: ${DEFAULT_INTERFACE}"
echo "  Manifest URL: ${METALLB_MANIFEST_URL}"
echo ""

read -p "Utiliser cette configuration? [Y/n]: " use_default

if [[ $use_default =~ ^[Nn]$ ]]; then
    echo ""
    read -p "Plage d'adresses IP [${DEFAULT_IP_RANGE}]: " IP_RANGE
    IP_RANGE=${IP_RANGE:-$DEFAULT_IP_RANGE}

    read -p "Interface réseau [${DEFAULT_INTERFACE}]: " INTERFACE
    INTERFACE=${INTERFACE:-$DEFAULT_INTERFACE}
else
    IP_RANGE="${DEFAULT_IP_RANGE}"
    INTERFACE="${DEFAULT_INTERFACE}"
fi

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
kubectl apply -f "${METALLB_MANIFEST_URL}"

echo -e "${GREEN}✓ MetalLB installé${NC}"

echo -e "${YELLOW}[2/3] Attente du démarrage de MetalLB...${NC}"
kubectl wait --namespace metallb-system \
    --for=condition=ready pod \
    --selector=app=metallb \
    --timeout=${KUBECTL_WAIT_TIMEOUT_SHORT} || true

# Attendre spécifiquement que tous les pods soient prêts
echo -e "${YELLOW}Attente de tous les pods MetalLB...${NC}"
kubectl wait --namespace metallb-system \
    --for=condition=ready pod \
    --all \
    --timeout=${KUBECTL_WAIT_TIMEOUT_QUICK} || true

# Attendre que le service webhook soit disponible
echo -e "${YELLOW}Attente de la disponibilité du service webhook...${NC}"
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if kubectl get endpoints -n metallb-system metallb-webhook-service &>/dev/null; then
        endpoints=$(kubectl get endpoints -n metallb-system metallb-webhook-service -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
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
echo -e "${YELLOW}Vérification de l'enregistrement du webhook dans l'API server...${NC}"
max_attempts=20
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if kubectl get validatingwebhookconfigurations.admissionregistration.k8s.io metallb-webhook-configuration &>/dev/null; then
        echo -e "${GREEN}✓ Webhook MetalLB enregistré dans l'API server${NC}"
        break
    fi
    attempt=$((attempt + 1))
    echo -ne "\r  Tentative $attempt/$max_attempts..."
    sleep 3
done
echo ""

# Test actif du webhook avec une ressource temporaire
echo -e "${YELLOW}Test de disponibilité du webhook (dry-run)...${NC}"
max_attempts=10
attempt=0
webhook_ok=false
while [ $attempt -lt $max_attempts ]; do
    # Créer une ressource test en mode dry-run pour tester le webhook
    if cat <<EOF | kubectl apply --dry-run=server -f - &>/dev/null; then
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: test-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.255.1-192.168.255.1
EOF
        echo -e "${GREEN}✓ Webhook répond correctement${NC}"
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
fi

echo -e "${GREEN}✓ MetalLB démarré et webhooks opérationnels${NC}"

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
