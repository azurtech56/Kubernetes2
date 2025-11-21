#!/bin/bash

################################################################################
# Kubernetes HA Setup - Notifications Multi-Canal
# Version: 2.0.0
# Description: Système de notifications vers Slack, Email, Discord, Telegram
################################################################################

# Configuration par défaut (peut être surchargée par .env)
NOTIFICATION_ENABLED="${NOTIFICATION_ENABLED:-false}"
NOTIFICATION_LEVEL="${NOTIFICATION_LEVEL:-info}"  # debug, info, warn, error, critical

# Slack
SLACK_ENABLED="${SLACK_ENABLED:-false}"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
SLACK_CHANNEL="${SLACK_CHANNEL:-#kubernetes}"
SLACK_USERNAME="${SLACK_USERNAME:-K8s-HA-Bot}"
SLACK_ICON="${SLACK_ICON:-:kubernetes:}"

# Email
EMAIL_ENABLED="${EMAIL_ENABLED:-false}"
EMAIL_FROM="${EMAIL_FROM:-k8s-ha@localhost}"
EMAIL_TO="${EMAIL_TO:-admin@localhost}"
EMAIL_SMTP_HOST="${EMAIL_SMTP_HOST:-localhost}"
EMAIL_SMTP_PORT="${EMAIL_SMTP_PORT:-25}"
EMAIL_SMTP_USER="${EMAIL_SMTP_USER:-}"
EMAIL_SMTP_PASSWORD="${EMAIL_SMTP_PASSWORD:-}"
EMAIL_USE_TLS="${EMAIL_USE_TLS:-false}"

# Discord
DISCORD_ENABLED="${DISCORD_ENABLED:-false}"
DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"
DISCORD_USERNAME="${DISCORD_USERNAME:-K8s-HA-Bot}"

# Telegram
TELEGRAM_ENABLED="${TELEGRAM_ENABLED:-false}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

# Niveaux de priorité
declare -gA NOTIFICATION_LEVELS=(
    ["debug"]=0
    ["info"]=1
    ["warn"]=2
    ["error"]=3
    ["critical"]=4
)

# Fonction pour vérifier si une notification doit être envoyée
should_notify() {
    local level="$1"

    if [ "$NOTIFICATION_ENABLED" != "true" ]; then
        return 1
    fi

    local current_level=${NOTIFICATION_LEVELS[$NOTIFICATION_LEVEL]:-1}
    local message_level=${NOTIFICATION_LEVELS[$level]:-1}

    [ "$message_level" -ge "$current_level" ]
}

################################################################################
# SLACK
################################################################################

send_slack() {
    local level="$1"
    local title="$2"
    local message="$3"
    local color="${4:-#439FE0}"

    if [ "$SLACK_ENABLED" != "true" ] || [ -z "$SLACK_WEBHOOK_URL" ]; then
        return 0
    fi

    if ! should_notify "$level"; then
        return 0
    fi

    # Couleurs selon le niveau
    case "$level" in
        "debug")   color="#6c757d" ;;
        "info")    color="#0dcaf0" ;;
        "warn")    color="#ffc107" ;;
        "error")   color="#dc3545" ;;
        "critical") color="#a71d2a" ;;
    esac

    local emoji
    case "$level" in
        "debug")   emoji=":mag:" ;;
        "info")    emoji=":information_source:" ;;
        "warn")    emoji=":warning:" ;;
        "error")   emoji=":x:" ;;
        "critical") emoji=":rotating_light:" ;;
    esac

    local hostname=$(hostname)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    local payload=$(cat <<EOF
{
    "channel": "$SLACK_CHANNEL",
    "username": "$SLACK_USERNAME",
    "icon_emoji": "$SLACK_ICON",
    "attachments": [
        {
            "color": "$color",
            "title": "$emoji $title",
            "text": "$message",
            "fields": [
                {
                    "title": "Serveur",
                    "value": "$hostname",
                    "short": true
                },
                {
                    "title": "Niveau",
                    "value": "${level^^}",
                    "short": true
                },
                {
                    "title": "Date",
                    "value": "$timestamp",
                    "short": false
                }
            ],
            "footer": "Kubernetes HA Setup",
            "footer_icon": "https://kubernetes.io/images/favicon.png"
        }
    ]
}
EOF
)

    curl -X POST -H 'Content-type: application/json' \
        --data "$payload" \
        "$SLACK_WEBHOOK_URL" \
        --silent --show-error --max-time 10 > /dev/null 2>&1

    local status=$?
    if [ $status -ne 0 ]; then
        echo "⚠️  Échec envoi notification Slack (code: $status)" >&2
    fi

    return $status
}

################################################################################
# EMAIL
################################################################################

