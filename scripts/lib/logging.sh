#!/bin/bash
################################################################################
# Bibliothèque de logging pour les scripts Kubernetes
# Auteur: azurtech56
# Version: 1.1
################################################################################

LOG_DIR="${LOG_DIR:-/var/log/k8s-setup}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"  # DEBUG, INFO, WARN, ERROR
ENABLE_COLORS="${ENABLE_COLORS:-1}"

# Codes couleur
if [ $ENABLE_COLORS -eq 1 ]; then
    C_RESET='\033[0m'
    C_RED='\033[0;31m'
    C_GREEN='\033[0;32m'
    C_YELLOW='\033[1;33m'
    C_BLUE='\033[0;34m'
    C_CYAN='\033[0;36m'
    C_MAGENTA='\033[0;35m'
else
    C_RESET='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_CYAN='' C_MAGENTA=''
fi

# Fonction interne de logging
_log() {
    local level=$1
    local color=$2
    shift 2
    local message="$*"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')

    # Filtrer selon LOG_LEVEL
    case $LOG_LEVEL in
        DEBUG) ;;
        INFO) [ "$level" = "DEBUG" ] && return ;;
        WARN) [ "$level" = "DEBUG" ] || [ "$level" = "INFO" ] && return ;;
        ERROR) [ "$level" != "ERROR" ] && return ;;
    esac

    # Affichage console avec couleur
    echo -e "${color}[$timestamp] [$level] $message${C_RESET}"

    # Écriture fichier sans couleur
    if [ -n "${LOG_FILE:-}" ]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
}

log_debug() { _log "DEBUG" "$C_BLUE" "$@"; }
log_info() { _log "INFO" "$C_RESET" "$@"; }
log_warn() { _log "WARN" "$C_YELLOW" "$@"; }
log_error() { _log "ERROR" "$C_RED" "$@"; }
log_success() { _log "SUCCESS" "$C_GREEN" "$@"; }

# Initialisation du logging
init_logging() {
    local script_name=$(basename "${BASH_SOURCE[1]}" .sh 2>/dev/null || echo "script")

    mkdir -p "$LOG_DIR" 2>/dev/null || true

    if [ -w "$LOG_DIR" ]; then
        LOG_FILE="$LOG_DIR/${script_name}-$(date +%Y%m%d_%H%M%S).log"
        log_info "=== Début de $script_name ==="
        log_info "Utilisateur: $(whoami)"
        log_info "Hostname: $(hostname)"
    fi
}

# Fonction pour masquer les secrets dans les logs
mask_secret() {
    local secret=$1
    local length=${#secret}

    if [ $length -le 2 ]; then
        echo "***"
    elif [ $length -le 4 ]; then
        echo "${secret:0:1}**${secret: -1}"
    else
        local visible=$((length / 4))
        local masked=$((length - visible * 2))
        echo "${secret:0:$visible}$(printf '*%.0s' $(seq 1 $masked))${secret: -$visible}"
    fi
}

# Exporter les fonctions et variables
export LOG_DIR LOG_LEVEL LOG_FILE
export -f _log
export -f log_debug
export -f log_info
export -f log_warn
export -f log_error
export -f log_success
export -f init_logging
export -f mask_secret
