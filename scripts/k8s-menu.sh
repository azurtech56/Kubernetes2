#!/bin/bash
################################################################################
# Menu interactif pour l'installation et la gestion de Kubernetes HA
# Compatible avec: Ubuntu 20.04/22.04/24.04 - Debian 12/13
# Auteur: azurtech56
# Version: 1.0
################################################################################

# Charger la configuration et la librairie
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Charger la librairie de configuration
if [ -f "$SCRIPT_DIR/lib-config.sh" ]; then
    source "$SCRIPT_DIR/lib-config.sh"
else
    echo "Erreur: lib-config.sh non trouvé dans $SCRIPT_DIR"
    exit 1
fi

# Charger et valider la configuration
load_kubernetes_config "$SCRIPT_DIR" || exit 1

# Extraire version majeure.mineure (ex: 1.33 depuis 1.33.0)
K8S_MAJOR_MINOR=$(get_k8s_major_minor)

# ============================================================================
# CONSTANTES DE MENU - Magic numbers éliminés
# ============================================================================
readonly MENU_INSTALL_WIZARD=1
readonly MENU_STEP_BY_STEP=2
readonly MENU_ADDONS=3
readonly MENU_MANAGEMENT=4
readonly MENU_DIAGNOSTICS=5
readonly MENU_HELP=6
readonly MENU_EXIT=0

# Sous-menus - Installation par étapes
readonly MENU_STEP_COMMON=1
readonly MENU_STEP_MASTER=2
readonly MENU_STEP_WORKER=3
readonly MENU_STEP_KEEPALIVED=4
readonly MENU_STEP_INIT_CLUSTER=5
readonly MENU_STEP_CALICO=6
readonly MENU_STEP_STORAGE=7

# Sous-menus - Add-ons
readonly MENU_ADDON_METALLB=1
readonly MENU_ADDON_RANCHER=2
readonly MENU_ADDON_MONITORING=3
readonly MENU_ADDON_ALL=4

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ============================================================================
# MENU HELPERS - Fonctions utilitaires pour affichage de menus
# ============================================================================

# Fonction pour afficher le titre
show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}${GREEN}Kubernetes ${K8S_MAJOR_MINOR} - Haute Disponibilité (HA)${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}Menu d'installation et de gestion${NC}                        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Afficher l'en-tête d'une section de menu
display_menu_header() {
    local title=$1
    show_header
    echo -e "${BOLD}${BLUE}═══ ${title} ═══${NC}"
    echo ""
}

# Afficher une option de menu
display_menu_option() {
    local number=$1
    local description=$2
    local color=${3:-"GREEN"}
    echo -e "${!color}[${number}]${NC}  ${description}"
}

# Afficher un titre de section dans un menu
display_menu_section() {
    local title=$1
    echo -e "${MAGENTA}▶ ${title}${NC}"
}

# Afficher le séparateur de fin de menu
display_menu_separator() {
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
}

# Obtenir une entrée utilisateur validée pour menu
get_menu_choice() {
    local min=$1
    local max=$2
    local prompt="${3:-Votre choix: }"

    while true; do
        echo -ne "${YELLOW}${prompt}${NC}"
        read choice

        # Vérifier que c'est un nombre
        if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}✗ Erreur: Entrez un nombre${NC}"
            sleep 1
            continue
        fi

        # Vérifier la plage
        if [ "$choice" -lt "$min" ] || [ "$choice" -gt "$max" ]; then
            echo -e "${RED}✗ Erreur: Entrez un nombre entre ${min} et ${max}${NC}"
            sleep 1
            continue
        fi

        echo "$choice"
        return 0
    done
}

# Exécuter une commande watch
run_watch_command() {
    local label=$1
    local command=$2
    local interval=${3:-2}

    echo ""
    echo -e "${YELLOW}Mode watch activé (${interval}s) - Appuyez sur Ctrl+C pour quitter${NC}"
    echo ""
    watch -n "$interval" -c "$command"
}

