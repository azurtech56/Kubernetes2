#!/bin/bash
################################################################################
# Script de génération et déploiement du fichier /etc/hosts
# Compatible avec: Ubuntu 20.04/22.04/24.04 - Debian 12/13
# Auteur: azurtech56
# Version: 1.0
################################################################################

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Génération du fichier /etc/hosts${NC}"
echo -e "${GREEN}========================================${NC}"

# Charger la configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "$SCRIPT_DIR/config.sh" ]; then
    echo -e "${RED}Erreur: fichier config.sh introuvable${NC}"
    exit 1
fi

source "$SCRIPT_DIR/config.sh"

# Vérifier si l'utilisateur est root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Ce script doit être exécuté en tant que root${NC}"
   exit 1
fi

# Fonction pour générer le contenu /etc/hosts
generate_hosts_file() {
    cat <<EOF
# /etc/hosts - Généré automatiquement par generate-hosts.sh
# Ne pas modifier manuellement - Utiliser config.sh et relancer le script

127.0.0.1 localhost
127.0.1.1 $(hostname)

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters

# ═══════════════════════════════════════════════════════════════════════════
# KUBERNETES HA CLUSTER - Généré depuis config.sh
# ═══════════════════════════════════════════════════════════════════════════

# IP Virtuelle (VIP) - keepalived
${VIP} ${VIP_FQDN} ${VIP_HOSTNAME}

# Masters
${MASTER1_IP} ${MASTER1_FQDN} ${MASTER1_HOSTNAME}
${MASTER2_IP} ${MASTER2_FQDN} ${MASTER2_HOSTNAME}
${MASTER3_IP} ${MASTER3_FQDN} ${MASTER3_HOSTNAME}

# Workers
${WORKER1_IP} ${WORKER1_FQDN} ${WORKER1_HOSTNAME}
${WORKER2_IP} ${WORKER2_FQDN} ${WORKER2_HOSTNAME}
${WORKER3_IP} ${WORKER3_FQDN} ${WORKER3_HOSTNAME}

# ═══════════════════════════════════════════════════════════════════════════
EOF
}

# Menu principal
show_menu() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}Génération du fichier /etc/hosts${NC}                           ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Configuration actuelle (config.sh):${NC}"
    echo ""
    echo -e "  ${YELLOW}VIP:${NC}      ${VIP} → ${VIP_FQDN}"
    echo -e "  ${YELLOW}Master 1:${NC} ${MASTER1_IP} → ${MASTER1_FQDN}"
    echo -e "  ${YELLOW}Master 2:${NC} ${MASTER2_IP} → ${MASTER2_FQDN}"
    echo -e "  ${YELLOW}Master 3:${NC} ${MASTER3_IP} → ${MASTER3_FQDN}"
    echo -e "  ${YELLOW}Worker 1:${NC} ${WORKER1_IP} → ${WORKER1_FQDN}"
    echo -e "  ${YELLOW}Worker 2:${NC} ${WORKER2_IP} → ${WORKER2_FQDN}"
    echo -e "  ${YELLOW}Worker 3:${NC} ${WORKER3_IP} → ${WORKER3_FQDN}"
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}[1]${NC}  Générer /etc/hosts sur CE nœud uniquement"
    echo -e "${GREEN}[2]${NC}  Générer et afficher le contenu (preview)"
    echo -e "${GREEN}[3]${NC}  Déployer sur TOUS les nœuds via SSH"
    echo -e "${GREEN}[4]${NC}  Sauvegarder /etc/hosts actuel"
    echo ""
    echo -e "${RED}[0]${NC}  Retour"
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -ne "${YELLOW}Votre choix: ${NC}"
}

# Option 1: Générer localement
generate_local() {
    echo ""
    echo -e "${YELLOW}[1/3] Sauvegarde de /etc/hosts actuel...${NC}"
    cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d_%H%M%S)
    echo -e "${GREEN}✓ Sauvegarde créée${NC}"

    echo -e "${YELLOW}[2/3] Génération du nouveau /etc/hosts...${NC}"
    generate_hosts_file > /tmp/hosts.new
    echo -e "${GREEN}✓ Fichier généré${NC}"

    echo -e "${YELLOW}[3/3] Remplacement de /etc/hosts...${NC}"
    mv /tmp/hosts.new /etc/hosts
    chmod 644 /etc/hosts
    echo -e "${GREEN}✓ /etc/hosts mis à jour sur ce nœud${NC}"

    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Succès ! /etc/hosts généré et appliqué localement${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
}

