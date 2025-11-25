#!/bin/bash
################################################################################
# Installation et Configuration de Sealed Secrets
# Chiffrage automatique des secrets Kubernetes pour GitOps
# Auteur: Claude Code
# Version: 1.0
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# VÉRIFICATIONS INITIALES
# ============================================================================

show_header() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  INSTALLATION SEALED SECRETS - GitOps Security${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Vérifier si root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Ce script doit être exécuté en tant que root${NC}"
    exit 1
fi

# Vérifier kubectl disponible
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl non trouvé${NC}"
    exit 1
fi

# Vérifier cluster accessible
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}✗ Cluster Kubernetes non accessible${NC}"
    exit 1
fi

show_header

# ============================================================================
# INSTALLATION SEALED SECRETS
# ============================================================================

echo -e "${YELLOW}[1/3] Ajout du repository Helm Sealed Secrets...${NC}"
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update
echo -e "${GREEN}✓ Repository ajouté${NC}"
echo ""

echo -e "${YELLOW}[2/3] Installation du controller Sealed Secrets...${NC}"
helm install sealed-secrets sealed-secrets/sealed-secrets \
    -n kube-system \
    --set commandArgs="{--update-status=true,--key-rotation-period=30d}" \
    --wait \
    --timeout=300s

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Sealed Secrets installé${NC}"
else
    echo -e "${RED}✗ Erreur installation${NC}"
    exit 1
fi
echo ""

echo -e "${YELLOW}[3/3] Vérification du deployment...${NC}"
sleep 5

if kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets &>/dev/null; then
    echo -e "${GREEN}✓ Pod sealed-secrets est running${NC}"
else
    echo -e "${RED}✗ Pod sealed-secrets non trouvé${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ Sealed Secrets installé avec succès !${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BLUE}Usage - Créer et chiffrer un secret:${NC}"
echo ""
echo -e "${CYAN}# 1. Créer un secret normal:${NC}"
echo "kubectl create secret generic keepalived \\"
echo "    --from-literal=password='monmotdepasse' \\"
echo "    -n kube-system \\"
echo "    --dry-run=client -o yaml > secret.yaml"
echo ""
echo -e "${CYAN}# 2. Sceller le secret (chiffrer):${NC}"
echo "kubeseal -f secret.yaml -w sealed-secret.yaml"
echo ""
echo -e "${CYAN}# 3. Commiter sealed-secret.yaml (SAFE):${NC}"
echo "git add sealed-secret.yaml"
echo "git commit -m 'Add sealed secret'"
echo ""
echo -e "${CYAN}# 4. En production, appliquer:${NC}"
echo "kubectl apply -f sealed-secret.yaml"
echo "# → Sealed Secrets controller déchiffre automatiquement"
echo ""

echo -e "${BLUE}Secrets à créer et chiffrer:${NC}"
echo "  1. keepalived (VRRP_PASSWORD)"
echo "  2. rancher (RANCHER_PASSWORD)"
echo "  3. grafana (GRAFANA_PASSWORD)"
echo ""

echo -e "${YELLOW}Documentation complète:${NC}"
echo "https://github.com/bitnami-labs/sealed-secrets"
echo ""
