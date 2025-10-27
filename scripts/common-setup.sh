#!/bin/bash
################################################################################
# Script de préparation commune pour tous les nœuds Kubernetes
# Compatible avec: Ubuntu 20.04/22.04/24.04 - Debian 12/13
# Auteur: azurtech56
# Version: 2.0 - Idempotent
################################################################################

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Configuration commune Kubernetes${NC}"
echo -e "${GREEN}========================================${NC}"

# Vérifier si l'utilisateur est root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Ce script doit être exécuté en tant que root${NC}"
   exit 1
fi

# Charger la configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Charger les bibliothèques
if [ -f "$SCRIPT_DIR/lib/logging.sh" ]; then
    source "$SCRIPT_DIR/lib/logging.sh"
    init_logging
fi

if [ -f "$SCRIPT_DIR/lib/idempotent.sh" ]; then
    source "$SCRIPT_DIR/lib/idempotent.sh"
    init_idempotent
else
    echo -e "${YELLOW}⚠ Bibliothèque d'idempotence non trouvée - Mode standard${NC}"
fi

# Charger bibliothèques v2.1
if [ -f "$SCRIPT_DIR/lib/performance.sh" ]; then
    source "$SCRIPT_DIR/lib/performance.sh"
    init_cache
    start_timer "common_setup"
fi

if [ -f "$SCRIPT_DIR/lib/error-codes.sh" ]; then
    source "$SCRIPT_DIR/lib/error-codes.sh"
fi

if [ -f "$SCRIPT_DIR/lib/dry-run.sh" ]; then
    source "$SCRIPT_DIR/lib/dry-run.sh"
    init_dry_run
fi

if [ -f "$SCRIPT_DIR/lib/notifications.sh" ]; then
    source "$SCRIPT_DIR/lib/notifications.sh"
    notify_install_start "Configuration commune"
fi

if [ -f "$SCRIPT_DIR/config.sh" ]; then
    echo -e "${BLUE}Chargement de la configuration depuis config.sh...${NC}"
    source "$SCRIPT_DIR/config.sh"
else
    echo -e "${YELLOW}Avertissement: config.sh non trouvé, utilisation de la version par défaut${NC}"
    K8S_VERSION="1.32.2"
    K8S_REPO_VERSION="1.32"
fi

echo -e "${BLUE}Version Kubernetes à installer: ${K8S_VERSION}${NC}"
echo -e "${BLUE}Repository Kubernetes: v${K8S_REPO_VERSION}${NC}"
echo ""

echo -e "${YELLOW}[1/8] Désactivation du swap...${NC}"
if type -t setup_swap_idempotent &>/dev/null; then
    setup_swap_idempotent
else
    swapoff -a
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    echo -e "${GREEN}✓ Swap désactivé${NC}"
fi

echo -e "${YELLOW}[2/8] Mise à jour du système et installation des dépendances...${NC}"
apt update
apt upgrade -y

# Installer les outils nécessaires
echo -e "${BLUE}Installation des dépendances requises...${NC}"

# Détecter si Ubuntu ou Debian pour software-properties
if grep -q "ubuntu" /etc/os-release 2>/dev/null; then
    SOFTWARE_PROPERTIES="software-properties-common"
else
    # Sur Debian, ce paquet n'existe pas ou n'est pas nécessaire
    SOFTWARE_PROPERTIES=""
fi

apt install -y \
    curl \
    gnupg \
    ca-certificates \
    apt-transport-https \
    ${SOFTWARE_PROPERTIES} \
    ufw \
    iproute2 \
    openssh-client \
    net-tools \
    bash-completion

echo -e "${GREEN}✓ Système mis à jour et dépendances installées${NC}"
echo -e "${BLUE}  Paquets: curl, gnupg, ufw, iproute2, openssh-client, net-tools${NC}"

echo -e "${YELLOW}[3/8] Chargement des modules kernel...${NC}"
if type -t setup_kernel_modules_idempotent &>/dev/null; then
    setup_kernel_modules_idempotent "overlay" "br_netfilter"
else
    cat <<EOF | tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
    modprobe overlay
    modprobe br_netfilter
    echo -e "${GREEN}✓ Modules kernel chargés${NC}"
fi

echo -e "${YELLOW}[4/8] Configuration sysctl...${NC}"
if type -t setup_sysctl_idempotent &>/dev/null; then
    setup_sysctl_idempotent
else
    cat <<EOF | tee /etc/sysctl.d/99-kubernetes-k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
    sysctl --system > /dev/null 2>&1
    echo -e "${GREEN}✓ sysctl configuré${NC}"
fi

echo -e "${YELLOW}[5/8] Installation de containerd...${NC}"
apt install -y containerd
mkdir -p /etc/containerd/
containerd config default | tee /etc/containerd/config.toml >/dev/null 2>&1

# Modification SystemdCgroup
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd
echo -e "${GREEN}✓ containerd installé et configuré${NC}"

echo -e "${YELLOW}[6/8] Ajout du repository Kubernetes...${NC}"
mkdir -p /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_REPO_VERSION}/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_REPO_VERSION}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
echo -e "${GREEN}✓ Repository Kubernetes v${K8S_REPO_VERSION} ajouté${NC}"

echo -e "${YELLOW}[7/8] Installation de kubelet, kubeadm et kubectl...${NC}"
apt update
apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
echo -e "${GREEN}✓ Composants Kubernetes installés${NC}"

echo -e "${YELLOW}[8/8] Vérification de la version...${NC}"
kubeadm version
kubectl version --client
echo -e "${GREEN}✓ Installation terminée${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Configuration commune terminée !${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Prochaines étapes:${NC}"
echo "  - Pour un master: exécutez master-setup.sh"
echo "  - Pour un worker: exécutez worker-setup.sh"

# === v2.1 Performance & Notifications ===
if type -t stop_timer &>/dev/null; then
    stop_timer "common_setup"
fi

if type -t notify_install_success &>/dev/null; then
    notify_install_success "Configuration commune"
fi

if type -t dry_run_summary &>/dev/null; then
    dry_run_summary
fi
# === Fin v2.1 ===
