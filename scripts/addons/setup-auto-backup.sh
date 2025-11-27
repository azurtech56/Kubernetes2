#!/bin/bash
################################################################################
# Script de configuration des backups automatiques Kubernetes
# Configure un cron job pour backups quotidiens/hebdomadaires
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
BACKUP_SCRIPT="$SCRIPT_DIR/backup-cluster.sh"
AUTO_BACKUP_SCRIPT="/usr/local/bin/k8s-auto-backup.sh"

################################################################################
# FONCTIONS
################################################################################

show_usage() {
    cat <<EOF
${CYAN}════════════════════════════════════════════════════════════════${NC}
  Configuration des Backups Automatiques Kubernetes
${CYAN}════════════════════════════════════════════════════════════════${NC}

${YELLOW}Usage:${NC}
  $0 [options]

${YELLOW}Options:${NC}
  --schedule <schedule>  Planification cron (défaut: interactif)
  --type <type>         Type de backup: full, etcd (défaut: full)
  --retention <days>    Rétention en jours (défaut: 7)
  --disable             Désactiver les backups automatiques
  --status              Afficher l'état des backups automatiques
  -h, --help            Afficher cette aide

${YELLOW}Exemples de planification:${NC}
  --schedule "0 2 * * *"        Tous les jours à 2h00
  --schedule "0 3 * * 0"        Tous les dimanches à 3h00
  --schedule "0 */6 * * *"      Toutes les 6 heures

${YELLOW}Exemples:${NC}
  # Configuration interactive
  $0

  # Backup quotidien à 2h00
  $0 --schedule "0 2 * * *" --type full --retention 7

  # Backup etcd toutes les 6 heures
  $0 --schedule "0 */6 * * *" --type etcd --retention 2

  # Désactiver les backups automatiques
  $0 --disable

  # Vérifier l'état
  $0 --status

${CYAN}════════════════════════════════════════════════════════════════${NC}
EOF
}

# Vérifier si backup-cluster.sh existe
check_backup_script() {
    if [ ! -f "$BACKUP_SCRIPT" ]; then
        echo -e "${RED}Erreur: Script de backup introuvable: $BACKUP_SCRIPT${NC}"
        exit 1
    fi

    if [ ! -x "$BACKUP_SCRIPT" ]; then
        chmod +x "$BACKUP_SCRIPT"
    fi
}

# Afficher l'état actuel
show_status() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  État des Backups Automatiques${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Vérifier si le script wrapper existe
    if [ -f "$AUTO_BACKUP_SCRIPT" ]; then
        echo -e "${GREEN}✓ Script de backup automatique installé${NC}"
        echo "  Emplacement: $AUTO_BACKUP_SCRIPT"
        echo ""
    else
        echo -e "${YELLOW}✗ Script de backup automatique non installé${NC}"
        echo ""
        return 0
    fi

    # Vérifier la configuration cron
    local cron_entries=$(crontab -l 2>/dev/null | grep -v "^#" | grep "k8s-auto-backup.sh" || true)

    if [ -n "$cron_entries" ]; then
        echo -e "${GREEN}✓ Cron job configuré${NC}"
        echo ""
        echo "Configuration cron actuelle:"
        echo "────────────────────────────────────────────────────────────────"
        echo "$cron_entries"
        echo "────────────────────────────────────────────────────────────────"
        echo ""

        # Analyser la planification
        local schedule=$(echo "$cron_entries" | awk '{print $1, $2, $3, $4, $5}')
        echo "Planification:"

        case "$schedule" in
            "0 2 * * *")
                echo "  • Type: Quotidien"
                echo "  • Heure: 02:00"
                ;;
            "0 3 * * 0")
                echo "  • Type: Hebdomadaire"
                echo "  • Jour: Dimanche"
                echo "  • Heure: 03:00"
                ;;
            "0 */6 * * *")
                echo "  • Type: Toutes les 6 heures"
                ;;
            *)
                echo "  • Cron: $schedule"
                ;;
        esac
    else
        echo -e "${YELLOW}✗ Aucun cron job configuré${NC}"
    fi

    echo ""

    # Vérifier les backups récents
    local backup_dir="${BACKUP_DIR:-/var/backups/k8s-cluster}"
    if [ -d "$backup_dir" ]; then
        local recent_backups=$(find "$backup_dir" -name "k8s-backup-*.tar.gz" -mtime -7 -type f 2>/dev/null | wc -l)
        echo "Backups récents (7 derniers jours): $recent_backups"

        if [ "$recent_backups" -gt 0 ]; then
            echo ""
            echo "Dernier backup:"
            local last_backup=$(find "$backup_dir" -name "k8s-backup-*.tar.gz" -type f 2>/dev/null | sort -r | head -n1)
            if [ -n "$last_backup" ]; then
                echo "  • Fichier: $(basename "$last_backup")"
                echo "  • Taille: $(du -h "$last_backup" | cut -f1)"
                echo "  • Date: $(stat -c %y "$last_backup" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1)"
            fi
        fi
    fi

    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
}

