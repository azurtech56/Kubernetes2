#!/bin/bash
################################################################################
# Script d'initialisation du cluster Kubernetes (Premier master uniquement)
# Compatible avec: Ubuntu 20.04/22.04/24.04
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
echo -e "${GREEN}  Initialisation du cluster Kubernetes${NC}"
echo -e "${GREEN}========================================${NC}"

# Vérifier si l'utilisateur est root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Ce script doit être exécuté en tant que root${NC}"
   exit 1
fi

# Charger la configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    echo -e "${BLUE}Chargement de la configuration depuis config.sh...${NC}"
    source "$SCRIPT_DIR/config.sh"
else
    echo -e "${YELLOW}Avertissement: config.sh non trouvé, utilisation des valeurs par défaut${NC}"
fi

# Afficher la configuration détectée
echo ""
echo -e "${BLUE}Configuration détectée depuis config.sh:${NC}"
echo "  VIP: ${VIP:-Non défini}"
echo "  Masters: $(get_master_count 2>/dev/null || echo '3') nœuds"
echo ""

# Demander confirmation
echo -e "${RED}ATTENTION: Ce script doit être exécuté UNIQUEMENT sur le premier master${NC}"
echo -e "${YELLOW}Assurez-vous que:${NC}"
echo "  1. keepalived est configuré et l'IP virtuelle ${VIP:-192.168.0.200} est active"
echo "  2. /etc/hosts contient les entrées pour tous les masters"
echo "  3. common-setup.sh et master-setup.sh ont été exécutés"
echo ""
read -p "Continuer? [y/N]: " confirm

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${RED}Initialisation annulée${NC}"
    exit 1
fi

# Générer le fichier kubelet-ha.yaml dynamiquement
echo -e "${YELLOW}Génération du fichier de configuration kubeadm...${NC}"

# Détecter l'IP locale du premier master
LOCAL_IP=$(hostname -I | awk '{print $1}')
FIRST_MASTER_HOSTNAME=${MASTER1_HOSTNAME:-$(hostname)}

# Générer les certSANs dynamiquement pour apiServer
CERT_SANS_API="    - \"${VIP_HOSTNAME:-k8s}\""
CERT_SANS_API="${CERT_SANS_API}\n    - \"${VIP:-192.168.0.200}\""

# Ajouter tous les masters détectés
master_num=1
while true; do
    ip_var="MASTER${master_num}_IP"
    hostname_var="MASTER${master_num}_HOSTNAME"

    if [ -n "${!ip_var}" ]; then
        CERT_SANS_API="${CERT_SANS_API}\n    - \"${!hostname_var}\""
        CERT_SANS_API="${CERT_SANS_API}\n    - \"${!ip_var}\""
        ((master_num++))
    else
        break
    fi
done

CERT_SANS_API="${CERT_SANS_API}\n    - \"localhost\"\n    - \"127.0.0.1\"\n    - \"::1\""

# Générer le fichier de configuration
cat > kubelet-ha.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "${LOCAL_IP}"
  bindPort: ${API_SERVER_PORT:-6443}
nodeRegistration:
  name: "${FIRST_MASTER_HOSTNAME}"
  criSocket: "/var/run/containerd/containerd.sock"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: "${K8S_VERSION:-1.32.2}"
controlPlaneEndpoint: "${VIP_HOSTNAME:-k8s}:${API_SERVER_PORT:-6443}"
networking:
  podSubnet: "${POD_SUBNET:-11.0.0.0/16}"
  serviceSubnet: "${SERVICE_SUBNET:-10.0.0.0/16}"
apiServer:
  certSANs:
$(echo -e "$CERT_SANS_API")
etcd:
  local:
    dataDir: "/var/lib/etcd"
    certSANs:
$(echo -e "$CERT_SANS_API")
controllerManager: {}
scheduler: {}
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: "systemd"
EOF
echo -e "${GREEN}✓ Fichier kubelet-ha.yaml créé${NC}"
echo ""
echo -e "${BLUE}Aperçu de la configuration:${NC}"
echo "  - Hostname: ${FIRST_MASTER_HOSTNAME}"
echo "  - IP locale: ${LOCAL_IP}"
echo "  - VIP: ${VIP:-192.168.0.200}"
echo "  - Kubernetes: ${K8S_VERSION:-1.32.2}"
echo "  - Masters configurés: $(get_master_count 2>/dev/null || echo '3')"
echo ""

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

echo "# Pour ajouter les AUTRES MASTERS au cluster:" >> join-commands.txt
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

# Installation automatique des composants essentiels
echo -e "${YELLOW}Installation des composants essentiels...${NC}"
echo ""
echo -e "${BLUE}Pour que le cluster soit fonctionnel, vous devez installer:${NC}"
echo "  1. Calico CNI (réseau des pods) - OBLIGATOIRE"
echo "  2. Storage Provisioner (stockage persistant) - RECOMMANDÉ"
echo ""
read -p "Voulez-vous installer automatiquement Calico et le Storage Provisioner maintenant ? [Y/n]: " install_essentials

if [[ ! $install_essentials =~ ^[Nn]$ ]]; then
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}  Installation de Calico CNI${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    if [ -f "$SCRIPT_DIR/install-calico.sh" ]; then
        bash "$SCRIPT_DIR/install-calico.sh"
    else
        echo -e "${RED}Erreur: install-calico.sh non trouvé${NC}"
        echo -e "${YELLOW}Veuillez exécuter manuellement: ./install-calico.sh${NC}"
    fi

    echo ""
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}  Installation du Storage Provisioner${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    if [ -f "$SCRIPT_DIR/install-storage.sh" ]; then
        bash "$SCRIPT_DIR/install-storage.sh"
    else
        echo -e "${RED}Erreur: install-storage.sh non trouvé${NC}"
        echo -e "${YELLOW}Veuillez exécuter manuellement: ./install-storage.sh${NC}"
    fi

    echo ""
    echo -e "${GREEN}✓ Composants essentiels installés${NC}"
    echo ""
else
    echo ""
    echo -e "${YELLOW}⚠ Installation manuelle requise${NC}"
    echo -e "${BLUE}N'oubliez pas d'installer ces composants:${NC}"
    echo "  1. ./install-calico.sh (OBLIGATOIRE)"
    echo "  2. ./install-storage.sh (RECOMMANDÉ)"
    echo ""
fi

echo -e "${YELLOW}Prochaines étapes:${NC}"
echo ""
echo -e "${BLUE}1. Ajouter les autres masters:${NC}"
echo "   Voir le fichier join-commands.txt pour les commandes"
echo "   $(get_master_count 2>/dev/null || echo '3') masters total configurés dans config.sh"
echo ""
echo -e "${BLUE}2. Ajouter les workers:${NC}"
echo "   Voir le fichier join-commands.txt pour les commandes"
echo ""
echo -e "${BLUE}3. Installer MetalLB (Load Balancer):${NC}"
echo "   ./install-metallb.sh"
echo ""
echo -e "${BLUE}4. Installer Rancher (Interface Web - optionnel):${NC}"
echo "   ./install-rancher.sh"
echo ""
echo -e "${BLUE}5. Installer Prometheus + Grafana (Monitoring - optionnel):${NC}"
echo "   ./install-monitoring.sh"
echo ""
cat join-commands.txt
