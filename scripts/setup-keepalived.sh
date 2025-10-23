#!/bin/bash
################################################################################
# Script de configuration keepalived pour Haute Disponibilité
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
echo -e "${GREEN}  Configuration keepalived${NC}"
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
    VIP="192.168.0.200"
    VRRP_PASSWORD="K8s_HA_Pass"
    VRRP_ROUTER_ID="51"
fi

echo ""
echo -e "${BLUE}Configuration keepalived:${NC}"
echo "  IP Virtuelle: ${VIP}"
echo "  Password VRRP: ${VRRP_PASSWORD}"
echo "  Router ID: ${VRRP_ROUTER_ID}"
echo ""

# Détecter l'interface réseau principale
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
echo -e "${YELLOW}Interface réseau détectée: ${INTERFACE}${NC}"

# Menu de sélection du rôle
echo ""
echo -e "${BLUE}Configuration du nœud Master:${NC}"
echo ""
echo -e "${YELLOW}Est-ce le PREMIER master (celui qui aura la VIP par défaut)? [y/N]:${NC}"
read -p "> " is_first_master

if [[ $is_first_master =~ ^[Yy]$ ]]; then
    STATE="MASTER"
    PRIORITY="101"
    echo -e "${GREEN}Ce nœud sera configuré comme MASTER (priorité 101)${NC}"
else
    STATE="BACKUP"
    echo ""
    echo -e "${YELLOW}Entrez la priorité pour ce nœud BACKUP${NC}"
    echo -e "${BLUE}Suggestions:${NC}"
    echo "  - Master 2: 100"
    echo "  - Master 3: 99"
    echo "  - Master 4: 98"
    echo "  - etc."
    echo ""
    read -p "Priorité [50-100]: " PRIORITY

    # Validation de la priorité
    if ! [[ "$PRIORITY" =~ ^[0-9]+$ ]] || [ "$PRIORITY" -lt 50 ] || [ "$PRIORITY" -gt 100 ]; then
        echo -e "${RED}Priorité invalide. Utilisation de la valeur par défaut: 100${NC}"
        PRIORITY="100"
    fi

    echo -e "${GREEN}Ce nœud sera configuré comme BACKUP (priorité ${PRIORITY})${NC}"
fi

# Demander le nom du nœud (optionnel)
echo ""
echo -e "${YELLOW}Nom du nœud (optionnel, pour information):${NC}"
read -p "Nom [laisser vide pour auto]: " NODE_NAME
if [ -z "$NODE_NAME" ]; then
    NODE_NAME=$(hostname)
fi

echo ""
echo -e "${YELLOW}Configuration pour ${NODE_NAME}:${NC}"
echo "  État: ${STATE}"
echo "  Priorité: ${PRIORITY}"
echo "  Interface: ${INTERFACE}"
echo ""
read -p "Confirmer la configuration? [y/N]: " confirm

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${RED}Configuration annulée${NC}"
    exit 1
fi

echo -e "${YELLOW}Création du fichier de configuration keepalived...${NC}"

# Créer le répertoire si nécessaire
mkdir -p /etc/keepalived

cat > /etc/keepalived/keepalived.conf <<EOF
vrrp_instance VI_1 {
    state ${STATE}
    interface ${INTERFACE}
    virtual_router_id ${VRRP_ROUTER_ID}
    priority ${PRIORITY}
    advert_int ${VRRP_ADVERT_INT}

    authentication {
        auth_type PASS
        auth_pass ${VRRP_PASSWORD}
    }

    virtual_ipaddress {
        ${VIP}/24
    }
}
EOF

echo -e "${GREEN}✓ Fichier de configuration créé${NC}"

echo -e "${YELLOW}Redémarrage de keepalived...${NC}"
systemctl restart keepalived
systemctl enable keepalived
echo -e "${GREEN}✓ keepalived démarré${NC}"

echo ""
echo -e "${YELLOW}Vérification de l'état...${NC}"
sleep 2
systemctl status keepalived --no-pager | head -n 10

echo ""
echo -e "${YELLOW}Vérification de l'IP virtuelle...${NC}"
ip addr show ${INTERFACE} | grep "${VIP}" && echo -e "${GREEN}✓ IP virtuelle active sur ce nœud${NC}" || echo -e "${YELLOW}⚠ IP virtuelle non active (normal si BACKUP)${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Configuration keepalived terminée !${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Commandes utiles:${NC}"
echo "  - Vérifier le statut: systemctl status keepalived"
echo "  - Voir les logs: journalctl -u keepalived -f"
echo "  - Vérifier l'IP: ip addr show ${INTERFACE}"
echo "  - Tester le ping: ping -c 3 ${VIP}"
