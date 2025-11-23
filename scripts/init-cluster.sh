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

# Charger et valider la configuration
if [ -f "$SCRIPT_DIR/lib-config.sh" ]; then
    source "$SCRIPT_DIR/lib-config.sh"

    # Charger configuration avec validation
    if ! load_kubernetes_config "$SCRIPT_DIR"; then
        echo -e "${RED}✗ Erreur: Configuration invalide ou incomplète${NC}"
        exit 1
    fi

    # Vérifier prérequis installation
    if ! validate_install_prerequisites "init-cluster.sh"; then
        echo -e "${RED}✗ Prérequis non satisfaits${NC}"
        echo -e "${YELLOW}Exécutez d'abord: ./common-setup.sh${NC}"
        exit 1
    fi

    # Afficher configuration chargée
    show_kubernetes_config
else
    echo -e "${RED}✗ Erreur: lib-config.sh manquant${NC}"
    exit 1
fi

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
ETCD_ENDPOINTS=""
while true; do
    ip_var="MASTER${master_num}_IP"
    hostname_var="MASTER${master_num}_HOSTNAME"

    if [ -n "${!ip_var}" ]; then
        CERT_SANS_API="${CERT_SANS_API}\n    - \"${!hostname_var}\""
        CERT_SANS_API="${CERT_SANS_API}\n    - \"${!ip_var}\""

        # Construire les endpoints etcd externes (pour HA)
        if [ $master_num -gt 1 ]; then
            ETCD_ENDPOINTS="${ETCD_ENDPOINTS}\n    - \"https://${!ip_var}:2379\""
        else
            ETCD_ENDPOINTS="    - \"https://${!ip_var}:2379\""
        fi

        ((master_num++))
    else
        break
    fi
done

# Compter le nombre de masters pour décider si etcd local ou externe
MASTER_COUNT=$((master_num - 1))

CERT_SANS_API="${CERT_SANS_API}\n    - \"localhost\"\n    - \"127.0.0.1\"\n    - \"::1\""

# Générer la configuration etcd selon le nombre de masters
if [ $MASTER_COUNT -eq 1 ]; then
    # Mode etcd local pour un seul master
    ETCD_CONFIG="etcd:
  local:
    dataDir: \"/var/lib/etcd\""
else
    # Mode etcd externe pour HA (3+ masters)
    # Utiliser les chemins configurables depuis config.sh ou les defaults
    ETCD_CA="${ETCD_CA_FILE:-/etc/kubernetes/pki/etcd/ca.crt}"
    ETCD_CERT="${ETCD_CERT_FILE:-/etc/kubernetes/pki/etcd/peer.crt}"
    ETCD_KEY="${ETCD_KEY_FILE:-/etc/kubernetes/pki/etcd/peer.key}"

    ETCD_CONFIG="etcd:
  external:
    endpoints:
$(echo -e "$ETCD_ENDPOINTS" | sed 's/^/      /')
    caFile: \"${ETCD_CA}\"
    certFile: \"${ETCD_CERT}\"
    keyFile: \"${ETCD_KEY}\""
fi

# Générer le fichier de configuration
cat > kubelet-ha.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "${LOCAL_IP}"
  bindPort: ${API_SERVER_PORT:-6443}
nodeRegistration:
  name: "${FIRST_MASTER_HOSTNAME}"
  criSocket: "/var/run/containerd/containerd.sock"

---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: "${K8S_VERSION:-1.33.0}"
controlPlaneEndpoint: "${VIP_HOSTNAME:-k8s}:${API_SERVER_PORT:-6443}"
networking:
  podSubnet: "${POD_SUBNET:-11.0.0.0/16}"
  serviceSubnet: "${SERVICE_SUBNET:-10.0.0.0/16}"
apiServer:
  certSANs:
