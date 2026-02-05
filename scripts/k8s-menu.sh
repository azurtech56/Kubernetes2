#!/bin/bash
################################################################################
# Menu interactif pour l'installation et la gestion de Kubernetes HA
# Compatible avec: Ubuntu 20.04/22.04/24.04 - Debian 12/13
# Auteur: azurtech56
# Version: 1.0
################################################################################

# ============================================================================
# COULEURS
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

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

# ============================================================================
# CHARGEMENT CONFIGURATION CENTRALISÉE
# ============================================================================
# Charger la configuration globalement une seule fois
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Charger lib-config si disponible (optionnel - pour validation)
if [ -f "$SCRIPT_DIR/lib-config.sh" ]; then
    source "$SCRIPT_DIR/lib-config.sh" 2>/dev/null
fi

# Charger la configuration
if [ -f "./config.sh" ]; then
    source "./config.sh"
    K8S_DISPLAY_VERSION="${K8S_VERSION:-1.33}"
else
    K8S_DISPLAY_VERSION="1.33"
fi

# ============================================================================
# MENU HELPERS - Fonctions utilitaires pour affichage
# ============================================================================

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

# Fonction unifiée pour exécuter un script avec ou sans privilèges root
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


# Fonction pour afficher le titre
show_header() {
    clear

    # Calculer les espaces nécessaires pour l'alignement (62 caractères au total)
    local title="Kubernetes ${K8S_DISPLAY_VERSION} - Haute Disponibilité (HA)"
    local title_length=${#title}
    local padding_needed=$((62 - title_length - 2))  # -2 pour les espaces au début
    local padding=$(printf '%*s' "$padding_needed" '')

    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}${GREEN}${title}${NC}${padding}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}Menu d'installation et de gestion${NC}                        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Fonction pour afficher le menu principal
show_main_menu() {
    show_header
    echo -e "${BOLD}${BLUE}═══ MENU PRINCIPAL ═══${NC}"
    echo ""
    echo -e "${BOLD}${GREEN}[1]  🚀 Déploiement automatique complet${NC} ${YELLOW}(Recommandé)${NC}"
    echo -e "     ${CYAN}Installation complète depuis le master vers tous les workers${NC}"
    echo ""
    echo -e "${GREEN}[2]${NC}  Installation guidée (Assistant)"
    echo -e "${GREEN}[3]${NC}  Installation par étapes"
    echo -e "${GREEN}[4]${NC}  Installation des Add-ons"
    echo -e "${GREEN}[5]${NC}  Gestion du cluster"
    echo -e "${GREEN}[6]${NC}  Vérifications et diagnostics"
    echo -e "${GREEN}[7]${NC}  Informations et aide"
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
    echo -e "${GREEN}[1]${NC}  Configuration commune (core/common-setup.sh)"
    echo -e "${GREEN}[2]${NC}  Configuration Master (core/master-setup.sh)"
    echo -e "${GREEN}[3]${NC}  Configuration Worker (core/worker-setup.sh)"
    echo ""
    echo -e "${MAGENTA}▶ Haute Disponibilité (HA)${NC}"
    echo -e "${GREEN}[4]${NC}  Configuration keepalived (core/setup-keepalived.sh)"
    echo ""
    echo -e "${MAGENTA}▶ Cluster${NC}"
    echo -e "${GREEN}[5]${NC}  Initialisation du cluster (core/init-cluster.sh)"
    echo -e "${GREEN}[6]${NC}  Installation Calico CNI (core/install-calico.sh)"
    echo ""
    echo -e "${RED}[0]${NC}  Retour au menu principal"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -ne "${YELLOW}Votre choix: ${NC}"
}