# ============================================================================
# GENERIC MENU LOOP - Gestionnaire générique de boucle menu
# ============================================================================
# Usage: run_generic_menu_loop show_function_name handler_function_name
run_generic_menu_loop() {
    local menu_function=$1
    local handler_function=$2

    while true; do
        "$menu_function"
        choice=$(get_menu_choice 0 9)  # Plage générique 0-9

        if [ "$choice" = "0" ]; then
            break
        fi

        # Appeler le handler avec le choix
        "$handler_function" "$choice" || {
            echo -e "${RED}✗ Choix invalide${NC}"
            sleep 1
        }
    done
}

# Fonction pour afficher le menu principal
show_main_menu() {
    show_header
    echo -e "${BOLD}${BLUE}═══ MENU PRINCIPAL ═══${NC}"
    echo ""
    echo -e "${GREEN}[1]${NC}  Installation complète (Assistant)"
    echo -e "${GREEN}[2]${NC}  Installation par étapes"
    echo -e "${GREEN}[3]${NC}  Installation des Add-ons"
    echo -e "${GREEN}[4]${NC}  Gestion du cluster"
    echo -e "${GREEN}[5]${NC}  Vérifications et diagnostics"
    echo -e "${GREEN}[6]${NC}  Informations et aide"
    echo ""
    echo -e "${RED}[0]${NC}  Quitter"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -ne "${YELLOW}Votre choix: ${NC}"
}

# Menu installation par étapes
show_step_menu() {
    show_header
    echo -e "${BOLD}${BLUE}═══ INSTALLATION PAR ÉTAPES ═══${NC}"
    echo ""
    echo -e "${MAGENTA}▶ Préparation (sur tous les nœuds)${NC}"
    echo -e "${GREEN}[1]${NC}  Configuration commune (common-setup.sh)"
    echo -e "${GREEN}[2]${NC}  Configuration Master (master-setup.sh)"
    echo -e "${GREEN}[3]${NC}  Configuration Worker (worker-setup.sh)"
    echo ""
    echo -e "${MAGENTA}▶ Haute Disponibilité (HA)${NC}"
    echo -e "${GREEN}[4]${NC}  Configuration keepalived (setup-keepalived.sh)"
    echo ""
    echo -e "${MAGENTA}▶ Cluster${NC}"
    echo -e "${GREEN}[5]${NC}  Initialisation du cluster (init-cluster.sh)"
    echo -e "${GREEN}[6]${NC}  Installation Calico CNI (install-calico.sh)"
    echo -e "${GREEN}[7]${NC}  Installation Storage Provisioner (install-storage.sh)"
    echo ""
    echo -e "${RED}[0]${NC}  Retour au menu principal"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -ne "${YELLOW}Votre choix: ${NC}"
}

# Menu add-ons
show_addons_menu() {
    show_header
    echo -e "${BOLD}${BLUE}═══ INSTALLATION DES ADD-ONS ═══${NC}"
    echo ""
    echo -e "${GREEN}[1]${NC}  MetalLB - Load Balancer (install-metallb.sh)"
    echo -e "${GREEN}[2]${NC}  Rancher - Interface Web (install-rancher.sh)"
    echo -e "${GREEN}[3]${NC}  Monitoring - Prometheus + Grafana (install-monitoring.sh)"
    echo -e "${GREEN}[4]${NC}  Installer tous les add-ons"
    echo ""
    echo -e "${RED}[0]${NC}  Retour au menu principal"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -ne "${YELLOW}Votre choix: ${NC}"
}

