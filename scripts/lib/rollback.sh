#!/bin/bash
################################################################################
# Système de rollback automatique pour les installations Kubernetes
# Auteur: azurtech56
# Version: 1.0
# Usage: source "$(dirname "$0")/lib/rollback.sh"
################################################################################

# Stack des opérations effectuées (LIFO - Last In First Out)
declare -a ROLLBACK_STACK=()

# Enregistrer une opération réversible
register_rollback() {
    local rollback_cmd="$1"
    local description="$2"

    ROLLBACK_STACK+=("$rollback_cmd|$description")

    if type log_debug &>/dev/null; then
        log_debug "Rollback enregistré: $description"
    fi
}

# Exécuter tous les rollbacks
execute_rollback() {
    local reason="$1"

    if [ ${#ROLLBACK_STACK[@]} -eq 0 ]; then
        if type log_info &>/dev/null; then
            log_info "Aucune opération à annuler"
        else
            echo "Aucune opération à annuler"
        fi
        return 0
    fi

    if type log_error &>/dev/null; then
        log_error "=== ÉCHEC DE L'INSTALLATION ==="
        log_error "Raison: $reason"
        log_warn "=== ROLLBACK AUTOMATIQUE EN COURS ==="
    else
        echo "=== ÉCHEC DE L'INSTALLATION ==="
        echo "Raison: $reason"
        echo "=== ROLLBACK AUTOMATIQUE EN COURS ==="
    fi

    echo ""

    # Parcourir la stack en ordre inverse (LIFO)
    for (( idx=${#ROLLBACK_STACK[@]}-1 ; idx>=0 ; idx-- )) ; do
        local entry="${ROLLBACK_STACK[idx]}"
        local cmd=$(echo "$entry" | cut -d'|' -f1)
        local desc=$(echo "$entry" | cut -d'|' -f2)

        if type log_info &>/dev/null; then
            log_info "Annulation: $desc"
        else
            echo "Annulation: $desc"
        fi

        if eval "$cmd" 2>/dev/null; then
            if type log_success &>/dev/null; then
                log_success "  ✓ Annulé"
            else
                echo "  ✓ Annulé"
            fi
        else
            if type log_warn &>/dev/null; then
                log_warn "  ⚠ Échec (peut être déjà supprimé)"
            else
                echo "  ⚠ Échec (peut être déjà supprimé)"
            fi
        fi

        sleep 1
    done

    echo ""
    if type log_success &>/dev/null; then
        log_success "Rollback terminé - système restauré à l'état initial"
    else
        echo "Rollback terminé - système restauré à l'état initial"
    fi
}

# Nettoyer la stack après succès
clear_rollback_stack() {
    ROLLBACK_STACK=()

    if type log_debug &>/dev/null; then
        log_debug "Stack de rollback nettoyée"
    fi
}

# Trap pour rollback automatique en cas d'erreur
enable_auto_rollback() {
    trap 'execute_rollback "Erreur ligne $LINENO: $BASH_COMMAND"' ERR
    trap 'execute_rollback "Script interrompu par l'\''utilisateur"' INT TERM

    if type log_debug &>/dev/null; then
        log_debug "Auto-rollback activé"
    fi
}

# Exporter les fonctions
export -f register_rollback
export -f execute_rollback
export -f clear_rollback_stack
export -f enable_auto_rollback