# Menu add-ons
show_addons_menu() {
    show_header
    echo -e "${BOLD}${BLUE}═══ GESTION DES ADD-ONS ═══${NC}"
    echo ""
    echo -e "${MAGENTA}▶ Installation${NC}"
    echo -e "${GREEN}[1]${NC}  MetalLB - Load Balancer"
    echo -e "${GREEN}[2]${NC}  Rancher - Interface Web"
    echo -e "${GREEN}[3]${NC}  Monitoring - Prometheus + Grafana"
    echo -e "${GREEN}[4]${NC}  Installer tous les add-ons"
    echo ""
    echo -e "${MAGENTA}▶ Désinstallation${NC}"
    echo -e "${RED}[5]${NC}  Désinstaller MetalLB"
    echo -e "${RED}[6]${NC}  Désinstaller Rancher"
    echo -e "${RED}[7]${NC}  Désinstaller Monitoring"
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
    echo -e "${MAGENTA}▶ Avant installation${NC}"
    echo -e "${GREEN}[1]${NC}  Vérifier les prérequis système"
    echo ""
    echo -e "${MAGENTA}▶ Après installation${NC}"
    echo -e "${GREEN}[2]${NC}  Vérifier l'état des pods système"
    echo -e "${GREEN}[3]${NC}  Vérifier keepalived et IP virtuelle"
    echo -e "${GREEN}[4]${NC}  Vérifier MetalLB"
    echo -e "${GREEN}[5]${NC}  Vérifier Calico"
    echo -e "${GREEN}[6]${NC}  Logs des pods (sélection interactive)"
    echo -e "${GREEN}[7]${NC}  Test de déploiement nginx"
    echo -e "${GREEN}[8]${NC}  Rapport complet du cluster"
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

# Fonction pour afficher l'architecture
show_architecture() {
    show_header

    # La configuration est déjà chargée globalement
    # Pas besoin de re-charger config.sh

    echo -e "${BOLD}${BLUE}═══ ARCHITECTURE DU CLUSTER ═══${NC}"
    echo ""
    echo "                    ┌─────────────────┐"
    echo "                    │   IP Virtuelle  │"
    echo "                    │  ${VIP}  │"
    echo "                    │    (${VIP_HOSTNAME})      │"
    echo "                    └────────┬────────┘"
    echo "                             │ (keepalived)"
    echo "                             │"

    # Compter le nombre de masters pour afficher le diagramme
    local total_masters=0
    local temp_num=1
    while true; do
        local ip_var="MASTER${temp_num}_IP"
        if [ -n "${!ip_var}" ]; then
            ((total_masters++))
            ((temp_num++))
        else
            break
        fi
    done

    # Affichage dynamique en fonction du nombre de masters
    if [ $total_masters -eq 1 ]; then
        echo "                        ┌────▼────┐"
        echo "                        │ Master1 │"
        echo "                        │${MASTER1_HOSTNAME} │"
        echo "                        │.${MASTER1_IP##*.}    │"
        echo "                        └─────────┘"
    elif [ $total_masters -eq 2 ]; then
        echo "                ┌───────────────┴───────────────┐"
        echo "           ┌────▼────┐                    ┌────▼────┐"
        echo "           │ Master1 │                    │ Master2 │"
        echo "           │${MASTER1_HOSTNAME}  │                    │${MASTER2_HOSTNAME}  │"
        echo "           │.${MASTER1_IP##*.}     │                    │.${MASTER2_IP##*.}     │"
        echo "           └─────────┘                    └─────────┘"
    elif [ $total_masters -eq 3 ]; then
        echo "        ┌────────────────────┼────────────────────┐"
        echo "        │                    │                    │"
        echo "   ┌────▼────┐          ┌────▼────┐          ┌────▼────┐"
        echo "   │ Master1 │          │ Master2 │          │ Master3 │"
        echo "   │${MASTER1_HOSTNAME}  │          │${MASTER2_HOSTNAME}  │          │${MASTER3_HOSTNAME}  │"
        echo "   │.${MASTER1_IP##*.}     │          │.${MASTER2_IP##*.}     │          │.${MASTER3_IP##*.}     │"
        echo "   └─────────┘          └─────────┘          └─────────┘"
    else
        # Plus de 3 masters: affichage en liste
        echo "                        ┌───────────┐"
        local m_num=1
        while true; do
            local ip_var="MASTER${m_num}_IP"
            local hostname_var="MASTER${m_num}_HOSTNAME"
            if [ -n "${!ip_var}" ]; then
                echo "                        │ Master${m_num}  │"
                echo "                        │ ${!hostname_var} │"
                ((m_num++))
            else
                break
            fi
        done
        echo "                        └───────────┘"
    fi
    echo ""
    echo -e "${YELLOW}Configuration réseau:${NC}"
    echo "  • IP Virtuelle (VIP): ${VIP} → ${VIP_HOSTNAME}.${DOMAIN_NAME}"

    # Afficher dynamiquement tous les masters configurés
    master_num=1
    while true; do
        ip_var="MASTER${master_num}_IP"
        hostname_var="MASTER${master_num}_HOSTNAME"
        if [ -n "${!ip_var}" ]; then
            echo "  • Master ${master_num}: ${!ip_var} → ${!hostname_var}.${DOMAIN_NAME}"
            ((master_num++))
        else
            break
        fi
    done

    # Afficher les workers s'ils existent
    worker_num=1
    workers_found=false
    while true; do
        ip_var="WORKER${worker_num}_IP"
        hostname_var="WORKER${worker_num}_HOSTNAME"
        if [ -n "${!ip_var}" ]; then
            if [ "$workers_found" = false ]; then
                echo "  • Workers:"
                workers_found=true
            fi
            echo "    - Worker ${worker_num}: ${!ip_var} → ${!hostname_var}.${DOMAIN_NAME}"
            ((worker_num++))
        else
            break
        fi
    done

    echo "  • MetalLB Pool: ${METALLB_IP_START}-${METALLB_IP_END}"
    echo "  • Pod Network: ${POD_NETWORK:-11.0.0.0/16}"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
}

# Fonction pour afficher l'ordre d'installation
show_installation_order() {
    show_header

    # La configuration est déjà chargée globalement

    echo -e "${BOLD}${BLUE}═══ ORDRE D'INSTALLATION RECOMMANDÉ ═══${NC}"
    echo ""
    echo -e "${YELLOW}1. Sur TOUS les nœuds (masters et workers):${NC}"
    echo "   → common-setup.sh"
    echo ""

    # Affichage dynamique des masters
    local master_list=""
    local master_num=1
    while true; do
        local hostname_var="MASTER${master_num}_HOSTNAME"
        if [ -n "${!hostname_var}" ]; then
            if [ -z "$master_list" ]; then
                master_list="${!hostname_var}"
            else
                master_list="${master_list}, ${!hostname_var}"
            fi
            ((master_num++))
        else
            break
        fi
    done

    echo -e "${YELLOW}2. Sur TOUS les masters (${master_list}):${NC}"
    echo "   → master-setup.sh"
    echo "   → setup-keepalived.sh (choisir le bon rôle)"
    echo ""
    echo -e "${YELLOW}3. Sur le PREMIER master UNIQUEMENT (${MASTER1_HOSTNAME:-master1}):${NC}"
    echo "   → core/init-cluster.sh"
    echo "   → core/install-calico.sh"
    echo ""

    # Afficher les autres masters s'il y en a
    local other_masters=""
    master_num=2
    while true; do
        local hostname_var="MASTER${master_num}_HOSTNAME"
        if [ -n "${!hostname_var}" ]; then
            if [ -z "$other_masters" ]; then
                other_masters="${!hostname_var}"
            else
                other_masters="${other_masters} et ${!hostname_var}"
            fi
            ((master_num++))
        else
            break
        fi
    done

    if [ -n "$other_masters" ]; then
        echo -e "${YELLOW}4. Sur les autres masters (${other_masters}):${NC}"
        echo "   → Utiliser la commande kubeadm join --control-plane"
        echo ""
    fi

    echo -e "${YELLOW}5. Sur TOUS les workers:${NC}"
    echo "   → worker-setup.sh"
    echo "   → Utiliser la commande kubeadm join (sans --control-plane)"
    echo ""
    echo -e "${YELLOW}6. Add-ons optionnels (sur le premier master):${NC}"
    echo "   → addons/install-metallb.sh"
    echo "   → addons/install-rancher.sh"
    echo "   → addons/install-monitoring.sh"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
}

# Assistant d'installation
installation_wizard() {
    show_header

    # La configuration est déjà chargée globalement

    echo -e "${BOLD}${BLUE}═══ ASSISTANT D'INSTALLATION ═══${NC}"
    echo ""
    echo -e "${YELLOW}Cet assistant vous guidera dans l'installation complète.${NC}"
    echo ""
    echo -e "${BLUE}Quel est le rôle de ce nœud?${NC}"
    echo -e "${GREEN}[1]${NC}  Premier Master (${MASTER1_HOSTNAME:-master1})"

    # Construire la liste des masters secondaires
    local secondary_masters=""
    local master_num=2
    while true; do
        local hostname_var="MASTER${master_num}_HOSTNAME"
        if [ -n "${!hostname_var}" ]; then
            if [ -z "$secondary_masters" ]; then
                secondary_masters="${!hostname_var}"
            else
                secondary_masters="${secondary_masters} ou ${!hostname_var}"
            fi
            ((master_num++))
        else
            break
        fi
    done

    if [ -n "$secondary_masters" ]; then
        echo -e "${GREEN}[2]${NC}  Master secondaire (${secondary_masters})"
    else
        echo -e "${GREEN}[2]${NC}  Master secondaire"
    fi

    echo -e "${GREEN}[3]${NC}  Worker"
    echo -e "${RED}[0]${NC}  Annuler"
    echo ""
    echo -ne "${YELLOW}Votre choix: ${NC}"
    read role_choice

    case $role_choice in
        1)
            # Premier master
            show_header
            echo -e "${BOLD}${GREEN}Installation du Premier Master (${MASTER1_HOSTNAME:-master1})${NC}"
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
                run_script_with_privilege "./core/common-setup.sh" true
                run_script_with_privilege "./core/master-setup.sh" true
                run_script_with_privilege "./core/setup-keepalived.sh" true
                run_script_with_privilege "./core/init-cluster.sh" true
                run_script_with_privilege "./core/install-calico.sh" false

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
                run_script_with_privilege "./core/common-setup.sh" true
                run_script_with_privilege "./core/master-setup.sh" true
                run_script_with_privilege "./core/setup-keepalived.sh" true

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
                run_script_with_privilege "./core/common-setup.sh" true
                run_script_with_privilege "./core/worker-setup.sh" true

                echo ""
                echo -e "${YELLOW}Utilisez maintenant la commande 'kubeadm join' (SANS --control-plane)${NC}"
                echo -e "${YELLOW}générée lors de l'initialisation du premier master.${NC}"
                echo ""
                read -p "Appuyez sur Entrée pour continuer..."
            fi
            ;;
    esac
}

