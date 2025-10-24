#!/bin/bash
################################################################################
# Script de vérification des prérequis pour installation Kubernetes
# À exécuter AVANT tout autre script d'installation
# Compatible avec: Ubuntu 20.04/22.04/24.04 - Debian 12/13
# Auteur: azurtech56
# Version: 1.0
################################################################################

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Vérification des Prérequis${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Vérifier si l'utilisateur est root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Ce script doit être exécuté en tant que root${NC}"
   exit 1
fi

# Liste des commandes requises
REQUIRED_COMMANDS=(
    "curl:curl"
    "gpg:gnupg"
    "ip:iproute2"
    "ssh:openssh-client"
    "scp:openssh-client"
    "ufw:ufw"
    "base64:coreutils"
    "grep:grep"
    "awk:gawk"
    "sed:sed"
)

# Compteurs
MISSING_COUNT=0
INSTALLED_COUNT=0

echo -e "${BLUE}Vérification des commandes système...${NC}"
echo ""

for cmd_pkg in "${REQUIRED_COMMANDS[@]}"; do
    cmd="${cmd_pkg%%:*}"
    pkg="${cmd_pkg##*:}"

    if command -v "$cmd" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $cmd (paquet: $pkg)"
        ((INSTALLED_COUNT++))
    else
        echo -e "  ${RED}✗${NC} $cmd (paquet: $pkg) ${YELLOW}MANQUANT${NC}"
        ((MISSING_COUNT++))
    fi
done

echo ""
echo -e "${BLUE}Vérification des ressources système...${NC}"
echo ""

# Vérifier CPU
CPU_COUNT=$(nproc)
if [ "$CPU_COUNT" -ge 2 ]; then
    echo -e "  ${GREEN}✓${NC} CPU: $CPU_COUNT cœurs (minimum 2)"
else
    echo -e "  ${RED}✗${NC} CPU: $CPU_COUNT cœurs ${YELLOW}(minimum requis: 2)${NC}"
    ((MISSING_COUNT++))
fi

# Vérifier RAM
RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
if [ "$RAM_MB" -ge 3500 ]; then
    echo -e "  ${GREEN}✓${NC} RAM: ${RAM_MB}MB (minimum 4GB)"
else
    echo -e "  ${RED}✗${NC} RAM: ${RAM_MB}MB ${YELLOW}(minimum requis: 4GB / 4000MB)${NC}"
    ((MISSING_COUNT++))
fi

# Vérifier espace disque
DISK_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$DISK_GB" -ge 20 ]; then
    echo -e "  ${GREEN}✓${NC} Disque: ${DISK_GB}GB disponible (minimum 20GB)"
else
    echo -e "  ${RED}✗${NC} Disque: ${DISK_GB}GB ${YELLOW}(minimum requis: 20GB)${NC}"
    ((MISSING_COUNT++))
fi

# Vérifier swap
SWAP_STATUS=$(swapon --show | wc -l)
if [ "$SWAP_STATUS" -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} Swap: désactivé (requis pour Kubernetes)"
else
    echo -e "  ${YELLOW}⚠${NC} Swap: activé ${YELLOW}(sera désactivé par common-setup.sh)${NC}"
fi

echo ""
echo -e "${BLUE}Vérification réseau...${NC}"
echo ""

# Détection interface réseau
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
if [ -n "$INTERFACE" ]; then
    IP_ADDR=$(ip -4 addr show "$INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    echo -e "  ${GREEN}✓${NC} Interface réseau: $INTERFACE (IP: $IP_ADDR)"
else
    echo -e "  ${RED}✗${NC} Interface réseau: ${YELLOW}non détectée${NC}"
    ((MISSING_COUNT++))
fi

# Vérifier connectivité internet
if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Connectivité Internet: OK"
else
    echo -e "  ${RED}✗${NC} Connectivité Internet: ${YELLOW}ÉCHEC${NC}"
    ((MISSING_COUNT++))
fi

# Vérifier DNS
if ping -c 1 -W 2 google.com &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Résolution DNS: OK"
else
    echo -e "  ${YELLOW}⚠${NC} Résolution DNS: ${YELLOW}ÉCHEC (peut causer des problèmes)${NC}"
fi

echo ""
echo -e "${BLUE}Vérification OS...${NC}"
echo ""

# Détecter OS
if [ -f /etc/os-release ]; then
    source /etc/os-release
    echo -e "  ${GREEN}✓${NC} OS: $PRETTY_NAME"

    # Vérifier compatibilité
    case "$ID" in
        ubuntu)
            case "$VERSION_ID" in
                20.04|22.04|24.04)
                    echo -e "  ${GREEN}✓${NC} Version: Supportée officiellement"
                    ;;
                *)
                    echo -e "  ${YELLOW}⚠${NC} Version: ${YELLOW}Non testée (supportées: 20.04, 22.04, 24.04)${NC}"
                    ;;
            esac
            ;;
        debian)
            case "$VERSION_ID" in
                12|13)
                    echo -e "  ${GREEN}✓${NC} Version: Supportée officiellement"
                    ;;
                *)
                    echo -e "  ${YELLOW}⚠${NC} Version: ${YELLOW}Non testée (supportées: Debian 12, 13)${NC}"
                    ;;
            esac
            ;;
        *)
            echo -e "  ${YELLOW}⚠${NC} OS: ${YELLOW}Non testé (recommandé: Ubuntu 20.04/22.04/24.04 ou Debian 12/13)${NC}"
            ;;
    esac
else
    echo -e "  ${RED}✗${NC} OS: ${YELLOW}Impossible de détecter${NC}"
    ((MISSING_COUNT++))
fi

# Résumé
echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  RÉSUMÉ${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

TOTAL_CHECKS=$((INSTALLED_COUNT + MISSING_COUNT))
SUCCESS_RATE=$((INSTALLED_COUNT * 100 / TOTAL_CHECKS))

echo -e "  Vérifications réussies: ${GREEN}$INSTALLED_COUNT${NC}/$TOTAL_CHECKS (${SUCCESS_RATE}%)"
echo -e "  Problèmes détectés:     ${RED}$MISSING_COUNT${NC}/$TOTAL_CHECKS"

echo ""

if [ "$MISSING_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✓ SUCCÈS: Tous les prérequis sont satisfaits !${NC}"
    echo ""
    echo -e "${BLUE}Vous pouvez maintenant exécuter:${NC}"
    echo -e "  ${YELLOW}sudo ./scripts/common-setup.sh${NC}"
    echo ""
    exit 0
else
    echo -e "${YELLOW}⚠ ATTENTION: $MISSING_COUNT prérequis manquants${NC}"
    echo ""
    echo -e "${BLUE}Recommandation:${NC}"
    echo -e "  1. Installez les paquets manquants avec:"
    echo -e "     ${YELLOW}apt update && apt install -y curl gnupg iproute2 openssh-client ufw${NC}"
    echo ""
    echo -e "  2. Ou exécutez directement common-setup.sh qui installera les dépendances:"
    echo -e "     ${YELLOW}sudo ./scripts/common-setup.sh${NC}"
    echo ""
    exit 1
fi