# Menu gestion
show_management_menu() {
    show_header
    echo -e "${BOLD}${BLUE}═══ GESTION DU CLUSTER ═══${NC}"
    echo ""
    echo -e "${MAGENTA}▶ Configuration${NC}"
    echo -e "${GREEN}[1]${NC}  Générer /etc/hosts sur les nœuds"
    echo ""
    echo -e "${MAGENTA}▶ Informations${NC}"
    echo -e "${GREEN}[2]${NC}  Afficher les nœuds"
    echo -e "${GREEN}[3]${NC}  Afficher tous les pods"
    echo -e "${GREEN}[4]${NC}  Afficher les services LoadBalancer"
    echo -e "${GREEN}[5]${NC}  État du cluster (cluster-info)"
    echo ""
    echo -e "${MAGENTA}▶ Tokens et certificats${NC}"
    echo -e "${GREEN}[6]${NC}  Générer commande kubeadm join"
    echo -e "${GREEN}[7]${NC}  Vérifier expiration des certificats"
    echo ""
    echo -e "${MAGENTA}▶ Mots de passe${NC}"
    echo -e "${GREEN}[8]${NC}  Récupérer mot de passe Grafana"
    echo -e "${GREEN}[9]${NC}  Récupérer mot de passe Rancher"
    echo ""
    echo -e "${RED}[0]${NC}  Retour au menu principal"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -ne "${YELLOW}Votre choix: ${NC}"
}

# Menu diagnostics
show_diagnostic_menu() {
    show_header
    echo -e "${BOLD}${BLUE}═══ VÉRIFICATIONS ET DIAGNOSTICS ═══${NC}"
    echo ""
    echo -e "${GREEN}[1]${NC}  Vérifier l'état des pods système"
    echo -e "${GREEN}[2]${NC}  Vérifier keepalived et IP virtuelle"
    echo -e "${GREEN}[3]${NC}  Vérifier MetalLB"
    echo -e "${GREEN}[4]${NC}  Vérifier Calico"
    echo -e "${GREEN}[5]${NC}  Logs des pods (sélection interactive)"
    echo -e "${GREEN}[6]${NC}  Test de déploiement nginx"
    echo -e "${GREEN}[7]${NC}  Rapport complet du cluster"
    echo ""
    echo -e "${RED}[0]${NC}  Retour au menu principal"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -ne "${YELLOW}Votre choix: ${NC}"
}

# Menu aide
show_help_menu() {
    show_header
    echo -e "${BOLD}${BLUE}═══ INFORMATIONS ET AIDE ═══${NC}"
    echo ""
    echo -e "${GREEN}[1]${NC}  Architecture du cluster"
    echo -e "${GREEN}[2]${NC}  Ordre d'installation recommandé"
    echo -e "${GREEN}[3]${NC}  Ports utilisés"
    echo -e "${GREEN}[4]${NC}  Commandes utiles"
    echo -e "${GREEN}[5]${NC}  À propos"
    echo ""
    echo -e "${RED}[0]${NC}  Retour au menu principal"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -ne "${YELLOW}Votre choix: ${NC}"
}

# Fonction unifiée pour exécuter un script avec ou sans privilèges root
# Usage: run_script_with_privilege "./script.sh" [true|false]
# Default: true (utilise sudo)
run_script_with_privilege() {
    local script=$1
    local use_sudo=${2:-true}

    echo ""
    echo -e "${YELLOW}Exécution de ${script}...${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"

    # Validation: vérifier que le script existe
    if [ ! -f "$script" ]; then
        echo -e "${RED}✗ Script non trouvé: $script${NC}"
        echo ""
        read -p "Appuyez sur Entrée pour continuer..."
        return 1
    fi

    # Rendre le script exécutable
    chmod +x "$script"

    # Exécuter avec ou sans sudo
    if [[ "$use_sudo" == true ]]; then
        sudo "$script"
    else
        "$script"
    fi

    local exit_code=$?
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ Script exécuté avec succès${NC}"
    else
        echo -e "${RED}✗ Erreur lors de l'exécution (code: $exit_code)${NC}"
    fi

    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
    return $exit_code
}

# Wrappers de compatibilité (deprecated - utiliser run_script_with_privilege)
run_script() {
    run_script_with_privilege "$1" true
}

run_script_no_sudo() {
    run_script_with_privilege "$1" false
}

