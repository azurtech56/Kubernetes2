#!/bin/bash
################################################################################
# Script de désinstallation complète - Kubernetes HA
# Compatible avec: Ubuntu 20.04/22.04/24.04 - Debian 12/13
# Version: 2.1.0
################################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Répertoire du script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Charger les bibliothèques
source "$SCRIPT_DIR/lib/logging.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/notifications.sh" 2>/dev/null || true

init_logging "uninstall-cluster"

################################################################################
# FONCTIONS D'AFFICHAGE
################################################################################

show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}${RED}Kubernetes HA - Désinstallation${NC}                         ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_menu() {
    show_header
    echo -e "${BOLD}${BLUE}═══ MENU DE DÉSINSTALLATION ═══${NC}"
    echo ""
    echo -e "${GREEN}[1]${NC}  Désinstaller MetalLB"
    echo -e "${GREEN}[2]${NC}  Désinstaller Rancher"
    echo -e "${GREEN}[3]${NC}  Désinstaller Monitoring (Prometheus + Grafana)"
    echo -e "${GREEN}[4]${NC}  Désinstaller Calico CNI"
    echo -e "${GREEN}[5]${NC}  Désinstaller keepalived"
    echo ""
    echo -e "${RED}[6]${NC}  ${RED}${BOLD}Désinstallation COMPLÈTE du cluster${NC}"
    echo ""
    echo -e "${YELLOW}[0]${NC}  Retour / Quitter"
    echo ""
    echo -n "Votre choix: "
}

################################################################################
# FONCTIONS DE DÉSINSTALLATION
################################################################################

# Désinstallation MetalLB
uninstall_metallb() {
    log_info "Début désinstallation MetalLB"
    show_header
    echo -e "${RED}═══ DÉSINSTALLATION DE METALLB ═══${NC}"
    echo ""
    echo -e "${YELLOW}Cette action va:${NC}"
    echo "  - Supprimer toutes les ressources MetalLB"
    echo "  - Supprimer le namespace metallb-system"
    echo "  - Supprimer les IP pools et configurations"
    echo ""
    read -p "Êtes-vous sûr de vouloir désinstaller MetalLB? [y/N]: " confirm

    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${YELLOW}Désinstallation de MetalLB...${NC}"

        log_info "Suppression des ressources MetalLB"
        kubectl delete ipaddresspools.metallb.io -n metallb-system --all 2>/dev/null || true
        kubectl delete l2advertisements.metallb.io -n metallb-system --all 2>/dev/null || true
        kubectl delete namespace metallb-system 2>/dev/null || true

        log_success "MetalLB désinstallé"
        echo -e "${GREEN}✓ MetalLB désinstallé${NC}"

        # Notification
        if type -t notify_info &>/dev/null; then
            notify_info "MetalLB désinstallé" "Suppression réussie du namespace metallb-system"
        fi
    else
        log_info "Désinstallation MetalLB annulée"
        echo -e "${YELLOW}Désinstallation annulée${NC}"
    fi
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
}

# Désinstallation Rancher
uninstall_rancher() {
    log_info "Début désinstallation Rancher"
    show_header
    echo -e "${RED}═══ DÉSINSTALLATION DE RANCHER ═══${NC}"
    echo ""
    echo -e "${YELLOW}Cette action va:${NC}"
    echo "  - Supprimer Rancher (Helm)"
    echo "  - Supprimer le namespace cattle-system"
    echo "  - Supprimer cert-manager"
    echo "  - Supprimer le namespace cert-manager"
    echo ""
    read -p "Êtes-vous sûr de vouloir désinstaller Rancher? [y/N]: " confirm

    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${YELLOW}Désinstallation de Rancher...${NC}"

        log_info "Suppression Rancher via Helm"
        helm uninstall rancher -n cattle-system 2>/dev/null || true
        kubectl delete namespace cattle-system 2>/dev/null || true

        echo -e "${YELLOW}Désinstallation de cert-manager...${NC}"
        log_info "Suppression cert-manager"
        kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.0/cert-manager.yaml 2>/dev/null || true
        kubectl delete namespace cert-manager 2>/dev/null || true

        log_success "Rancher et cert-manager désinstallés"
        echo -e "${GREEN}✓ Rancher et cert-manager désinstallés${NC}"

        # Notification
        if type -t notify_info &>/dev/null; then
            notify_info "Rancher désinstallé" "Suppression réussie de Rancher et cert-manager"
        fi
    else
        log_info "Désinstallation Rancher annulée"
        echo -e "${YELLOW}Désinstallation annulée${NC}"
    fi
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
}

