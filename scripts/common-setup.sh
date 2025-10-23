#!/bin/bash
################################################################################
# Script de préparation commune pour tous les nœuds Kubernetes
# Compatible avec: Ubuntu 20.04/22.04/24.04 - Debian 12/13
# Auteur: azurtech56
# Version: 1.0
################################################################################

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Configuration commune Kubernetes${NC}"
echo -e "${GREEN}========================================${NC}"

# Vérifier si l'utilisateur est root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Ce script doit être exécuté en tant que root${NC}"
   exit 1
fi

echo -e "${YELLOW}[1/8] Désactivation du swap...${NC}"
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
echo -e "${GREEN}✓ Swap désactivé${NC}"

echo -e "${YELLOW}[2/8] Mise à jour du système...${NC}"
apt update
apt upgrade -y
echo -e "${GREEN}✓ Système mis à jour${NC}"

echo -e "${YELLOW}[3/8] Chargement des modules kernel...${NC}"
cat <<EOF | tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter
echo -e "${GREEN}✓ Modules kernel chargés${NC}"

echo -e "${YELLOW}[4/8] Configuration sysctl...${NC}"
cat <<EOF | tee /etc/sysctl.d/99-kubernetes-k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system > /dev/null 2>&1
echo -e "${GREEN}✓ sysctl configuré${NC}"

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
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
echo -e "${GREEN}✓ Repository Kubernetes ajouté${NC}"

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