$(printf '%b' "$CERT_SANS_API")
${ETCD_CONFIG}
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
echo "  - Kubernetes: ${K8S_VERSION:-1.33.0}"
echo "  - Masters configurés: ${MASTER_COUNT}"
if [ $MASTER_COUNT -eq 1 ]; then
    echo "  - Mode etcd: LOCAL (single master)"
else
    echo "  - Mode etcd: EXTERNAL (HA - ${MASTER_COUNT} masters)"
    echo "  - Endpoints etcd:"
    echo -e "$ETCD_ENDPOINTS" | sed 's/^/      /'
fi
echo ""

echo -e "${YELLOW}[1/4] Initialisation de kubeadm...${NC}"
kubeadm init --config kubelet-ha.yaml --upload-certs | tee kubeadm-init.log

echo -e "${GREEN}✓ Cluster initialisé${NC}"

echo -e "${YELLOW}[2/4] Configuration de kubectl pour l'utilisateur courant...${NC}"

# Vérifier que le fichier admin.conf existe (créé par kubeadm init)
if [ ! -f /etc/kubernetes/admin.conf ]; then
    echo -e "${RED}✗ Erreur: /etc/kubernetes/admin.conf non trouvé${NC}"
    echo -e "${YELLOW}Le cluster n'a pas été initialisé avec 'kubeadm init'${NC}"
    echo -e "${YELLOW}Assurez-vous d'avoir exécuté les étapes précédentes${NC}"
    exit 1
fi

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

# Extraire les commandes de join et les sauvegarder de manière réutilisable
echo -e "${BLUE}========================================${NC}" > join-commands.txt
echo -e "COMMANDES POUR REJOINDRE LE CLUSTER" >> join-commands.txt
echo -e "${BLUE}========================================${NC}" >> join-commands.txt
echo "" >> join-commands.txt

echo "# Pour ajouter les AUTRES MASTERS au cluster:" >> join-commands.txt
grep -A 3 "kubeadm join" kubeadm-init.log | grep "control-plane" | head -n 3 >> join-commands.txt || echo "Commande non trouvée" >> join-commands.txt
echo "" >> join-commands.txt

echo "# Pour ajouter un WORKER:" >> join-commands.txt
grep -A 3 "kubeadm join" kubeadm-init.log | grep -v "control-plane" | head -n 3 >> join-commands.txt || echo "Commande non trouvée" >> join-commands.txt

# Sauvegarder aussi un script sourçable pour automatisation
echo -e "${BLUE}Génération du script d'automatisation join-nodes.sh...${NC}"

# Extraire le token et le certificat hash
MASTER_JOIN_CMD=$(grep -A 3 "kubeadm join" kubeadm-init.log | grep "control-plane" | head -n 3 | tr '\n' ' ' | sed 's/  */ /g')
WORKER_JOIN_CMD=$(grep -A 3 "kubeadm join" kubeadm-init.log | grep -v "control-plane" | head -n 3 | tr '\n' ' ' | sed 's/  */ /g')

cat > join-nodes.sh <<'JOINEOF'
#!/bin/bash
# Script d'aide pour rejoindre des nœuds au cluster Kubernetes
# Généré par init-cluster.sh - À customizer selon vos besoins

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_commands() {
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Commandes pour rejoindre le cluster${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Pour ajouter un MASTER:${NC}"
JOINEOF

echo "    echo \"$MASTER_JOIN_CMD\"" >> join-nodes.sh

cat >> join-nodes.sh <<'JOINEOF'
    echo ""
    echo -e "${YELLOW}Pour ajouter un WORKER:${NC}"
JOINEOF

echo "    echo \"$WORKER_JOIN_CMD\"" >> join-nodes.sh

cat >> join-nodes.sh <<'JOINEOF'
    echo ""
}

# Si appelé directement, afficher les commandes
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    show_commands
fi
JOINEOF

chmod +x join-nodes.sh
echo -e "${GREEN}✓ Script join-nodes.sh généré${NC}"

echo -e "${GREEN}✓ Commandes sauvegardées dans join-commands.txt et join-nodes.sh${NC}"

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