# Fonction pour afficher l'architecture
show_architecture() {
    show_header
    echo -e "${BOLD}${BLUE}═══ ARCHITECTURE DU CLUSTER ═══${NC}"
    echo ""
    echo "                    ┌─────────────────┐"
    echo "                    │   IP Virtuelle  │"
    echo "                    │     ${VIP}    │"
    echo "                    │    (${VIP_HOSTNAME})      │"
    echo "                    └────────┬────────┘"
    echo "                             │"
    echo "        ┌────────────────────┼────────────────────┐"
    echo "        │                    │                    │"
    echo "   ┌────▼────┐          ┌────▼────┐          ┌────▼────┐"
    echo "   │ Master1 │          │ Master2 │          │ Master3 │"
    echo "   │${MASTER1_HOSTNAME}  │          │${MASTER2_HOSTNAME}  │          │${MASTER3_HOSTNAME}  │"
    echo "   │${MASTER1_IP##*.} │          │${MASTER2_IP##*.} │          │${MASTER3_IP##*.} │"
    echo "   └─────────┘          └─────────┘          └─────────┘"
    echo ""
    echo -e "${YELLOW}Configuration réseau:${NC}"
    echo "  • IP Virtuelle (VIP): ${VIP} → ${VIP_HOSTNAME}.${DOMAIN_NAME}"
    echo "  • Master 1: ${MASTER1_IP} → ${MASTER1_HOSTNAME}.${DOMAIN_NAME}"
    echo "  • Master 2: ${MASTER2_IP} → ${MASTER2_HOSTNAME}.${DOMAIN_NAME}"
    echo "  • Master 3: ${MASTER3_IP} → ${MASTER3_HOSTNAME}.${DOMAIN_NAME}"
    # Calcul optimisé sans subshells externes
    local start_octet="${METALLB_IP_START##*.}"
    local end_octet="${METALLB_IP_END##*.}"
    METALLB_COUNT=$((end_octet - start_octet))
    echo "  • MetalLB Pool: ${METALLB_IP_START}-${METALLB_IP_END} (${METALLB_COUNT} IPs)"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
}

# Fonction pour afficher l'ordre d'installation
show_installation_order() {
    show_header
    echo -e "${BOLD}${BLUE}═══ ORDRE D'INSTALLATION RECOMMANDÉ ═══${NC}"
    echo ""
    echo -e "${YELLOW}1. Sur TOUS les nœuds (masters et workers):${NC}"
    echo "   → common-setup.sh"
    echo ""
    echo -e "${YELLOW}2. Sur TOUS les masters (k8s01-1, k8s01-2, k8s01-3):${NC}"
    echo "   → master-setup.sh"
    echo "   → setup-keepalived.sh (choisir le bon rôle)"
    echo ""
    echo -e "${YELLOW}3. Sur le PREMIER master UNIQUEMENT (k8s01-1):${NC}"
    echo "   → init-cluster.sh"
    echo "   → install-calico.sh"
    echo ""
    echo -e "${YELLOW}4. Sur les autres masters (k8s01-2 et k8s01-3):${NC}"
    echo "   → Utiliser la commande kubeadm join --control-plane"
    echo ""
    echo -e "${YELLOW}5. Sur TOUS les workers:${NC}"
    echo "   → worker-setup.sh"
    echo "   → Utiliser la commande kubeadm join (sans --control-plane)"
    echo ""
    echo -e "${YELLOW}6. Add-ons optionnels (sur le premier master):${NC}"
    echo "   → install-metallb.sh"
    echo "   → install-rancher.sh"
    echo "   → install-monitoring.sh"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
}

