#!/bin/bash
################################################################################
# Script de génération automatique du fichier .env
# Génère des mots de passe forts et crée le fichier de configuration
# Auteur: azurtech56
# Version: 2.0
################################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"

echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Génération du fichier .env avec mots de passe sécurisés  ${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""

# Fonction pour générer un mot de passe fort
generate_password() {
    local length=${1:-16}
    local password

    # Vérifier si openssl est disponible
    if command -v openssl &> /dev/null; then
        # Générer avec openssl (alphanumerique + symboles)
        password=$(openssl rand -base64 "$length" | tr -d "=+/\n" | cut -c1-"$length")
    else
        # Fallback avec /dev/urandom
        password=$(tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c "$length")
    fi

    # Retourner sans newline
    echo -n "$password"
}

# Fonction pour valider la force d'un mot de passe
validate_password_strength() {
    local password=$1
    local min_length=8

    if [ ${#password} -lt $min_length ]; then
        echo -e "${RED}✗ Mot de passe trop court (minimum $min_length caractères)${NC}"
        return 1
    fi

    # Vérifier la complexité (au moins une majuscule, une minuscule, un chiffre)
    if ! [[ "$password" =~ [A-Z] ]] || ! [[ "$password" =~ [a-z] ]] || ! [[ "$password" =~ [0-9] ]]; then
        echo -e "${YELLOW}⚠ Mot de passe faible (manque majuscule/minuscule/chiffre)${NC}"
        return 2
    fi

    return 0
}

# Fonction pour demander une valeur à l'utilisateur
prompt_value() {
    local prompt_text=$1
    local default_value=$2
    local is_password=${3:-false}
    local value

    if [ "$is_password" = true ]; then
        read -sp "$prompt_text: " value
        echo ""
    else
        read -p "$prompt_text [$default_value]: " value
        value=${value:-$default_value}
    fi

    # Retourner sans newline
    echo -n "$value"
}

# Vérifier si .env existe déjà
if [ -f "$ENV_FILE" ]; then
    echo -e "${YELLOW}⚠ Le fichier .env existe déjà.${NC}"
    echo ""
    read -p "Voulez-vous le REMPLACER ? (oui/non): " confirm

    if [ "$confirm" != "oui" ] && [ "$confirm" != "o" ]; then
        echo -e "${GREEN}✓ Opération annulée${NC}"
        exit 0
    fi

    # Backup de l'ancien fichier
    backup_file="$ENV_FILE.backup-$(date +%Y%m%d_%H%M%S)"
    mv "$ENV_FILE" "$backup_file"
    echo -e "${GREEN}✓ Backup créé: $backup_file${NC}"
    echo ""
fi

# Vérifier si .env.example existe
if [ ! -f "$ENV_EXAMPLE" ]; then
    echo -e "${RED}✗ Fichier .env.example introuvable${NC}"
    exit 1
fi

echo -e "${CYAN}Configuration interactive${NC}"
echo -e "${CYAN}═══════════════════════${NC}"
echo ""
echo "Appuyez sur Entrée pour utiliser la valeur par défaut entre []"
echo "Les mots de passe seront générés automatiquement si laissés vides"
echo ""

# MODE DE GÉNÉRATION
echo -e "${YELLOW}[1/2] Mode de génération${NC}"
echo ""
echo "  1) Automatique - Générer tous les mots de passe automatiquement (recommandé)"
echo "  2) Manuel - Saisir manuellement chaque mot de passe"
echo ""
read -p "Votre choix [1]: " generation_mode
generation_mode=${generation_mode:-1}
echo ""

# CONFIGURATION UTILISATEUR SSH
echo -e "${YELLOW}[2/2] Configuration SSH${NC}"
echo ""
SSH_USER=$(prompt_value "Utilisateur SSH pour le déploiement" "ubuntu" false)
echo ""

# GÉNÉRATION DES MOTS DE PASSE
echo -e "${CYAN}Génération des mots de passe...${NC}"
echo ""

if [ "$generation_mode" = "1" ]; then
    # Mode automatique
    echo "  🔐 Génération automatique de mots de passe forts..."
    VRRP_PASSWORD=$(generate_password 16)
    RANCHER_PASSWORD=$(generate_password 20)
    GRAFANA_PASSWORD=$(generate_password 20)
    echo -e "${GREEN}  ✓ Mots de passe générés${NC}"
else
    # Mode manuel
    while true; do
        VRRP_PASSWORD=$(prompt_value "Mot de passe VRRP (keepalived)" "" true)
        if [ -z "$VRRP_PASSWORD" ]; then
            VRRP_PASSWORD=$(generate_password 16)
            echo -e "${GREEN}  ✓ Mot de passe VRRP généré automatiquement${NC}"
            break
        fi
        validate_password_strength "$VRRP_PASSWORD" && break
    done
    echo ""

    while true; do
        RANCHER_PASSWORD=$(prompt_value "Mot de passe Rancher admin" "" true)
        if [ -z "$RANCHER_PASSWORD" ]; then
            RANCHER_PASSWORD=$(generate_password 20)
            echo -e "${GREEN}  ✓ Mot de passe Rancher généré automatiquement${NC}"
            break
        fi
        validate_password_strength "$RANCHER_PASSWORD" && break
    done
    echo ""

    while true; do
        GRAFANA_PASSWORD=$(prompt_value "Mot de passe Grafana admin" "" true)
        if [ -z "$GRAFANA_PASSWORD" ]; then
            GRAFANA_PASSWORD=$(generate_password 20)
            echo -e "${GREEN}  ✓ Mot de passe Grafana généré automatiquement${NC}"
            break
        fi
        validate_password_strength "$GRAFANA_PASSWORD" && break
    done
    echo ""
fi

# PARAMÈTRES OPTIONNELS
echo -e "${YELLOW}Paramètres optionnels (laissez vide pour ignorer)${NC}"
echo ""
NOTIFICATION_EMAIL=$(prompt_value "Email pour notifications" "" false)
SLACK_WEBHOOK_URL=$(prompt_value "Webhook Slack" "" false)
echo ""

# CRÉATION DU FICHIER .env
echo -e "${CYAN}Création du fichier .env...${NC}"
echo ""

cat > "$ENV_FILE" <<EOF
################################################################################
# Fichier de configuration des secrets Kubernetes
# ATTENTION: Ce fichier contient des mots de passe - NE PAS versionner dans Git
# Généré automatiquement le $(date +"%Y-%m-%d %H:%M:%S")
################################################################################

# ═══════════════════════════════════════════════════════════════════════════
# MOTS DE PASSE CRITIQUES
# ═══════════════════════════════════════════════════════════════════════════

# Mot de passe pour keepalived (VRRP)
# Utilisé pour sécuriser la communication entre les masters
VRRP_PASSWORD="$VRRP_PASSWORD"

# Mot de passe administrateur Rancher
# Utilisé pour accéder à l'interface web Rancher (https://rancher.example.com)
RANCHER_PASSWORD="$RANCHER_PASSWORD"

# Mot de passe administrateur Grafana
# Utilisé pour accéder à Grafana (https://grafana.example.com)
GRAFANA_PASSWORD="$GRAFANA_PASSWORD"

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURATION SSH
# ═══════════════════════════════════════════════════════════════════════════

# Utilisateur SSH pour le déploiement (doit avoir sudo sans mot de passe)
SSH_USER="$SSH_USER"

# ═══════════════════════════════════════════════════════════════════════════
# PARAMÈTRES OPTIONNELS
# ═══════════════════════════════════════════════════════════════════════════

# Email pour recevoir les notifications (backup, alertes, etc.)
EOF

if [ -n "$NOTIFICATION_EMAIL" ]; then
    echo "NOTIFICATION_EMAIL=\"$NOTIFICATION_EMAIL\"" >> "$ENV_FILE"
else
    echo "#NOTIFICATION_EMAIL=\"votre-email@example.com\"" >> "$ENV_FILE"
fi

cat >> "$ENV_FILE" <<EOF

# Webhook Slack pour notifications (optionnel)
EOF

if [ -n "$SLACK_WEBHOOK_URL" ]; then
    echo "SLACK_WEBHOOK_URL=\"$SLACK_WEBHOOK_URL\"" >> "$ENV_FILE"
else
    echo "#SLACK_WEBHOOK_URL=\"https://hooks.slack.com/services/XXXXX/XXXXX/XXXXX\"" >> "$ENV_FILE"
fi

cat >> "$ENV_FILE" <<EOF

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURATION BACKUP (voir setup-auto-backup.sh)
# ═══════════════════════════════════════════════════════════════════════════

# Répertoire de stockage des backups
#BACKUP_DIR="/var/backups/k8s-cluster"

# Durée de rétention des backups (en jours)
#BACKUP_RETENTION_DAYS="7"

# ═══════════════════════════════════════════════════════════════════════════
# FIN DU FICHIER
# ═══════════════════════════════════════════════════════════════════════════
EOF

# Sécuriser le fichier
chmod 600 "$ENV_FILE"

echo -e "${GREEN}✓ Fichier .env créé avec succès${NC}"
echo ""

# AFFICHER LE RÉSUMÉ
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Résumé de la configuration                                ${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Fichier créé:${NC} $ENV_FILE"
echo -e "${GREEN}Permissions:${NC} 600 (lecture/écriture owner uniquement)"
echo ""
echo -e "${YELLOW}Mots de passe générés:${NC}"

# Fonction pour masquer un mot de passe (afficher seulement début et fin)
mask_password() {
    local password=$1
    local length=${#password}
    local visible=$((length / 4))

    if [ $length -le 4 ]; then
        echo "***"
    else
        echo "${password:0:$visible}***${password: -$visible}"
    fi
}

echo "  • VRRP Password:    $(mask_password "$VRRP_PASSWORD")"
echo "  • Rancher Password: $(mask_password "$RANCHER_PASSWORD")"
echo "  • Grafana Password: $(mask_password "$GRAFANA_PASSWORD")"
echo ""
echo -e "${YELLOW}Configuration SSH:${NC}"
echo "  • SSH User: $SSH_USER"
echo ""

if [ -n "$NOTIFICATION_EMAIL" ]; then
    echo -e "${YELLOW}Notifications:${NC}"
    echo "  • Email: $NOTIFICATION_EMAIL"
    [ -n "$SLACK_WEBHOOK_URL" ] && echo "  • Slack: Configuré ✓"
    echo ""
fi

echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}✓ Configuration terminée !${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT - SÉCURITÉ:${NC}"
echo ""
echo "  1. Le fichier .env est protégé (chmod 600)"
echo "  2. Il est exclu de Git (.gitignore)"
echo "  3. NE JAMAIS versionner ce fichier"
echo "  4. Sauvegarder les mots de passe dans un gestionnaire sécurisé"
echo ""
echo -e "${YELLOW}Prochaines étapes:${NC}"
echo ""
echo "  1. Vérifier le fichier: cat $ENV_FILE"
echo "  2. Exécuter les scripts: ./k8s-menu.sh"
echo "  3. Les mots de passe seront chargés automatiquement depuis .env"
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