# Désinstallation Monitoring
uninstall_monitoring() {
    log_info "Début désinstallation Monitoring"
    show_header
    echo -e "${RED}═══ DÉSINSTALLATION DU MONITORING ═══${NC}"
    echo ""
    echo -e "${YELLOW}Cette action va:${NC}"
    echo "  - Supprimer Prometheus et Grafana (Helm)"
    echo "  - Supprimer cAdvisor"
    echo "  - Supprimer le namespace monitoring"
    echo ""
    read -p "Êtes-vous sûr de vouloir désinstaller le monitoring? [y/N]: " confirm

    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${YELLOW}Désinstallation de Prometheus/Grafana...${NC}"

        log_info "Suppression Prometheus via Helm"
        helm uninstall prometheus -n monitoring 2>/dev/null || true
        kubectl delete daemonset cadvisor -n monitoring 2>/dev/null || true
        kubectl delete namespace monitoring 2>/dev/null || true

        log_success "Monitoring désinstallé"
        echo -e "${GREEN}✓ Monitoring désinstallé${NC}"

        # Notification
        if type -t notify_info &>/dev/null; then
            notify_info "Monitoring désinstallé" "Suppression réussie de Prometheus, Grafana et cAdvisor"
        fi
    else
        log_info "Désinstallation Monitoring annulée"
        echo -e "${YELLOW}Désinstallation annulée${NC}"
    fi
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
}

# Désinstallation Calico
uninstall_calico() {
    log_info "Début désinstallation Calico"
    show_header
    echo -e "${RED}═══ DÉSINSTALLATION DE CALICO CNI ═══${NC}"
    echo ""
    echo -e "${YELLOW}Cette action va:${NC}"
    echo "  - Supprimer tous les composants Calico"
    echo "  - Supprimer les CustomResourceDefinitions Calico"
    echo "  - Nettoyer les configurations réseau"
    echo ""
    echo -e "${RED}⚠️  ATTENTION: Cette action affectera la connectivité réseau du cluster${NC}"
    echo ""
    read -p "Êtes-vous sûr de vouloir désinstaller Calico? [y/N]: " confirm

    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${YELLOW}Désinstallation de Calico...${NC}"

        log_info "Suppression composants Calico"
        kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/calico.yaml 2>/dev/null || true
        kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.0/manifests/calico.yaml 2>/dev/null || true

        # Nettoyage CRDs
        kubectl delete crd $(kubectl get crd | grep calico | awk '{print $1}') 2>/dev/null || true

        log_success "Calico désinstallé"
        echo -e "${GREEN}✓ Calico désinstallé${NC}"

        # Notification
        if type -t notify_warn &>/dev/null; then
            notify_warn "Calico désinstallé" "CNI supprimé - Le réseau cluster est impacté"
        fi
    else
        log_info "Désinstallation Calico annulée"
        echo -e "${YELLOW}Désinstallation annulée${NC}"
    fi
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
}

# Désinstallation keepalived
uninstall_keepalived() {
    log_info "Début désinstallation keepalived"
    show_header
    echo -e "${RED}═══ DÉSINSTALLATION DE KEEPALIVED ═══${NC}"
    echo ""
    echo -e "${YELLOW}Cette action va:${NC}"
    echo "  - Arrêter et désactiver keepalived"
    echo "  - Désinstaller le paquet keepalived"
    echo "  - Supprimer les configurations"
    echo ""
    echo -e "${RED}⚠️  ATTENTION: Cette action supprimera la VIP (haute disponibilité)${NC}"
    echo ""
    read -p "Êtes-vous sûr de vouloir désinstaller keepalived? [y/N]: " confirm

    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${YELLOW}Désinstallation de keepalived...${NC}"

        log_info "Arrêt du service keepalived"
        systemctl stop keepalived 2>/dev/null || true
        systemctl disable keepalived 2>/dev/null || true

        log_info "Désinstallation du paquet"
        apt-get remove --purge -y keepalived 2>/dev/null || true

        log_info "Suppression des configurations"
        rm -f /etc/keepalived/keepalived.conf 2>/dev/null || true

        log_success "keepalived désinstallé"
        echo -e "${GREEN}✓ keepalived désinstallé${NC}"

        # Notification
        if type -t notify_warn &>/dev/null; then
            notify_warn "keepalived désinstallé" "VIP supprimée - Haute disponibilité désactivée"
        fi
    else
        log_info "Désinstallation keepalived annulée"
        echo -e "${YELLOW}Désinstallation annulée${NC}"
    fi
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
}

