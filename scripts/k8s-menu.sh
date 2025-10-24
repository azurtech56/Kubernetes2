#!/bin/bash
################################################################################
# Menu interactif pour l'installation et la gestion de Kubernetes HA
# Compatible avec: Ubuntu 20.04/22.04/24.04 - Debian 12/13
# Auteur: azurtech56
# Version: 1.0
################################################################################

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Fonction pour afficher le titre
show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}${GREEN}Kubernetes 1.32 - Haute Disponibilité (HA)${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}Menu d'installation et de gestion${NC}                        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
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

# Fonction pour exécuter un script
run_script() {
    local script=$1
    echo ""
    echo -e "${YELLOW}Exécution de ${script}...${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"

    if [ -f "$script" ]; then
        chmod +x "$script"
        sudo "$script"
        local exit_code=$?
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
        if [ $exit_code -eq 0 ]; then
            echo -e "${GREEN}✓ Script exécuté avec succès${NC}"
        else
            echo -e "${RED}✗ Erreur lors de l'exécution (code: $exit_code)${NC}"
        fi
    else
        echo -e "${RED}✗ Script non trouvé: $script${NC}"
    fi

    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
}

# Fonction pour exécuter un script sans sudo
run_script_no_sudo() {
    local script=$1
    echo ""
    echo -e "${YELLOW}Exécution de ${script}...${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"

    if [ -f "$script" ]; then
        chmod +x "$script"
        "$script"
        local exit_code=$?
        echo ""
        echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
        if [ $exit_code -eq 0 ]; then
            echo -e "${GREEN}✓ Script exécuté avec succès${NC}"
        else
            echo -e "${RED}✗ Erreur lors de l'exécution (code: $exit_code)${NC}"
        fi
    else
        echo -e "${RED}✗ Script non trouvé: $script${NC}"
    fi

    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
}

# Fonction pour afficher l'architecture
show_architecture() {
    show_header
    echo -e "${BOLD}${BLUE}═══ ARCHITECTURE DU CLUSTER ═══${NC}"
    echo ""
    echo "                    ┌─────────────────┐"
    echo "                    │   IP Virtuelle  │"
    echo "                    │  192.168.0.200  │"
    echo "                    │      (k8s)      │"
    echo "                    └────────┬────────┘"
    echo "                             │"
    echo "        ┌────────────────────┼────────────────────┐"
    echo "        │                    │                    │"
    echo "   ┌────▼────┐          ┌────▼────┐          ┌────▼────┐"
    echo "   │ Master1 │          │ Master2 │          │ Master3 │"
    echo "   │k8s01-1  │          │k8s01-2  │          │k8s01-3  │"
    echo "   │.201     │          │.202     │          │.203     │"
    echo "   └─────────┘          └─────────┘          └─────────┘"
    echo ""
    echo -e "${YELLOW}Configuration réseau:${NC}"
    echo "  • IP Virtuelle (VIP): 192.168.0.200 → k8s.home.local"
    echo "  • Master 1: 192.168.0.201 → k8s01-1.home.local"
    echo "  • Master 2: 192.168.0.202 → k8s01-2.home.local"
    echo "  • Master 3: 192.168.0.203 → k8s01-3.home.local"
    echo "  • MetalLB Pool: 192.168.0.220-192.168.0.240 (21 IPs)"
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
                echo ""
                echo -e "${YELLOW}Mode watch activé - Appuyez sur Ctrl+C pour quitter${NC}"
                echo ""
                watch -n 2 -c "kubectl get pods -n kube-system"
                ;;
            2)
                echo ""
                echo -e "${YELLOW}Mode watch activé - Appuyez sur Ctrl+C pour quitter${NC}"
                echo ""
                watch -n 2 "echo -e '${GREEN}=== État keepalived ===${NC}' && systemctl status keepalived --no-pager | head -15 && echo '' && echo -e '${GREEN}=== IP Virtuelle ===${NC}' && ip addr | grep -A2 '192.168.0.200'"
                ;;
            3)
                echo ""
                echo -e "${YELLOW}Mode watch activé - Appuyez sur Ctrl+C pour quitter${NC}"
                echo ""
                watch -n 2 -c "echo '=== Pods MetalLB ===' && kubectl get pods -n metallb-system && echo '' && echo '=== IP Pools ===' && kubectl get ipaddresspools.metallb.io -n metallb-system"
                ;;
            4)
                echo ""
                echo -e "${YELLOW}Mode watch activé - Appuyez sur Ctrl+C pour quitter${NC}"
                echo ""
                watch -n 2 -c "kubectl get pods -n kube-system | grep -E 'NAME|calico'"
                ;;
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
                echo -e "${BOLD}${BLUE}═══ À PROPOS ═══${NC}"
                echo ""
                echo -e "${GREEN}Kubernetes 1.32 - Haute Disponibilité${NC}"
                echo "Version: 1.0"
                echo ""
                echo "Scripts d'installation automatisés pour un cluster"
                echo "Kubernetes en haute disponibilité avec keepalived."
                echo ""
                echo -e "${YELLOW}Composants:${NC}"
                echo "  • Kubernetes 1.32"
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