# Gestion du cluster
manage_cluster() {
    while true; do
        show_management_menu
        read choice

        case $choice in
            1)
                ./generate-hosts.sh
                ;;
            2)
                echo ""
                echo -e "${YELLOW}Mode watch activé - Appuyez sur Ctrl+C pour quitter${NC}"
                echo ""
                watch -n 2 -c "kubectl get nodes -o wide"
                ;;
            3)
                echo ""
                echo -e "${YELLOW}Mode watch activé - Appuyez sur Ctrl+C pour quitter${NC}"
                echo ""
                watch -n 2 -c "kubectl get pods -A"
                ;;
            4)
                echo ""
                echo -e "${YELLOW}Mode watch activé - Appuyez sur Ctrl+C pour quitter${NC}"
                echo ""
                watch -n 2 -c "kubectl get svc -A | grep -E 'NAMESPACE|LoadBalancer'"
                ;;
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
            0)
                break
                ;;
            *)
                echo -e "${RED}Choix invalide${NC}"
                sleep 1
                ;;
        esac
    done
}

# Diagnostics
run_diagnostics() {
    while true; do
        show_diagnostic_menu
        read choice

        case $choice in
            1)
                # Vérifier les prérequis système
                if [ -f "$SCRIPT_DIR/core/check-prerequisites.sh" ]; then
                    echo ""
                    bash "$SCRIPT_DIR/core/check-prerequisites.sh" "auto"
                    echo ""
                    read -p "Appuyez sur Entrée pour continuer..."
                else
                    echo -e "${RED}✗ Script core/check-prerequisites.sh non trouvé${NC}"
                    read -p "Appuyez sur Entrée pour continuer..."
                fi
                ;;
            2)
                echo ""
                echo -e "${YELLOW}Mode watch activé - Appuyez sur Ctrl+C pour quitter${NC}"
                echo ""
                watch -n 2 -c "kubectl get pods -n kube-system"
                ;;
            3)
                # La configuration est déjà chargée globalement
                VIP_TO_CHECK="${VIP:-192.168.0.200}"
                echo ""
                echo -e "${YELLOW}Mode watch activé - Appuyez sur Ctrl+C pour quitter${NC}"
                echo ""
                watch -n 2 "echo -e '${GREEN}=== État keepalived ===${NC}' && systemctl status keepalived --no-pager | head -15 && echo '' && echo -e '${GREEN}=== IP Virtuelle ===${NC}' && ip addr | grep -A2 '${VIP_TO_CHECK}'"
                ;;
            4)
                echo ""
                echo -e "${YELLOW}Mode watch activé - Appuyez sur Ctrl+C pour quitter${NC}"
                echo ""
                watch -n 2 -c "echo '=== Pods MetalLB ===' && kubectl get pods -n metallb-system && echo '' && echo '=== IP Pools ===' && kubectl get ipaddresspools.metallb.io -n metallb-system"
                ;;
            5)
                echo ""
                echo -e "${YELLOW}Mode watch activé - Appuyez sur Ctrl+C pour quitter${NC}"
                echo ""
                watch -n 2 -c "kubectl get pods -n kube-system | grep -E 'NAME|calico'"
                ;;
            6)
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
            7)
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
            8)
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
            0)
                break
                ;;
            *)
                echo -e "${RED}Choix invalide${NC}"
                sleep 1
                ;;
        esac
    done
}