# Option 2: Preview
preview_hosts() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}Aperçu du fichier /etc/hosts qui sera généré${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    generate_hosts_file | nl -ba -w2 -s'  '
    echo ""
}

# Option 3: Déployer sur tous les nœuds
deploy_all() {
    echo ""
    echo -e "${YELLOW}Déploiement sur tous les nœuds via SSH${NC}"
    echo ""

    # Tableau de tous les nœuds
    declare -a NODES=(
        "${MASTER1_IP}:${MASTER1_HOSTNAME}"
        "${MASTER2_IP}:${MASTER2_HOSTNAME}"
        "${MASTER3_IP}:${MASTER3_HOSTNAME}"
        "${WORKER1_IP}:${WORKER1_HOSTNAME}"
        "${WORKER2_IP}:${WORKER2_HOSTNAME}"
        "${WORKER3_IP}:${WORKER3_HOSTNAME}"
    )

    # Demander le nom d'utilisateur SSH
    echo -ne "${YELLOW}Nom d'utilisateur SSH (défaut: root): ${NC}"
    read SSH_USER
    SSH_USER=${SSH_USER:-root}

    echo ""
    echo -e "${BLUE}Génération du fichier temporaire...${NC}"
    generate_hosts_file > /tmp/hosts.deploy

    echo ""
    echo -e "${CYAN}Déploiement en cours...${NC}"
    echo ""

    SUCCESS_COUNT=0
    FAILED_COUNT=0

    for node in "${NODES[@]}"; do
        IP="${node%%:*}"
        HOSTNAME="${node##*:}"

        echo -ne "  ${YELLOW}→${NC} ${HOSTNAME} (${IP})... "

        # Tester la connectivité SSH
        if ! ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "${SSH_USER}@${IP}" "exit" 2>/dev/null; then
            echo -e "${RED}✗ Échec (SSH inaccessible)${NC}"
            ((FAILED_COUNT++))
            continue
        fi

        # Sauvegarder l'ancien fichier
        ssh "${SSH_USER}@${IP}" "cp /etc/hosts /etc/hosts.backup.\$(date +%Y%m%d_%H%M%S)" 2>/dev/null

        # Copier le nouveau fichier
        if scp -o StrictHostKeyChecking=no /tmp/hosts.deploy "${SSH_USER}@${IP}:/tmp/hosts.new" >/dev/null 2>&1; then
            ssh "${SSH_USER}@${IP}" "mv /tmp/hosts.new /etc/hosts && chmod 644 /etc/hosts" 2>/dev/null
            echo -e "${GREEN}✓ OK${NC}"
            ((SUCCESS_COUNT++))
        else
            echo -e "${RED}✗ Échec${NC}"
            ((FAILED_COUNT++))
        fi
    done

    rm -f /tmp/hosts.deploy

    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}Succès:${NC} ${SUCCESS_COUNT}/6 nœuds"
    echo -e "  ${RED}Échecs:${NC} ${FAILED_COUNT}/6 nœuds"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"

    if [ $FAILED_COUNT -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}💡 Conseil:${NC} Vérifiez que:"
        echo "  - SSH est accessible sur tous les nœuds"
        echo "  - Les clés SSH sont configurées (ssh-copy-id)"
        echo "  - L'utilisateur a les droits sudo/root"
    fi
}

# Option 4: Sauvegarder
backup_hosts() {
    echo ""
    BACKUP_FILE="/etc/hosts.backup.$(date +%Y%m%d_%H%M%S)"
    cp /etc/hosts "$BACKUP_FILE"
    echo -e "${GREEN}✓ Sauvegarde créée: ${BACKUP_FILE}${NC}"
    echo ""
    echo -e "Pour restaurer: ${CYAN}cp ${BACKUP_FILE} /etc/hosts${NC}"
}

# Boucle principale
while true; do
    show_menu
    read choice

    case $choice in
        1)
            generate_local
            echo ""
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        2)
            preview_hosts
            echo ""
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        3)
            deploy_all
            echo ""
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        4)
            backup_hosts
            read -p "Appuyez sur Entrée pour continuer..."
            ;;
        0)
            echo ""
            echo -e "${GREEN}Au revoir !${NC}"
            exit 0
            ;;
        *)
            echo ""
            echo -e "${RED}Option invalide${NC}"
            sleep 2
            ;;
    esac
done