# Assistant d'installation
installation_wizard() {
    show_header
    echo -e "${BOLD}${BLUE}═══ ASSISTANT D'INSTALLATION ═══${NC}"
    echo ""
    echo -e "${YELLOW}Cet assistant vous guidera dans l'installation complète.${NC}"
    echo ""
    echo -e "${BLUE}Quel est le rôle de ce nœud?${NC}"
    echo -e "${GREEN}[1]${NC}  Premier Master (k8s01-1)"
    echo -e "${GREEN}[2]${NC}  Master secondaire (k8s01-2 ou k8s01-3)"
    echo -e "${GREEN}[3]${NC}  Worker"
    echo -e "${RED}[0]${NC}  Annuler"
    echo ""
    echo -ne "${YELLOW}Votre choix: ${NC}"
    read role_choice

    case $role_choice in
        1)
            # Premier master
            show_header
            echo -e "${BOLD}${GREEN}Installation du Premier Master (k8s01-1)${NC}"
            echo ""
            echo -e "${YELLOW}Étapes à effectuer:${NC}"
            echo "  1. Configuration commune"
            echo "  2. Configuration master"
            echo "  3. Configuration keepalived (MASTER - Priority 101)"
            echo "  4. Initialisation du cluster"
            echo "  5. Installation Calico"
            echo ""
            read -p "Continuer? [y/N]: " confirm

            if [[ $confirm =~ ^[Yy]$ ]]; then
                run_script "./common-setup.sh"
                run_script "./master-setup.sh"
                run_script "./setup-keepalived.sh"
                run_script "./init-cluster.sh"
                run_script_no_sudo "./install-calico.sh"

                echo ""
                echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
                echo -e "${GREEN}Installation du premier master terminée!${NC}"
                echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
                echo ""
                echo -e "${YELLOW}Prochaines étapes:${NC}"
                echo "  1. Installer les autres masters avec ce menu (option 2)"
                echo "  2. Installer les workers avec ce menu (option 3)"
                echo "  3. Installer les add-ons (MetalLB, Rancher, Monitoring)"
                echo ""
                read -p "Appuyez sur Entrée pour continuer..."
            fi
            ;;
        2)
            # Master secondaire
            show_header
            echo -e "${BOLD}${GREEN}Installation d'un Master Secondaire${NC}"
            echo ""
            echo -e "${YELLOW}Étapes à effectuer:${NC}"
            echo "  1. Configuration commune"
            echo "  2. Configuration master"
            echo "  3. Configuration keepalived (BACKUP)"
            echo "  4. Rejoindre le cluster avec kubeadm join --control-plane"
            echo ""
            read -p "Continuer? [y/N]: " confirm

            if [[ $confirm =~ ^[Yy]$ ]]; then
                run_script "./common-setup.sh"
                run_script "./master-setup.sh"
                run_script "./setup-keepalived.sh"

                echo ""
                echo -e "${YELLOW}Utilisez maintenant la commande 'kubeadm join' avec --control-plane${NC}"
                echo -e "${YELLOW}générée lors de l'initialisation du premier master.${NC}"
                echo ""
                read -p "Appuyez sur Entrée pour continuer..."
            fi
            ;;
        3)
            # Worker
            show_header
            echo -e "${BOLD}${GREEN}Installation d'un Worker${NC}"
            echo ""
            echo -e "${YELLOW}Étapes à effectuer:${NC}"
            echo "  1. Configuration commune"
            echo "  2. Configuration worker"
            echo "  3. Rejoindre le cluster avec kubeadm join"
            echo ""
            read -p "Continuer? [y/N]: " confirm

            if [[ $confirm =~ ^[Yy]$ ]]; then
                run_script "./common-setup.sh"
                run_script "./worker-setup.sh"

                echo ""
                echo -e "${YELLOW}Utilisez maintenant la commande 'kubeadm join' (SANS --control-plane)${NC}"
                echo -e "${YELLOW}générée lors de l'initialisation du premier master.${NC}"
                echo ""
                read -p "Appuyez sur Entrée pour continuer..."
            fi
            ;;
    esac
}

# ============================================================================
# HANDLERS - Gestionnaires d'actions pour les menus
# ============================================================================

# Handler pour le menu Gestion du cluster
handle_management_choice() {
    local choice=$1
    case $choice in
        1) ./generate-hosts.sh ;;
        2) run_watch_command "Nœuds" "kubectl get nodes -o wide" ;;
        3) run_watch_command "Pods" "kubectl get pods -A" ;;
        4) run_watch_command "Services LoadBalancer" "kubectl get svc -A | grep -E 'NAMESPACE|LoadBalancer'" ;;
        5)
            kubectl cluster-info
            echo ""
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        6)
            echo ""
            kubeadm token create --print-join-command
            echo ""
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        7)
            echo ""
            kubeadm certs check-expiration
            echo ""
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        8)
            echo ""
            echo -e "${YELLOW}Mot de passe Grafana:${NC}"
            kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 -d
            echo ""
            echo ""
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        9)
            echo ""
            echo -e "${YELLOW}Mot de passe Rancher:${NC}"
            kubectl get secret --namespace cattle-system bootstrap-secret -o jsonpath="{.data.bootstrapPassword}" 2>/dev/null | base64 -d
            echo ""
            echo ""
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        *) return 1 ;;
    esac
}

