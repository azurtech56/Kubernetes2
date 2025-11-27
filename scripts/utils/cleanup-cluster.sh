#!/bin/bash
################################################################################
# Script de nettoyage et désinstallation du cluster Kubernetes
# Supprime tous les composants et reset le système
# Auteur: azurtech56
# Version: 1.0
################################################################################

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# FONCTIONS
# ============================================================================

show_header() {
    clear
    echo -e "${RED}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  NETTOYAGE ET DÉSINSTALLATION - KUBERNETES HA${NC}"
    echo -e "${RED}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

show_warning() {
    echo -e "${RED}⚠⚠⚠ AVERTISSEMENT ⚠⚠⚠${NC}"
    echo ""
    echo -e "${YELLOW}Ce script va:${NC}"
    echo "  • Désinstaller Kubernetes et ses composants"
    echo "  • Supprimer tous les pods et services"
    echo "  • Nettoyer la configuration du système"
    echo "  • Désactiver les services (kubelet, containerd)"
    echo ""
    echo -e "${RED}Cette action est IRRÉVERSIBLE!${NC}"
    echo ""
}

confirm_action() {
    local prompt=$1
    read -p "$(echo -e ${YELLOW}${prompt}${NC})" response
    if [[ ! $response =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Opération annulée${NC}"
        exit 0
    fi
}

# ============================================================================
# VÉRIFICATIONS INITIALES
# ============================================================================

show_header

# Vérifier si root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Ce script doit être exécuté en tant que root${NC}"
    exit 1
fi

show_warning
confirm_action "Êtes-vous CERTAIN de vouloir continuer? (oui/non): "

echo ""
echo -e "${CYAN}Démarrage du nettoyage...${NC}"
echo ""

# ============================================================================
# ÉTAPE 1: Désinstaller les add-ons Kubernetes
# ============================================================================

echo -e "${YELLOW}[1/5] Suppression des add-ons...${NC}"

# Supprimer MetalLB
if kubectl get namespace metallb-system &> /dev/null; then
    echo "  • Suppression de MetalLB..."
    helm uninstall metallb -n metallb-system 2>/dev/null || true
    kubectl delete namespace metallb-system 2>/dev/null || true
fi

# Supprimer Rancher
if kubectl get namespace cattle-system &> /dev/null; then
    echo "  • Suppression de Rancher..."
    helm uninstall rancher -n cattle-system 2>/dev/null || true
    kubectl delete namespace cattle-system 2>/dev/null || true
fi

# Supprimer Monitoring
if kubectl get namespace monitoring &> /dev/null; then
    echo "  • Suppression de Prometheus..."
    helm uninstall prometheus -n monitoring 2>/dev/null || true
    kubectl delete namespace monitoring 2>/dev/null || true
fi

# Supprimer Calico
if kubectl get namespace calico-system &> /dev/null; then
    echo "  • Suppression de Calico..."
    kubectl delete namespace calico-system 2>/dev/null || true
    kubectl delete namespace calico-apiserver 2>/dev/null || true
fi

echo -e "${GREEN}✓ Add-ons supprimés${NC}"
echo ""

# ============================================================================
# ÉTAPE 2: Reset kubeadm
# ============================================================================

echo -e "${YELLOW}[2/5] Reset du cluster kubeadm...${NC}"

# Reset kubeadm
kubeadm reset -f 2>/dev/null || true

echo -e "${GREEN}✓ kubeadm reset${NC}"
echo ""

# ============================================================================
# ÉTAPE 3: Arrêter et désactiver services
# ============================================================================

echo -e "${YELLOW}[3/5] Arrêt des services...${NC}"

# Kubelet
systemctl stop kubelet 2>/dev/null || true
systemctl disable kubelet 2>/dev/null || true

# keepalived
systemctl stop keepalived 2>/dev/null || true
systemctl disable keepalived 2>/dev/null || true

# Helm (optionnel)
# systemctl stop helm 2>/dev/null || true

echo -e "${GREEN}✓ Services arrêtés et désactivés${NC}"
echo ""

# ============================================================================
# ÉTAPE 4: Nettoyer les fichiers système
# ============================================================================

echo -e "${YELLOW}[4/5] Nettoyage des fichiers...${NC}"

# Répertoires critiques
rm -rf /etc/kubernetes/ 2>/dev/null || true
rm -rf /var/lib/kubernetes/ 2>/dev/null || true
rm -rf /var/lib/kubelet/ 2>/dev/null || true
rm -rf /var/lib/etcd/ 2>/dev/null || true
rm -rf /var/lib/keepalived/ 2>/dev/null || true
rm -rf $HOME/.kube/ 2>/dev/null || true

# Fichiers de configuration
rm -f /etc/cni/net.d/* 2>/dev/null || true
rm -f /etc/default/kubelet 2>/dev/null || true
rm -f /etc/systemd/system/kubelet.service.d/* 2>/dev/null || true
rm -f /etc/keepalived/keepalived.conf 2>/dev/null || true

# Rechargement systemd
systemctl daemon-reload 2>/dev/null || true

echo -e "${GREEN}✓ Fichiers nettoyés${NC}"
echo ""

# ============================================================================
# ÉTAPE 5: Nettoyage réseau (optionnel)
# ============================================================================

echo -e "${YELLOW}[5/5] Nettoyage réseau...${NC}"

# Supprimer les routes Calico
ip route | grep -E "10.0.0.0|11.0.0.0" | awk '{print $1}' | xargs -I {} ip route del {} 2>/dev/null || true

# Supprimer les interfaces virtuelles
ip link show | grep -E "cali|docker|br-" | awk '{print $2}' | sed 's/:$//' | xargs -I {} ip link delete {} 2>/dev/null || true

# Iptables cleanup
iptables -F 2>/dev/null || true
iptables -X 2>/dev/null || true
iptables -t nat -F 2>/dev/null || true
iptables -t nat -X 2>/dev/null || true
iptables -t mangle -F 2>/dev/null || true
iptables -t mangle -X 2>/dev/null || true

echo -e "${GREEN}✓ Réseau nettoyé${NC}"
echo ""

# ============================================================================
# RÉSUMÉ
# ============================================================================

echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Nettoyage complété avec succès!${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}Le système est prêt pour une nouvelle installation.${NC}"
echo ""

echo -e "${BLUE}Prochaines étapes (optionnel):${NC}"
echo "  1. Réactiver swap (si désactivé): swapon -a"
echo "  2. Réinstaller les composants: ./deploy-cluster.sh"
echo ""

read -p "Appuyez sur Entrée pour continuer..."