# Menu aide détaillé
help_menu() {
    while true; do
        show_help_menu
        read choice

        case $choice in
            1)
                show_architecture
                ;;
            2)
                show_installation_order
                ;;
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

                # La configuration est déjà chargée globalement
                echo -e "${BOLD}${BLUE}═══ À PROPOS ═══${NC}"
                echo ""
                echo -e "${GREEN}Kubernetes ${K8S_DISPLAY_VERSION} - Haute Disponibilité${NC}"
                echo "Version: 1.0"
                echo ""
                echo "Scripts d'installation automatisés pour un cluster"
                echo "Kubernetes en haute disponibilité avec keepalived."
                echo ""
                echo -e "${YELLOW}Composants:${NC}"
                echo "  • Kubernetes ${K8S_DISPLAY_VERSION}"
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
            0)
                break
                ;;
            *)
                echo -e "${RED}Choix invalide${NC}"
                sleep 1
                ;;
        esac
    done
}

# Fonction de désinstallation MetalLB
uninstall_metallb() {
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
        kubectl delete ipaddresspools.metallb.io -n metallb-system --all 2>/dev/null || true
        kubectl delete l2advertisements.metallb.io -n metallb-system --all 2>/dev/null || true
        kubectl delete namespace metallb-system 2>/dev/null || true
        echo -e "${GREEN}✓ MetalLB désinstallé${NC}"
    else
        echo -e "${YELLOW}Désinstallation annulée${NC}"
    fi
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
}