# Handler pour le menu Diagnostics
handle_diagnostic_choice() {
    local choice=$1
    case $choice in
        1) run_watch_command "Pods système" "kubectl get pods -n kube-system" ;;
        2) run_watch_command "keepalived et IP virtuelle" "echo -e '${GREEN}=== État keepalived ===${NC}' && systemctl status keepalived --no-pager | head -15 && echo '' && echo -e '${GREEN}=== IP Virtuelle ===${NC}' && ip addr | grep -A2 '${VIP}'" ;;
        3) run_watch_command "MetalLB" "echo '=== Pods MetalLB ===' && kubectl get pods -n metallb-system && echo '' && echo '=== IP Pools ===' && kubectl get ipaddresspools.metallb.io -n metallb-system" ;;
        4) run_watch_command "Calico" "kubectl get pods -n kube-system | grep -E 'NAME|calico'" ;;
        5)
            echo ""
            kubectl get pods -A
            echo ""
            read -p "Namespace du pod: " ns
            read -p "Nom du pod: " pod
            echo ""
            kubectl logs -n "$ns" "$pod"
            echo ""
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        6)
            echo ""
            echo -e "${YELLOW}Création d'un déploiement nginx de test...${NC}"
            kubectl create deployment nginx-test --image=nginx
            kubectl expose deployment nginx-test --port=80 --type=LoadBalancer
            sleep 5
            kubectl get svc nginx-test
            echo ""
            echo -e "${YELLOW}Pour supprimer le test:${NC}"
            echo "kubectl delete svc nginx-test"
            echo "kubectl delete deployment nginx-test"
            echo ""
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        7)
            show_header
            echo -e "${BOLD}${BLUE}═══ RAPPORT COMPLET DU CLUSTER ═══${NC}"
            echo ""
            echo -e "${YELLOW}▶ Nœuds:${NC}"
            kubectl get nodes -o wide
            echo ""
            echo -e "${YELLOW}▶ Pods système:${NC}"
            kubectl get pods -n kube-system
            echo ""
            echo -e "${YELLOW}▶ Services LoadBalancer:${NC}"
            kubectl get svc -A | grep LoadBalancer
            echo ""
            echo -e "${YELLOW}▶ État du cluster:${NC}"
            kubectl cluster-info
            echo ""
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        *) return 1 ;;
    esac
}