# Désactiver les backups automatiques
disable_auto_backup() {
    echo ""
    echo -e "${YELLOW}Désactivation des backups automatiques...${NC}"
    echo ""

    # Supprimer le cron job
    crontab -l 2>/dev/null | grep -v "k8s-auto-backup.sh" | crontab - 2>/dev/null || true
    echo -e "${GREEN}✓ Cron job supprimé${NC}"

    # Supprimer le script wrapper
    if [ -f "$AUTO_BACKUP_SCRIPT" ]; then
        rm -f "$AUTO_BACKUP_SCRIPT"
        echo -e "${GREEN}✓ Script wrapper supprimé${NC}"
    fi

    echo ""
    echo -e "${GREEN}Backups automatiques désactivés${NC}"
    echo ""
}

# Créer le script wrapper
create_wrapper_script() {
    local backup_type=$1
    local retention=$2

    cat > "$AUTO_BACKUP_SCRIPT" <<EOF
#!/bin/bash
################################################################################
# Script wrapper pour backups automatiques Kubernetes
# Généré automatiquement par setup-auto-backup.sh
# Date: $(date)
################################################################################

# Configuration
BACKUP_TYPE="$backup_type"
RETENTION_DAYS="$retention"
LOG_FILE="/var/log/k8s-setup/auto-backup-\$(date +%Y%m%d_%H%M%S).log"

# Créer le répertoire de logs
mkdir -p /var/log/k8s-setup

# Rediriger la sortie vers le log
exec > "\$LOG_FILE" 2>&1

echo "════════════════════════════════════════════════════════════════"
echo "Backup automatique Kubernetes - \$(date)"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Exécuter le backup
$BACKUP_SCRIPT --type "\$BACKUP_TYPE" --retention "\$RETENTION_DAYS"

EXIT_CODE=\$?

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Backup terminé - Code de sortie: \$EXIT_CODE"
echo "════════════════════════════════════════════════════════════════"

exit \$EXIT_CODE
EOF

    chmod +x "$AUTO_BACKUP_SCRIPT"
    echo -e "${GREEN}✓ Script wrapper créé: $AUTO_BACKUP_SCRIPT${NC}"
}

# Configurer le cron job
setup_cron_job() {
    local schedule=$1

    # Supprimer les anciens cron jobs k8s-auto-backup
    crontab -l 2>/dev/null | grep -v "k8s-auto-backup.sh" | crontab - 2>/dev/null || true

    # Ajouter le nouveau cron job
    (crontab -l 2>/dev/null; echo "$schedule $AUTO_BACKUP_SCRIPT") | crontab -

    echo -e "${GREEN}✓ Cron job configuré: $schedule${NC}"
}

