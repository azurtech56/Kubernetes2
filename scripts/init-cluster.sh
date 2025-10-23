#!/bin/bash
################################################################################
# Script d'initialisation du cluster Kubernetes (Premier master uniquement)
# Compatible avec: Ubuntu 20.04/22.04/24.04
# Auteur: Kubernetes HA Setup
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
echo -e "${GREEN}  Initialisation du cluster Kubernetes${NC}"
echo -e "${GREEN}========================================${NC}"

# Vérifier si l'utilisateur est root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Ce script doit être exécuté en tant que root${NC}"
   exit 1
fi

# Demander confirmation
echo -e "${RED}ATTENTION: Ce script doit être exécuté UNIQUEMENT sur le premier master (k8s01-1)${NC}"
echo -e "${YELLOW}Assurez-vous que:${NC}"
echo "  1. keepalived est configuré et l'IP virtuelle 192.168.0.200 est active"
echo "  2. Le fichier kubelet-ha.yaml est présent dans le répertoire courant"
echo "  3. /etc/hosts contient les entrées pour k8s, k8s01-1, k8s01-2, k8s01-3"
echo ""
read -p "Continuer? [y/N]: " confirm

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${RED}Initialisation annulée${NC}"
    exit 1
fi

# Vérifier que le fichier kubelet-ha.yaml existe
if [ ! -f "kubelet-ha.yaml" ]; then
    echo -e "${YELLOW}Le fichier kubelet-ha.yaml n'existe pas. Création...${NC}"

    # Détecter l'IP locale du premier master
    LOCAL_IP=$(hostname -I | awk '{print $1}')

    cat > kubelet-ha.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "${LOCAL_IP}"
  bindPort: 6443
nodeRegistration:
  name: "k8s01-1"
  criSocket: "/var/run/containerd/containerd.sock"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: "1.32.2"
controlPlaneEndpoint: "k8s:6443"
networking:
  podSubnet: "11.0.0.0/16"
  serviceSubnet: "10.0.0.1/16"
apiServer:
  certSANs:
    - "k8s"
    - "k8s01-1"
    - "k8s01-2"
    - "k8s01-3"
    - "192.168.0.200"
    - "192.168.0.201"
    - "192.168.0.202"
    - "192.168.0.203"
    - "localhost"
etcd:
  local:
    dataDir: "/var/lib/etcd"
    certSANs:
      - "k8s"
      - "k8s01-1"
      - "k8s01-2"
      - "k8s01-3"
      - "192.168.0.200"
      - "192.168.0.201"
      - "192.168.0.202"
      - "192.168.0.203"
      - "localhost"
      - "127.0.0.1"
      - "::1"
controllerManager: {}
scheduler: {}
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: "systemd"
EOF
    echo -e "${GREEN}✓ Fichier kubelet-ha.yaml créé${NC}"
fi

echo -e "${YELLOW}[1/4] Initialisation de kubeadm...${NC}"
kubeadm init --config kubelet-ha.yaml --upload-certs | tee kubeadm-init.log

echo -e "${GREEN}✓ Cluster initialisé${NC}"

echo -e "${YELLOW}[2/4] Configuration de kubectl pour l'utilisateur courant...${NC}"
# Configuration pour root
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# Configuration pour l'utilisateur sudo si différent de root
if [ -n "$SUDO_USER" ]; then
    SUDO_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    mkdir -p "$SUDO_HOME/.kube"
    cp -i /etc/kubernetes/admin.conf "$SUDO_HOME/.kube/config"
    chown -R "$SUDO_USER:$SUDO_USER" "$SUDO_HOME/.kube"
    echo -e "${GREEN}✓ kubectl configuré pour root et $SUDO_USER${NC}"
else
    echo -e "${GREEN}✓ kubectl configuré pour root${NC}"
fi

export KUBECONFIG=$HOME/.kube/config

echo -e "${YELLOW}[3/4] Extraction des commandes de join...${NC}"

# Extraire les commandes de join
echo -e "${BLUE}========================================${NC}" > join-commands.txt
echo -e "COMMANDES POUR REJOINDRE LE CLUSTER" >> join-commands.txt
echo -e "${BLUE}========================================${NC}" >> join-commands.txt
echo "" >> join-commands.txt

echo "# Pour ajouter un MASTER (k8s01-2 ou k8s01-3):" >> join-commands.txt
grep -A 2 "kubeadm join" kubeadm-init.log | head -n 3 >> join-commands.txt || echo "Commande non trouvée" >> join-commands.txt
echo "" >> join-commands.txt

echo "# Pour ajouter un WORKER:" >> join-commands.txt
grep "kubeadm join" kubeadm-init.log | grep -v "control-plane" | tail -n 2 >> join-commands.txt || echo "Commande non trouvée" >> join-commands.txt

echo -e "${GREEN}✓ Commandes sauvegardées dans join-commands.txt${NC}"

echo -e "${YELLOW}[4/4] Vérification du cluster...${NC}"
sleep 5
kubectl get nodes
echo -e "${GREEN}✓ Cluster vérifié${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Cluster initialisé avec succès !${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Prochaines étapes:${NC}"
echo ""
echo -e "${BLUE}1. Installer Calico (CNI):${NC}"
echo "   ./install-calico.sh"
echo ""
echo -e "${BLUE}2. Ajouter les autres masters (k8s01-2 et k8s01-3):${NC}"
echo "   Voir le fichier join-commands.txt pour les commandes"
echo ""
echo -e "${BLUE}3. Ajouter les workers:${NC}"
echo "   Voir le fichier join-commands.txt pour les commandes"
echo ""
echo -e "${BLUE}4. Installer MetalLB:${NC}"
echo "   ./install-metallb.sh"
echo ""
echo -e "${BLUE}5. Installer Rancher (optionnel):${NC}"
echo "   ./install-rancher.sh"
echo ""
cat join-commands.txt