send_email() {
    local level="$1"
    local title="$2"
    local message="$3"

    if [ "$EMAIL_ENABLED" != "true" ]; then
        return 0
    fi

    if ! should_notify "$level"; then
        return 0
    fi

    # Vérifier que sendmail ou mailx est installé
    if ! command -v mail &> /dev/null && ! command -v sendmail &> /dev/null; then
        echo "⚠️  mailx/sendmail non installé, impossible d'envoyer l'email" >&2
        return 1
    fi

    local hostname=$(hostname)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local subject="[K8s-HA] [${level^^}] $title"

    local body=$(cat <<EOF
Kubernetes HA Setup - Notification

Niveau: ${level^^}
Serveur: $hostname
Date: $timestamp

$title
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$message

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Kubernetes HA Setup v2.0.0
EOF
)

    if command -v mail &> /dev/null; then
        echo "$body" | mail -s "$subject" -r "$EMAIL_FROM" "$EMAIL_TO" 2>&1 > /dev/null
    else
        echo -e "Subject: $subject\nFrom: $EMAIL_FROM\nTo: $EMAIL_TO\n\n$body" | sendmail -t 2>&1 > /dev/null
    fi

    local status=$?
    if [ $status -ne 0 ]; then
        echo "⚠️  Échec envoi email (code: $status)" >&2
    fi

    return $status
}

################################################################################
# DISCORD
################################################################################

send_discord() {
    local level="$1"
    local title="$2"
    local message="$3"

    if [ "$DISCORD_ENABLED" != "true" ] || [ -z "$DISCORD_WEBHOOK_URL" ]; then
        return 0
    fi

    if ! should_notify "$level"; then
        return 0
    fi

    # Couleurs selon le niveau (format décimal)
    local color
    case "$level" in
        "debug")   color=7109487 ;;   # #6c757d
        "info")    color=900336 ;;    # #0dcaf0
        "warn")    color=16766215 ;;  # #ffc107
        "error")   color=14431557 ;;  # #dc3545
        "critical") color=10952234 ;; # #a71d2a
    esac

    local emoji
    case "$level" in
        "debug")   emoji="🔍" ;;
        "info")    emoji="ℹ️" ;;
        "warn")    emoji="⚠️" ;;
        "error")   emoji="❌" ;;
        "critical") emoji="🚨" ;;
    esac

    local hostname=$(hostname)
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    local payload=$(cat <<EOF
{
    "username": "$DISCORD_USERNAME",
    "embeds": [
        {
            "title": "$emoji $title",
            "description": "$message",
            "color": $color,
            "fields": [
                {
                    "name": "Serveur",
                    "value": "$hostname",
                    "inline": true
                },
                {
                    "name": "Niveau",
                    "value": "${level^^}",
                    "inline": true
                }
            ],
            "footer": {
                "text": "Kubernetes HA Setup"
            },
            "timestamp": "$timestamp"
        }
    ]
}
EOF
)

    curl -X POST -H 'Content-type: application/json' \
        --data "$payload" \
        "$DISCORD_WEBHOOK_URL" \
        --silent --show-error --max-time 10 > /dev/null 2>&1

    local status=$?
    if [ $status -ne 0 ]; then
        echo "⚠️  Échec envoi notification Discord (code: $status)" >&2
    fi

    return $status
}

################################################################################
# TELEGRAM
################################################################################

send_telegram() {
    local level="$1"
    local title="$2"
    local message="$3"

    if [ "$TELEGRAM_ENABLED" != "true" ] || [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        return 0
    fi

    if ! should_notify "$level"; then
        return 0
    fi

    local emoji
    case "$level" in
        "debug")   emoji="🔍" ;;
        "info")    emoji="ℹ️" ;;
        "warn")    emoji="⚠️" ;;
        "error")   emoji="❌" ;;
        "critical") emoji="🚨" ;;
    esac

    local hostname=$(hostname)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    local text=$(cat <<EOF
$emoji <b>$title</b>

$message

<b>Serveur:</b> $hostname
<b>Niveau:</b> ${level^^}
<b>Date:</b> $timestamp

<i>Kubernetes HA Setup v2.0.0</i>
EOF
)

    curl -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d parse_mode="HTML" \
        -d text="$text" \
        --silent --show-error --max-time 10 > /dev/null 2>&1

    local status=$?
    if [ $status -ne 0 ]; then
        echo "⚠️  Échec envoi notification Telegram (code: $status)" >&2
    fi

    return $status
}

################################################################################
# FONCTION UNIFIÉE
################################################################################

