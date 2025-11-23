#!/bin/bash
################################################################################
# Script de déploiement automatisé du cluster Kubernetes HA
# Orchestre l'exécution de tous les scripts dans le bon ordre
# Auteur: azurtech56
# Version: 1.0
################################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_LOG="${SCRIPT_DIR}/deployment-$(date +%Y%m%d_%H%M%S).log"
FAILED_STEPS=()
SKIPPED_STEPS=()

# ============================================================================
# FONCTIONS
# ============================================================================

log_step() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "$DEPLOYMENT_LOG"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}" | tee -a "$DEPLOYMENT_LOG"
}

log_error() {
    echo -e "${RED}✗ $1${NC}" | tee -a "$DEPLOYMENT_LOG"
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}" | tee -a "$DEPLOYMENT_LOG"
}

run_step() {
    local script=$1
    local description=$2
    local require_confirmation=${3:-false}

    if [ ! -f "$SCRIPT_DIR/$script" ]; then
        log_error "Script non trouvé: $script"
        FAILED_STEPS+=("$description ($script)")
        return 1
    fi

    log_step "Exécution: $description"

    if [ "$require_confirmation" = true ]; then
        read -p "Continuer? [y/N]: " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            log_warning "Étape ignorée: $description"
            SKIPPED_STEPS+=("$description")
            return 0
        fi
    fi

    if bash "$SCRIPT_DIR/$script" >> "$DEPLOYMENT_LOG" 2>&1; then
        log_success "$description"
        return 0
    else
        log_error "$description - ÉCHOUÉE"
        FAILED_STEPS+=("$description")
        return 1
    fi
}

show_header() {
    clear
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Déploiement Automatisé - Kubernetes HA${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

show_summary() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Résumé du Déploiement${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""

    if [ ${#FAILED_STEPS[@]} -eq 0 ] && [ ${#SKIPPED_STEPS[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ Déploiement complété avec succès!${NC}"
        echo ""
        return 0
    fi

    if [ ${#SKIPPED_STEPS[@]} -gt 0 ]; then
        echo -e "${YELLOW}Étapes ignorées (${#SKIPPED_STEPS[@]}):${NC}"
        for step in "${SKIPPED_STEPS[@]}"; do
            echo "  • $step"
        done
        echo ""
    fi

    if [ ${#FAILED_STEPS[@]} -gt 0 ]; then
        echo -e "${RED}Étapes échouées (${#FAILED_STEPS[@]}):${NC}"
        for step in "${FAILED_STEPS[@]}"; do
            echo "  • $step"
        done
        echo ""
        echo -e "${YELLOW}Consultez le log pour plus de détails:${NC}"
        echo "  $DEPLOYMENT_LOG"
        echo ""
        return 1
    fi
}

# ============================================================================
# VÉRIFICATIONS INITIALES
# ============================================================================

show_header

# Vérifier si root
if [[ $EUID -ne 0 ]]; then
    log_error "Ce script doit être exécuté en tant que root"
    exit 1
fi

# Vérifier prérequis
log_step "Vérification des prérequis système..."
if [ -f "$SCRIPT_DIR/check-prerequisites.sh" ]; then
    if ! bash "$SCRIPT_DIR/check-prerequisites.sh" "auto" >> "$DEPLOYMENT_LOG" 2>&1; then
        log_warning "Certains prérequis ne sont pas optimaux"
        log_warning "Le déploiement peut continuer mais peut rencontrer des problèmes"
        read -p "Continuer quand même? [y/N]: " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            log_error "Déploiement annulé"
            exit 1
        fi
    fi
fi

log_step "Configuration détectée:"
if [ -f "$SCRIPT_DIR/lib-config.sh" ]; then
    source "$SCRIPT_DIR/lib-config.sh" 2>/dev/null
    if [ -f "$SCRIPT_DIR/config.sh" ]; then
        source "$SCRIPT_DIR/config.sh" 2>/dev/null
        echo "  VIP: ${VIP:-Non définie}"
        echo "  Masters: $(get_master_count 2>/dev/null || echo 'Non détecté') nœuds"
    fi
fi

echo ""
echo -e "${YELLOW}Type de déploiement:${NC}"
echo "[1] Installation complète (tous les nœuds)"
echo "[2] Premier master uniquement"
echo "[3] Master secondaire uniquement"
echo "[4] Worker uniquement"
echo ""
read -p "Votre choix: " deployment_type

echo ""

# ============================================================================
# DÉPLOIEMENT
# ============================================================================

case $deployment_type in
    1)
        log_step "Déploiement COMPLET - Tous les nœuds"
        log_warning "ATTENTION: Assurez-vous d'exécuter cela sur TOUS les nœuds"
        echo ""
        run_step "common-setup.sh" "Configuration commune"
        ;;
    2)
        log_step "Déploiement PREMIER MASTER"
        run_step "common-setup.sh" "Configuration commune"
        run_step "master-setup.sh" "Configuration master"
        run_step "setup-keepalived.sh" "Configuration keepalived (MASTER)" true
        run_step "init-cluster.sh" "Initialisation cluster" true
        run_step "install-calico.sh" "Installation Calico CNI" true
        ;;
    3)
        log_step "Déploiement MASTER SECONDAIRE"
        run_step "common-setup.sh" "Configuration commune"
        run_step "master-setup.sh" "Configuration master"
        run_step "setup-keepalived.sh" "Configuration keepalived (BACKUP)" true
        log_warning "Utilisez la commande kubeadm join fournie pour rejoindre le cluster"
        ;;
    4)
        log_step "Déploiement WORKER"
        run_step "common-setup.sh" "Configuration commune"
        run_step "worker-setup.sh" "Configuration worker"
        log_warning "Utilisez la commande kubeadm join pour rejoindre le cluster"
        ;;
    *)
        log_error "Choix invalide"
        exit 1
        ;;
esac

# ============================================================================
# RÉSUMÉ ET NETTOYAGE
# ============================================================================

show_summary
RESULT=$?

echo -e "${CYAN}Log complet disponible:${NC}"
echo "  $DEPLOYMENT_LOG"
echo ""

exit $RESULT
