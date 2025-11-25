#!/bin/bash
################################################################################
# Installation de Cilium - CNI haute performance avec eBPF
# Alternative à Calico pour L7 policies et observabilité avancée
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
    echo -e "${BLUE}  INSTALLATION CILIUM - eBPF Networking${NC}"
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

# Vérifier helm disponible
if ! command -v helm &> /dev/null; then
    echo -e "${RED}✗ helm non trouvé${NC}"
    exit 1
fi

# Charger config et performance lib
if [ -f "$SCRIPT_DIR/lib-config.sh" ]; then
    source "$SCRIPT_DIR/lib-config.sh"
    load_kubernetes_config "$SCRIPT_DIR" || exit 1
fi

if [ -f "$SCRIPT_DIR/lib/performance.sh" ]; then
    source "$SCRIPT_DIR/lib/performance.sh"
fi

show_header

# ============================================================================
# VÉRIFICATIONS PRÉREQUIS
# ============================================================================

echo -e "${YELLOW}Vérification des prérequis Cilium...${NC}"

# Vérifier version Kubernetes
K8S_VERSION=$(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}' | sed 's/v//g')
echo -e "${BLUE}  Kubernetes version: $K8S_VERSION${NC}"

# Vérifier kernel version (minimum 5.8 pour eBPF)
KERNEL_VERSION=$(uname -r | cut -d'.' -f1,2)
echo -e "${BLUE}  Kernel version: $(uname -r)${NC}"

if (( $(echo "$KERNEL_VERSION < 5.8" | bc -l) )); then
    echo -e "${YELLOW}⚠ Attention: Kernel < 5.8 détecté${NC}"
    echo -e "${YELLOW}  Cilium nécessite kernel >= 5.8 pour eBPF complet${NC}"
    echo -e "${YELLOW}  Installation continuera mais avec fonctionnalités limitées${NC}"
fi

echo ""

# ============================================================================
# AJOUT REPOSITORY HELM
# ============================================================================

echo -e "${YELLOW}[1/5] Ajout du repository Helm Cilium...${NC}"

helm repo add cilium https://helm.cilium.io
helm repo update

echo -e "${GREEN}✓ Repository Cilium ajouté${NC}"
echo ""

# ============================================================================
# CRÉATION NAMESPACE
# ============================================================================

echo -e "${YELLOW}[2/5] Création du namespace cilium...${NC}"

kubectl create namespace cilium --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✓ Namespace cilium créé${NC}"
echo ""

# ============================================================================
# INSTALLATION CILIUM
# ============================================================================

echo -e "${YELLOW}[3/5] Installation de Cilium...${NC}"

# Créer values pour Cilium
cat > /tmp/cilium-values.yaml <<'EOF'
# Global settings
debug: false
logSystemLoad: false

# eBPF configuration
ebpf:
  enabled: true

# Networking
tunnel: vxlan  # ou geneve, disabled pour native routing

# Service mesh
serviceMap: true
identityAllocationMode: crd

# Monitoring
prometheus:
  enabled: true
  port: 9090

# Network Policies
networkPolicy: true
policyEnforcementMode: default  # ou always pour strict

# Hubble observability
hubble:
  enabled: true
  ui:
    enabled: true
    port: 8081
  metrics:
    enabled: true
    port: 6100

# Resources
resources:
  limits:
    cpu: 1000m
    memory: 1024Mi
  requests:
    cpu: 100m
    memory: 128Mi

# Node selector (optionnel)
nodeSelector: {}

# Tolerations
tolerations: []
EOF

helm install cilium cilium/cilium \
    -n cilium \
    -f /tmp/cilium-values.yaml \
    --set image.tag=latest \
    --set ipam.mode=cluster-pool \
    --set ipam.operator.clusterPoolIPv4PodCIDR="${POD_NETWORK:-11.0.0.0/16}" \
    --wait \
    --timeout=300s

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Cilium installé${NC}"
else
    echo -e "${RED}✗ Erreur installation Cilium${NC}"
    exit 1
fi
echo ""

# ============================================================================
# INSTALLATION CILIUM CLI
# ============================================================================

echo -e "${YELLOW}[4/5] Installation de Cilium CLI...${NC}"

if ! command -v cilium &> /dev/null; then
    CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/master/stable.txt)
    CLI_ARCH=amd64
    if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi

    curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
    sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
    sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
    rm cilium-linux-${CLI_ARCH}.tar.gz*

    echo -e "${GREEN}✓ Cilium CLI installé${NC}"
else
    echo -e "${GREEN}✓ Cilium CLI déjà présent${NC}"
fi
echo ""

# ============================================================================
# VÉRIFICATION
# ============================================================================

echo -e "${YELLOW}[5/5] Vérification du déploiement...${NC}"
sleep 5

cilium status

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Cilium est opérationnel${NC}"
else
    echo -e "${YELLOW}⚠ Cilium status non disponible - vérifier les pods${NC}"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ Cilium installé avec succès !${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BLUE}Cilium CLI commandes utiles:${NC}"
echo "  cilium status                    # État du cluster"
echo "  cilium connectivity test         # Test connectivité"
echo "  cilium policy get                # Voir policies en place"
echo "  cilium service list              # Services exposés"
echo "  cilium endpoint list             # Endpoints réseau"
echo ""

echo -e "${BLUE}Hubble UI (Observabilité):${NC}"
echo "  kubectl port-forward -n cilium svc/hubble-ui 8081:80"
echo "  # Ouvrir: http://localhost:8081"
echo ""

echo -e "${BLUE}Dashboards Prometheus:${NC}"
echo "  kubectl port-forward -n cilium svc/cilium-agent 9090:9090"
echo "  # Ouvrir: http://localhost:9090"
echo ""

echo -e "${YELLOW}Prochaines étapes:${NC}"
echo "  1. Tester la connectivité: cilium connectivity test"
echo "  2. Déployer des CiliumNetworkPolicies (L7)"
echo "  3. Explorer Hubble UI pour observabilité"
echo ""

echo -e "${BLUE}Documentation:${NC}"
echo "  https://docs.cilium.io/"
echo "  https://docs.cilium.io/en/stable/security/policy/"
echo ""