notify() {
    local level="${1:-info}"
    local title="$2"
    local message="$3"

    if [ "$NOTIFICATION_ENABLED" != "true" ]; then
        return 0
    fi

    if ! should_notify "$level"; then
        return 0
    fi

    # Log local
    if type -t log_info &>/dev/null; then
        case "$level" in
            "debug")   log_debug "[NOTIF] $title: $message" ;;
            "info")    log_info "[NOTIF] $title: $message" ;;
            "warn")    log_warn "[NOTIF] $title: $message" ;;
            "error"|"critical") log_error "[NOTIF] $title: $message" ;;
        esac
    fi

    # Envoyer vers tous les canaux configurés (en parallèle)
    local pids=()

    if [ "$SLACK_ENABLED" = "true" ]; then
        send_slack "$level" "$title" "$message" &
        pids+=($!)
    fi

    if [ "$EMAIL_ENABLED" = "true" ]; then
        send_email "$level" "$title" "$message" &
        pids+=($!)
    fi

    if [ "$DISCORD_ENABLED" = "true" ]; then
        send_discord "$level" "$title" "$message" &
        pids+=($!)
    fi

    if [ "$TELEGRAM_ENABLED" = "true" ]; then
        send_telegram "$level" "$title" "$message" &
        pids+=($!)
    fi

    # Attendre la fin de tous les envois
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done
}

################################################################################
# FONCTIONS HELPERS
################################################################################

notify_debug() {
    notify "debug" "$1" "${2:-}"
}

notify_info() {
    notify "info" "$1" "${2:-}"
}

notify_warn() {
    notify "warn" "$1" "${2:-}"
}

notify_error() {
    notify "error" "$1" "${2:-}"
}

notify_critical() {
    notify "critical" "$1" "${2:-}"
}

# Notification de démarrage d'installation
notify_install_start() {
    local component="$1"
    notify_info "Installation démarrée" "Début de l'installation de $component"
}

# Notification de fin d'installation
notify_install_success() {
    local component="$1"
    local duration="${2:-}"
    local msg="Installation de $component terminée avec succès"
    [ -n "$duration" ] && msg="$msg (durée: $duration)"
    notify_info "Installation réussie" "$msg"
}

# Notification d'échec d'installation
notify_install_failed() {
    local component="$1"
    local error="${2:-Erreur inconnue}"
    notify_error "Installation échouée" "Échec de l'installation de $component\n\nErreur: $error"
}

# Notification de santé du cluster
notify_health_check() {
    local status="$1"  # healthy, degraded, critical
    local details="${2:-}"

    case "$status" in
        "healthy")
            notify_info "Cluster en bonne santé" "$details"
            ;;
        "degraded")
            notify_warn "Cluster dégradé" "$details"
            ;;
        "critical")
            notify_critical "Cluster critique" "$details"
            ;;
    esac
}

# Notification de backup
notify_backup() {
    local status="$1"  # success, failed
    local backup_path="${2:-}"
    local size="${3:-}"

    case "$status" in
        "success")
            local msg="Backup réussi: $backup_path"
            [ -n "$size" ] && msg="$msg\nTaille: $size"
            notify_info "Backup terminé" "$msg"
            ;;
        "failed")
            notify_error "Backup échoué" "Échec de la sauvegarde\n\nChemin: $backup_path\nErreur: $size"
            ;;
    esac
}

# Test de configuration
test_notifications() {
    echo "🧪 Test des notifications configurées..."
    echo ""

    local success=0
    local failed=0

    if [ "$SLACK_ENABLED" = "true" ]; then
        echo -n "  • Slack... "
        if send_slack "info" "Test Notification" "Ceci est un test de notification Slack depuis Kubernetes HA Setup."; then
            echo "✅"
            ((success++))
        else
            echo "❌"
            ((failed++))
        fi
    fi

    if [ "$EMAIL_ENABLED" = "true" ]; then
        echo -n "  • Email... "
        if send_email "info" "Test Notification" "Ceci est un test de notification Email depuis Kubernetes HA Setup."; then
            echo "✅"
            ((success++))
        else
            echo "❌"
            ((failed++))
        fi
    fi

    if [ "$DISCORD_ENABLED" = "true" ]; then
        echo -n "  • Discord... "
        if send_discord "info" "Test Notification" "Ceci est un test de notification Discord depuis Kubernetes HA Setup."; then
            echo "✅"
            ((success++))
        else
            echo "❌"
            ((failed++))
        fi
    fi

    if [ "$TELEGRAM_ENABLED" = "true" ]; then
        echo -n "  • Telegram... "
        if send_telegram "info" "Test Notification" "Ceci est un test de notification Telegram depuis Kubernetes HA Setup."; then
            echo "✅"
            ((success++))
        else
            echo "❌"
            ((failed++))
        fi
    fi

    echo ""
    echo "Résultat: $success réussi(s), $failed échec(s)"
    echo ""

    if [ $success -eq 0 ]; then
        echo "❌ Aucune notification n'a été envoyée."
        echo "💡 Vérifiez la configuration dans scripts/.env"
        return 1
    fi

    return 0
}

# Export des fonctions
export -f should_notify
export -f send_slack
export -f send_email
export -f send_discord
export -f send_telegram
export -f notify
export -f notify_debug
export -f notify_info
export -f notify_warn
export -f notify_error
export -f notify_critical
export -f notify_install_start
export -f notify_install_success
export -f notify_install_failed
export -f notify_health_check
export -f notify_backup
export -f test_notifications