# Handler pour le menu Aide/Help
handle_help_choice() {
    local choice=$1
    case $choice in
        1) show_architecture ;;
        2) show_installation_order ;;
        3)
            show_header
            echo -e "${BOLD}${BLUE}═══ PORTS UTILISÉS ═══${NC}"
            echo ""
            echo -e "${YELLOW}Masters:${NC}"
            echo "  • 6443    - Kubernetes API server"
            echo "  • 2379    - etcd client"
            echo "  • 2380    - etcd peer"
            echo "  • 10250   - Kubelet API"
            echo "  • 10251   - kube-scheduler"
            echo "  • 10252   - kube-controller-manager"
            echo "  • 10255   - Read-only Kubelet API"
            echo "  • VRRP    - keepalived"
            echo ""
            echo -e "${YELLOW}Workers:${NC}"
            echo "  • 10250   - Kubelet API"
            echo "  • 30000-32767 - NodePort Services"
            echo ""
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        4)
            show_header
            echo -e "${BOLD}${BLUE}═══ COMMANDES UTILES ═══${NC}"
            echo ""
            echo -e "${YELLOW}Cluster:${NC}"
            echo "  kubectl get nodes"
            echo "  kubectl get pods -A"
            echo "  kubectl cluster-info"
            echo ""
            echo -e "${YELLOW}Diagnostics:${NC}"
            echo "  kubectl describe node <nom>"
            echo "  kubectl logs -n <namespace> <pod>"
            echo "  kubectl top nodes"
            echo ""
            echo -e "${YELLOW}keepalived:${NC}"
            echo "  systemctl status keepalived"
            echo "  journalctl -u keepalived -f"
            echo "  ip addr show"
            echo ""
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        5)
            show_header
            echo -e "${BOLD}${BLUE}═══ À PROPOS ═══${NC}"
            echo ""
            echo -e "${GREEN}Kubernetes ${K8S_MAJOR_MINOR} - Haute Disponibilité${NC}"
            echo "Version: 1.0"
            echo ""
            echo "Scripts d'installation automatisés pour un cluster"
            echo "Kubernetes en haute disponibilité avec keepalived."
            echo ""
            echo -e "${YELLOW}Composants:${NC}"
            echo "  • Kubernetes ${K8S_MAJOR_MINOR}"
            echo "  • keepalived (HA)"
            echo "  • Calico (CNI)"
            echo "  • MetalLB (Load Balancer)"
            echo "  • Rancher (Interface Web)"
            echo "  • Prometheus + Grafana (Monitoring)"
            echo ""
            echo -e "${YELLOW}Compatible avec:${NC}"
            echo "  • Ubuntu 20.04/22.04/24.04"
            echo "  • Debian 12/13"
            echo ""
            echo -e "${YELLOW}Projet Open Source${NC}"
            echo ""
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        *) return 1 ;;
    esac
}

# Gestion du cluster
manage_cluster() {
    run_generic_menu_loop show_management_menu handle_management_choice
}

# Diagnostics
run_diagnostics() {
    run_generic_menu_loop show_diagnostic_menu handle_diagnostic_choice
}

# Menu aide détaillé
help_menu() {
    run_generic_menu_loop show_help_menu handle_help_choice
}

# Boucle principale
main() {
    while true; do
        show_main_menu
        read choice

        case $choice in
            1)
                installation_wizard
                ;;
            2)
                # Menu installation par étapes
                while true; do
                    show_step_menu
                    read step_choice

                    case $step_choice in
                        1) run_script "./common-setup.sh" ;;
                        2) run_script "./master-setup.sh" ;;
                        3) run_script "./worker-setup.sh" ;;
                        4) run_script "./setup-keepalived.sh" ;;
                        5) run_script "./init-cluster.sh" ;;
                        6) run_script_no_sudo "./install-calico.sh" ;;
                        7) run_script_no_sudo "./install-storage.sh" ;;
                        0) break ;;
                        *)
                            echo -e "${RED}Choix invalide${NC}"
                            sleep 1
                            ;;
                    esac
                done
                ;;
            3)
                # Menu add-ons
                while true; do
                    show_addons_menu
                    read addon_choice

                    case $addon_choice in
                        1) run_script_no_sudo "./install-metallb.sh" ;;
                        2) run_script_no_sudo "./install-rancher.sh" ;;
                        3) run_script_no_sudo "./install-monitoring.sh" ;;
                        4)
                            run_script_no_sudo "./install-metallb.sh"
                            run_script_no_sudo "./install-rancher.sh"
                            run_script_no_sudo "./install-monitoring.sh"
                            ;;
                        0) break ;;
                        *)
                            echo -e "${RED}Choix invalide${NC}"
                            sleep 1
                            ;;
                    esac
                done
                ;;
            4)
                manage_cluster
                ;;
            5)
                run_diagnostics
                ;;
            6)
                help_menu
                ;;
            0)
                show_header
                echo -e "${GREEN}Merci d'avoir utilisé le menu Kubernetes HA!${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}Choix invalide${NC}"
                sleep 1
                ;;
        esac
    done
}

# Vérifier si on est dans le bon répertoire
if [ ! -f "common-setup.sh" ]; then
    echo -e "${RED}Erreur: Scripts non trouvés dans le répertoire courant${NC}"
    echo -e "${YELLOW}Veuillez exécuter ce script depuis le répertoire scripts/${NC}"
    exit 1
fi

# Lancer le menu principal
main
