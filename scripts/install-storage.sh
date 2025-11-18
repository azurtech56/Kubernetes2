#!/bin/bash
################################################################################
# Script d'installation du provisioner de stockage local-path
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
echo -e "${GREEN}  Installation Storage Provisioner${NC}"
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
    KUBECTL_WAIT_TIMEOUT_SHORT="180s"
    KUBECTL_WAIT_TIMEOUT_QUICK="90s"
fi

# Version de local-path-provisioner
STORAGE_VERSION="${STORAGE_PROVISIONER_VERSION:-v0.0.30}"
STORAGE_MANIFEST_URL="https://raw.githubusercontent.com/rancher/local-path-provisioner/${STORAGE_VERSION}/deploy/local-path-storage.yaml"

echo -e "${BLUE}Configuration:${NC}"
echo "  Version: ${STORAGE_VERSION}"
echo "  Manifest URL: ${STORAGE_MANIFEST_URL}"
echo ""

# Vérifier si local-path-provisioner est déjà installé
if kubectl get namespace local-path-storage &>/dev/null; then
    echo -e "${YELLOW}⚠ local-path-provisioner semble déjà installé${NC}"
    echo ""
    read -p "Voulez-vous réinstaller ? [y/N]: " reinstall
    if [[ ! $reinstall =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Installation annulée${NC}"
        exit 0
    fi
    echo -e "${YELLOW}Suppression de l'installation existante...${NC}"
    kubectl delete -f "${STORAGE_MANIFEST_URL}" --ignore-not-found=true
    echo -e "${GREEN}✓ Ancienne installation supprimée${NC}"
fi

echo -e "${YELLOW}[1/4] Installation de local-path-provisioner...${NC}"
if ! kubectl apply -f "${STORAGE_MANIFEST_URL}"; then
    echo -e "${RED}Erreur lors de l'installation${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Manifest appliqué${NC}"

echo -e "${YELLOW}[2/4] Attente du démarrage du provisioner...${NC}"
kubectl wait --for=condition=ready pod \
    -n local-path-storage \
    -l app=local-path-provisioner \
    --timeout=${KUBECTL_WAIT_TIMEOUT_SHORT} || {
    echo -e "${YELLOW}⚠ Timeout atteint, vérification manuelle...${NC}"
}

# Vérifier que le pod est bien démarré
POD_STATUS=$(kubectl get pods -n local-path-storage -l app=local-path-provisioner -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")

if [ "$POD_STATUS" = "Running" ]; then
    echo -e "${GREEN}✓ Provisioner démarré avec succès${NC}"
else
    echo -e "${YELLOW}⚠ Statut du pod: ${POD_STATUS}${NC}"
    echo -e "${BLUE}Logs du provisioner:${NC}"
    kubectl logs -n local-path-storage -l app=local-path-provisioner --tail=20 || true
fi

echo -e "${YELLOW}[3/4] Configuration de la StorageClass par défaut...${NC}"

# Vérifier si une StorageClass par défaut existe déjà
DEFAULT_SC=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}' 2>/dev/null || echo "")

if [ -n "$DEFAULT_SC" ] && [ "$DEFAULT_SC" != "local-path" ]; then
    echo -e "${YELLOW}⚠ Une StorageClass par défaut existe déjà: ${DEFAULT_SC}${NC}"
    read -p "Voulez-vous définir local-path comme StorageClass par défaut ? [y/N]: " set_default
    if [[ $set_default =~ ^[Yy]$ ]]; then
        # Retirer l'annotation de l'ancienne StorageClass par défaut
        kubectl patch storageclass "${DEFAULT_SC}" -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' || true
        # Définir local-path comme par défaut
        kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
        echo -e "${GREEN}✓ local-path défini comme StorageClass par défaut${NC}"
    else
        echo -e "${YELLOW}⚠ local-path ne sera pas la StorageClass par défaut${NC}"
    fi
else
    # Aucune StorageClass par défaut, on définit local-path
    kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' 2>/dev/null || {
        echo -e "${YELLOW}⚠ Impossible de définir local-path comme par défaut (peut-être déjà défini)${NC}"
    }
    echo -e "${GREEN}✓ local-path défini comme StorageClass par défaut${NC}"
fi

echo -e "${YELLOW}[4/4] Vérification de l'installation...${NC}"

# Afficher les StorageClass
echo -e "${BLUE}StorageClasses disponibles:${NC}"
kubectl get storageclass

echo ""
echo -e "${BLUE}Pods du provisioner:${NC}"
kubectl get pods -n local-path-storage

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Installation terminée !${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Informations utiles
echo -e "${BLUE}Informations:${NC}"
echo "  - Namespace: local-path-storage"
echo "  - StorageClass: local-path"
echo "  - Chemin de stockage par défaut: /opt/local-path-provisioner"
echo "  - Politique de réclamation: Delete"
echo "  - Mode de liaison: WaitForFirstConsumer"
echo ""

echo -e "${BLUE}Exemple d'utilisation:${NC}"
cat << 'EOF'

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 10Gi
EOF

echo ""
echo -e "${YELLOW}💡 Conseil:${NC} Les PersistentVolumeClaims utiliseront automatiquement"
echo "   la StorageClass 'local-path' si elle est définie par défaut."
echo ""
echo -e "${GREEN}✓ Le stockage persistant est maintenant disponible !${NC}"