# Désinstallation COMPLÈTE
uninstall_complete() {
    log_warn "Demande de désinstallation COMPLÈTE du cluster"
    show_header
    echo -e "${RED}${BOLD}═══ DÉSINSTALLATION COMPLÈTE DU CLUSTER ═══${NC}"
    echo ""
    echo -e "${RED}${BOLD}⚠️  DANGER: CETTE ACTION EST IRRÉVERSIBLE ⚠️${NC}"
    echo ""
    echo -e "${YELLOW}Cette action va:${NC}"
    echo "  1. Supprimer tous les add-ons (MetalLB, Rancher, Monitoring)"
    echo "  2. Supprimer Calico CNI"
    echo "  3. Réinitialiser le nœud Kubernetes (kubeadm reset)"
    echo "  4. Désinstaller Kubernetes (kubelet, kubeadm, kubectl)"
    echo "  5. Désinstaller keepalived"
    echo "  6. Nettoyer tous les fichiers et configurations"
    echo ""
    echo -e "${RED}${BOLD}TOUTES VOS DONNÉES CLUSTER SERONT PERDUES !${NC}"
    echo ""
    read -p "Tapez 'DELETE' en majuscules pour confirmer: " confirm

    if [[ "$confirm" == "DELETE" ]]; then
        echo ""
        log_error "Désinstallation COMPLÈTE confirmée"

        # Notification critique
        if type -t notify_critical &>/dev/null; then
            notify_critical "Désinstallation complète démarrée" "Suppression totale du cluster Kubernetes"
        fi

        # 1. Add-ons
        echo -e "${YELLOW}[1/6] Suppression des add-ons...${NC}"
        log_info "Suppression MetalLB"
        kubectl delete namespace metallb-system 2>/dev/null || true
        log_info "Suppression Rancher"
        helm uninstall rancher -n cattle-system 2>/dev/null || true
        kubectl delete namespace cattle-system cert-manager 2>/dev/null || true
        log_info "Suppression Monitoring"
        helm uninstall prometheus -n monitoring 2>/dev/null || true
        kubectl delete namespace monitoring 2>/dev/null || true

        # 2. Calico
        echo -e "${YELLOW}[2/6] Suppression de Calico...${NC}"
        log_info "Suppression Calico"
        kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/calico.yaml 2>/dev/null || true
        kubectl delete crd $(kubectl get crd 2>/dev/null | grep calico | awk '{print $1}') 2>/dev/null || true

        # 3. Reset Kubernetes
        echo -e "${YELLOW}[3/6] Réinitialisation Kubernetes...${NC}"
        log_info "kubeadm reset"
        kubeadm reset -f 2>/dev/null || true

        # 4. Désinstallation paquets
        echo -e "${YELLOW}[4/6] Désinstallation paquets Kubernetes...${NC}"
        log_info "Désinstallation kubelet, kubeadm, kubectl"
        apt-mark unhold kubelet kubeadm kubectl 2>/dev/null || true
        apt-get remove --purge -y kubelet kubeadm kubectl 2>/dev/null || true
        apt-get autoremove -y 2>/dev/null || true

        # 5. keepalived
        echo -e "${YELLOW}[5/6] Désinstallation keepalived...${NC}"
        log_info "Désinstallation keepalived"
        systemctl stop keepalived 2>/dev/null || true
        apt-get remove --purge -y keepalived 2>/dev/null || true

        # 6. Nettoyage
        echo -e "${YELLOW}[6/6] Nettoyage des fichiers...${NC}"
        log_info "Nettoyage fichiers et configurations"
        rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd /var/lib/k8s-setup 2>/dev/null || true
        rm -rf /etc/cni /opt/cni 2>/dev/null || true
        rm -rf /var/lib/calico /etc/calico 2>/dev/null || true
        rm -rf /etc/keepalived 2>/dev/null || true
        rm -rf ~/.kube 2>/dev/null || true

        # Nettoyage iptables
        log_info "Nettoyage règles iptables"
        iptables -F 2>/dev/null || true
        iptables -t nat -F 2>/dev/null || true
        iptables -t mangle -F 2>/dev/null || true
        iptables -X 2>/dev/null || true

        log_success "Désinstallation COMPLÈTE terminée"
        echo ""
        echo -e "${GREEN}${BOLD}✓ Désinstallation COMPLÈTE terminée${NC}"
        echo ""
        echo -e "${CYAN}Le serveur est maintenant propre.${NC}"
        echo -e "${CYAN}Vous pouvez réinstaller Kubernetes si nécessaire.${NC}"

        # Notification finale
        if type -t notify_critical &>/dev/null; then
            notify_critical "Désinstallation complète terminée" "Cluster Kubernetes entièrement supprimé"
        fi
    else
        log_info "Désinstallation COMPLÈTE annulée"
        echo -e "${YELLOW}Désinstallation annulée (confirmation incorrecte)${NC}"
    fi
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
}

################################################################################
# MENU PRINCIPAL
################################################################################

main() {
    while true; do
        show_menu
        read choice

        case $choice in
            1)
                uninstall_metallb
                ;;
            2)
                uninstall_rancher
                ;;
            3)
                uninstall_monitoring
                ;;
            4)
                uninstall_calico
                ;;
            5)
                uninstall_keepalived
                ;;
            6)
                uninstall_complete
                ;;
            0)
                echo ""
                log_info "Sortie du script de désinstallation"
                echo -e "${CYAN}Au revoir !${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo ""
                echo -e "${RED}Option invalide. Veuillez réessayer.${NC}"
                sleep 2
                ;;
        esac
    done
}

# Lancement du script
main