# Fonction de désinstallation Rancher
uninstall_rancher() {
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
        helm uninstall rancher -n cattle-system 2>/dev/null || true
        kubectl delete namespace cattle-system 2>/dev/null || true
        echo -e "${YELLOW}Désinstallation de cert-manager...${NC}"
        kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.0/cert-manager.yaml 2>/dev/null || true
        kubectl delete namespace cert-manager 2>/dev/null || true
        echo -e "${GREEN}✓ Rancher et cert-manager désinstallés${NC}"
    else
        echo -e "${YELLOW}Désinstallation annulée${NC}"
    fi
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
}

# Fonction de désinstallation Monitoring
uninstall_monitoring() {
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
        helm uninstall prometheus -n monitoring 2>/dev/null || true
        kubectl delete daemonset cadvisor -n monitoring 2>/dev/null || true
        kubectl delete namespace monitoring 2>/dev/null || true
        echo -e "${GREEN}✓ Monitoring désinstallé${NC}"
    else
        echo -e "${YELLOW}Désinstallation annulée${NC}"
    fi
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
}

# Boucle principale
main() {
    while true; do
        show_main_menu
        read choice

        case $choice in
            1)
                # Déploiement automatique complet
                run_script_with_privilege "./deploy-cluster-auto.sh" true
                ;;
            2)
                installation_wizard
                ;;
            3)
                # Menu installation par étapes
                while true; do
                    show_step_menu
                    read step_choice

                    case $step_choice in
                        1) run_script_with_privilege "./core/common-setup.sh" true ;;
                        2) run_script_with_privilege "./core/master-setup.sh" true ;;
                        3) run_script_with_privilege "./core/worker-setup.sh" true ;;
                        4) run_script_with_privilege "./core/setup-keepalived.sh" true ;;
                        5) run_script_with_privilege "./core/init-cluster.sh" true ;;
                        6) run_script_with_privilege "./core/install-calico.sh" false ;;
                        0) break ;;
                        *)
                            echo -e "${RED}Choix invalide${NC}"
                            sleep 1
                            ;;
                    esac
                done
                ;;
            4)
                # Menu add-ons
                while true; do
                    show_addons_menu
                    read addon_choice

                    case $addon_choice in
                        1) run_script_with_privilege "./addons/install-metallb.sh" false ;;
                        2) run_script_with_privilege "./addons/install-rancher.sh" false ;;
                        3) run_script_with_privilege "./addons/install-monitoring.sh" false ;;
                        4)
                            run_script_with_privilege "./addons/install-metallb.sh" false
                            run_script_with_privilege "./addons/install-rancher.sh" false
                            run_script_with_privilege "./addons/install-monitoring.sh" false
                            ;;
                        5) uninstall_metallb ;;
                        6) uninstall_rancher ;;
                        7) uninstall_monitoring ;;
                        0) break ;;
                        *)
                            echo -e "${RED}Choix invalide${NC}"
                            sleep 1
                            ;;
                    esac
                done
                ;;
            5)
                manage_cluster
                ;;
            6)
                run_diagnostics
                ;;
            7)
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
if [ ! -f "core/common-setup.sh" ]; then
    echo -e "${RED}Erreur: Scripts non trouvés dans le répertoire courant${NC}"
    echo -e "${YELLOW}Veuillez exécuter ce script depuis le répertoire scripts/${NC}"
    exit 1
fi

# Lancer le menu principal
main