# Configuration interactive
interactive_setup() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Configuration Interactive des Backups Automatiques${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Type de backup
    echo -e "${YELLOW}[1/3] Type de backup${NC}"
    echo ""
    echo "  1) Backup complet (etcd + ressources + configs) - Recommandé"
    echo "  2) Backup etcd uniquement (plus rapide)"
    echo ""
    read -p "Votre choix [1]: " backup_choice
    backup_choice=${backup_choice:-1}

    case "$backup_choice" in
        1) BACKUP_TYPE="full" ;;
        2) BACKUP_TYPE="etcd" ;;
        *) BACKUP_TYPE="full" ;;
    esac

    echo ""
    echo -e "${GREEN}✓ Type sélectionné: $BACKUP_TYPE${NC}"
    echo ""

    # Planification
    echo -e "${YELLOW}[2/3] Planification${NC}"
    echo ""
    echo "  1) Quotidien à 02:00 (recommandé)"
    echo "  2) Hebdomadaire (dimanche à 03:00)"
    echo "  3) Toutes les 6 heures"
    echo "  4) Toutes les 12 heures"
    echo "  5) Personnalisé (cron syntax)"
    echo ""
    read -p "Votre choix [1]: " schedule_choice
    schedule_choice=${schedule_choice:-1}

    case "$schedule_choice" in
        1) CRON_SCHEDULE="0 2 * * *" ;;
        2) CRON_SCHEDULE="0 3 * * 0" ;;
        3) CRON_SCHEDULE="0 */6 * * *" ;;
        4) CRON_SCHEDULE="0 */12 * * *" ;;
        5)
            echo ""
            read -p "Entrez la planification cron (ex: 0 2 * * *): " CRON_SCHEDULE
            ;;
        *) CRON_SCHEDULE="0 2 * * *" ;;
    esac

    echo ""
    echo -e "${GREEN}✓ Planification: $CRON_SCHEDULE${NC}"
    echo ""

    # Rétention
    echo -e "${YELLOW}[3/3] Rétention des backups${NC}"
    echo ""
    read -p "Nombre de jours à conserver [7]: " retention
    retention=${retention:-7}

    echo ""
    echo -e "${GREEN}✓ Rétention: $retention jours${NC}"
    echo ""

    # Résumé
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Résumé de la Configuration${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  Type de backup: $BACKUP_TYPE"
    echo "  Planification: $CRON_SCHEDULE"
    echo "  Rétention: $retention jours"
    echo ""

    read -p "Confirmer la configuration ? (oui/non) [oui]: " confirm
    confirm=${confirm:-oui}

    if [ "$confirm" != "oui" ] && [ "$confirm" != "o" ]; then
        echo ""
        echo -e "${YELLOW}Configuration annulée${NC}"
        exit 0
    fi

    echo ""

    # Appliquer la configuration
    create_wrapper_script "$BACKUP_TYPE" "$retention"
    setup_cron_job "$CRON_SCHEDULE"

    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ Configuration terminée avec succès${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Prochaines étapes:${NC}"
    echo ""
    echo "  1. Vérifier la configuration: $0 --status"
    echo "  2. Tester le backup: sudo $AUTO_BACKUP_SCRIPT"
    echo "  3. Vérifier les logs: ls -lh /var/log/k8s-setup/auto-backup-*.log"
    echo ""
    echo -e "${YELLOW}Le premier backup automatique sera exécuté selon la planification.${NC}"
    echo ""
}

################################################################################
# MAIN
################################################################################

# Parser les arguments
CRON_SCHEDULE=""
BACKUP_TYPE="full"
RETENTION=7
MODE="interactive"

while [ $# -gt 0 ]; do
    case "$1" in
        --schedule)
            CRON_SCHEDULE="$2"
            MODE="non-interactive"
            shift 2
            ;;
        --type)
            BACKUP_TYPE="$2"
            shift 2
            ;;
        --retention)
            RETENTION="$2"
            shift 2
            ;;
        --disable)
            disable_auto_backup
            exit 0
            ;;
        --status)
            show_status
            exit 0
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Option inconnue: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Vérifier les permissions root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Ce script doit être exécuté en tant que root${NC}"
   exit 1
fi

# Vérifier que backup-cluster.sh existe
check_backup_script

# Mode interactif ou non-interactif
if [ "$MODE" = "interactive" ]; then
    interactive_setup
else
    # Mode non-interactif
    echo ""
    echo -e "${CYAN}Configuration des backups automatiques...${NC}"
    echo ""

    create_wrapper_script "$BACKUP_TYPE" "$RETENTION"
    setup_cron_job "$CRON_SCHEDULE"

    echo ""
    echo -e "${GREEN}✓ Configuration terminée${NC}"
    echo ""
    echo "Pour vérifier: $0 --status"
    echo ""
fi
