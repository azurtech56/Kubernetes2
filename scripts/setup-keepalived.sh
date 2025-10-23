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

# Configuration
VIP="192.168.0.200"
VRRP_PASSWORD="K8s_HA_Pass"
ROUTER_ID="51"

echo -e "${BLUE}Configuration actuelle:${NC}"
echo "  IP Virtuelle: ${VIP}"
echo "  Password VRRP: ${VRRP_PASSWORD}"
echo "  Router ID: ${ROUTER_ID}"
echo ""

# Détecter l'interface réseau principale
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
echo -e "${YELLOW}Interface réseau détectée: ${INTERFACE}${NC}"

# Menu de sélection du rôle
echo ""
echo -e "${BLUE}Sélectionnez le rôle de ce nœud:${NC}"
echo "  1) Master 1 (k8s01-1) - Priority 101 - MASTER"
echo "  2) Master 2 (k8s01-2) - Priority 100 - BACKUP"
echo "  3) Master 3 (k8s01-3) - Priority 99 - BACKUP"
echo ""
read -p "Votre choix [1-3]: " choice

case $choice in
  1)
    STATE="MASTER"
    PRIORITY="101"
    NODE_NAME="k8s01-1"
    ;;
  2)
    STATE="BACKUP"
    PRIORITY="100"
    NODE_NAME="k8s01-2"
    ;;
  3)
    STATE="BACKUP"
    PRIORITY="99"
    NODE_NAME="k8s01-3"
    ;;
  *)
    echo -e "${RED}Choix invalide${NC}"
    exit 1
    ;;
esac

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

cat > /etc/keepalived/keepalived.conf <<EOF
vrrp_instance VI_1 {
    state ${STATE}
    interface ${INTERFACE}
    virtual_router_id ${ROUTER_ID}
    priority ${PRIORITY}
    advert_int 1

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
