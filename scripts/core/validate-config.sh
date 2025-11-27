#!/bin/bash
################################################################################
# Script de validation de la configuration Kubernetes HA
# Valide toutes les valeurs de config.sh avant installation
# Auteur: azurtech56
# Version: 2.0
################################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

# Compteurs
ERRORS=0
WARNINGS=0
CHECKS=0

# Options
FIX_MODE=false
VERBOSE=false

# Charger la configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

################################################################################
# FONCTIONS UTILITAIRES
################################################################################

show_usage() {
    cat <<EOF
${CYAN}════════════════════════════════════════════════════════════════${NC}
  Validation de Configuration Kubernetes HA
${CYAN}════════════════════════════════════════════════════════════════${NC}

${YELLOW}Usage:${NC}
  $0 [options]

${YELLOW}Options:${NC}
  --fix               Corriger automatiquement les erreurs simples
  -v, --verbose       Mode verbeux (afficher toutes les validations)
  -h, --help          Afficher cette aide

${YELLOW}Exemples:${NC}
  $0                  # Validation standard
  $0 --verbose        # Validation détaillée
  $0 --fix            # Avec corrections automatiques

${CYAN}════════════════════════════════════════════════════════════════${NC}
EOF
}

check_ok() {
    echo -e "${GREEN}✓${NC} $1"
    ((CHECKS++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
    ((CHECKS++))
}

check_error() {
    echo -e "${RED}✗${NC} $1"
    ((ERRORS++))
    ((CHECKS++))
}

check_info() {
    [ "$VERBOSE" = true ] && echo -e "${BLUE}ℹ${NC} $1"
}

################################################################################
# FONCTIONS DE VALIDATION
################################################################################

# Convertir IP en entier (pour comparaisons)
ip_to_int() {
    local ip=$1
    local a b c d
    IFS='.' read -r a b c d <<< "$ip"
    echo $((a * 256**3 + b * 256**2 + c * 256 + d))
}

# Validation d'adresse IP
validate_ip() {
    local ip=$1
    local name=$2

    # Regex IP valide
    if [[ ! $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        check_error "$name: IP invalide '$ip' (format: xxx.xxx.xxx.xxx)"
        return 1
    fi

    # Vérifier chaque octet (0-255)
    IFS='.' read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if [ "$octet" -gt 255 ]; then
            check_error "$name: Octet invalide '$octet' dans '$ip' (max: 255)"
            return 1
        fi
    done

    # IPs réservées
    if [[ $ip =~ ^0\. ]]; then
        check_error "$name: IP réseau réservée '$ip' (commence par 0.)"
        return 1
    fi

    if [[ $ip =~ ^127\. ]]; then
        check_error "$name: IP loopback réservée '$ip' (127.x.x.x)"
        return 1
    fi

    if [[ $ip =~ ^255\. ]]; then
        check_error "$name: IP broadcast réservée '$ip' (255.x.x.x)"
        return 1
    fi

    check_ok "$name: $ip"
    return 0
}

# Validation de hostname
validate_hostname() {
    local hostname=$1
    local name=$2

    # Longueur
    if [ ${#hostname} -gt 63 ]; then
        check_error "$name: Hostname trop long '$hostname' (max: 63 caractères)"
        return 1
    fi

    if [ ${#hostname} -eq 0 ]; then
        check_error "$name: Hostname vide"
        return 1
    fi

    # Caractères valides: alphanumeric + hyphen
    # Ne doit pas commencer/finir par hyphen
    if [[ ! $hostname =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
        check_error "$name: Hostname invalide '$hostname' (alphanum + '-', pas de '_')"
        return 1
    fi

    # Hostnames génériques (avertissement)
    if [[ $hostname =~ ^(localhost|node|server|host)$ ]]; then
        check_warn "$name: Hostname générique '$hostname' (recommandé: plus descriptif)"
    else
        check_ok "$name: $hostname"
    fi

    return 0
}

# Validation FQDN
validate_fqdn() {
    local fqdn=$1
    local name=$2

    # Longueur max 253
    if [ ${#fqdn} -gt 253 ]; then
        check_error "$name: FQDN trop long '$fqdn' (max: 253 caractères)"
        return 1
    fi

    # Format: hostname.domain.tld
    if [[ ! $fqdn =~ ^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$ ]]; then
        check_error "$name: FQDN invalide '$fqdn' (format: hostname.domain.tld)"
        return 1
    fi

    check_ok "$name: $fqdn"
    return 0
}

# Validation CIDR
validate_cidr() {
    local cidr=$1
    local name=$2

    # Format: xxx.xxx.xxx.xxx/yy
    if [[ ! $cidr =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        check_error "$name: CIDR invalide '$cidr' (format: xxx.xxx.xxx.xxx/yy)"
        return 1
    fi

    # Extraire IP et masque
    local ip="${cidr%/*}"
    local mask="${cidr#*/}"

    # Valider l'IP
    IFS='.' read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if [ "$octet" -gt 255 ]; then
            check_error "$name: Octet invalide dans '$cidr'"
            return 1
        fi
    done

    # Valider le masque (0-32)
    if [ "$mask" -lt 0 ] || [ "$mask" -gt 32 ]; then
        check_error "$name: Masque invalide '/$mask' (range: /0 à /32)"
        return 1
    fi

    # Calcul du nombre d'IPs
    local available_ips=$((2 ** (32 - mask)))
    check_ok "$name: $cidr ($available_ips IPs disponibles)"

    return 0
}

# Validation de port
validate_port() {
    local port=$1
    local name=$2

    # Vérifier que c'est un nombre
    if ! [[ $port =~ ^[0-9]+$ ]]; then
        check_error "$name: Port invalide '$port' (doit être un nombre)"
        return 1
    fi

    # Plage valide: 1-65535
    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        check_error "$name: Port hors plage '$port' (range: 1-65535)"
        return 1
    fi

    # Ports privilégiés (avertissement)
    if [ "$port" -lt 1024 ]; then
        check_info "$name: Port privilégié $port (<1024, nécessite root)"
    fi

    check_ok "$name: $port"
    return 0
}

# Validation de plage IP
validate_ip_range() {
    local start_ip=$1
    local end_ip=$2
    local name=$3

    # Valider les deux IPs
    validate_ip "$start_ip" "${name}_START" || return 1
    validate_ip "$end_ip" "${name}_END" || return 1

    # Convertir en entiers
    local start_int=$(ip_to_int "$start_ip")
    local end_int=$(ip_to_int "$end_ip")

    # Vérifier que start < end
    if [ "$start_int" -ge "$end_int" ]; then
        check_error "$name: IP début ($start_ip) >= IP fin ($end_ip)"
        return 1
    fi

    # Calculer le nombre d'IPs
    local count=$((end_int - start_int + 1))
    check_ok "$name: $start_ip - $end_ip ($count IPs)"

    return 0
}

################################################################################
# VALIDATIONS SPÉCIFIQUES
################################################################################

# Validation du domaine
validate_domain() {
    echo ""
    echo -e "${CYAN}[1/12] Validation du domaine${NC}"
    echo ""

    # Domain name
    if [ -z "$DOMAIN_NAME" ]; then
        check_error "DOMAIN_NAME: Non défini"
    elif [[ ! $DOMAIN_NAME =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$ ]]; then
        check_error "DOMAIN_NAME: Format invalide '$DOMAIN_NAME'"
    else
        check_ok "DOMAIN_NAME: $DOMAIN_NAME"
    fi
}

# Validation VIP
validate_vip() {
    echo ""
    echo -e "${CYAN}[2/12] Validation VIP${NC}"
    echo ""

    validate_ip "$VIP" "VIP" || return 1
    validate_hostname "$VIP_HOSTNAME" "VIP_HOSTNAME" || return 1
    validate_fqdn "$VIP_FQDN" "VIP_FQDN" || return 1

    # Vérifier cohérence FQDN
    local expected_fqdn="${VIP_HOSTNAME}.${DOMAIN_NAME}"
    if [ "$VIP_FQDN" != "$expected_fqdn" ]; then
        check_error "VIP_FQDN incohérent: '$VIP_FQDN' (attendu: '$expected_fqdn')"
    fi
}

# Validation masters
validate_masters() {
    echo ""
    echo -e "${CYAN}[3/12] Validation des masters${NC}"
    echo ""

    local master_num=1
    local master_count=0
    local -A seen_ips
    local -A seen_hostnames
    local -A seen_priorities
    local highest_priority=0
    local highest_master=""

    while true; do
        local ip_var="MASTER${master_num}_IP"
        local hostname_var="MASTER${master_num}_HOSTNAME"
        local fqdn_var="MASTER${master_num}_FQDN"
        local priority_var="MASTER${master_num}_PRIORITY"

        local ip="${!ip_var}"

        [ -z "$ip" ] && break

        ((master_count++))

        # Valider IP
        validate_ip "$ip" "MASTER${master_num}_IP" || continue

        # Vérifier doublons IP
        if [ -n "${seen_ips[$ip]}" ]; then
            check_error "MASTER${master_num}_IP: IP dupliquée '$ip' (déjà utilisée par ${seen_ips[$ip]})"
        else
            seen_ips[$ip]="MASTER${master_num}"
        fi

        # Valider hostname
        local hostname="${!hostname_var}"
        if [ -n "$hostname" ]; then
            validate_hostname "$hostname" "MASTER${master_num}_HOSTNAME" || continue

            # Vérifier doublons hostname
            if [ -n "${seen_hostnames[$hostname]}" ]; then
                check_error "MASTER${master_num}_HOSTNAME: Hostname dupliqué '$hostname'"
            else
                seen_hostnames[$hostname]="MASTER${master_num}"
            fi
        fi

        # Valider FQDN
        local fqdn="${!fqdn_var}"
        if [ -n "$fqdn" ]; then
            validate_fqdn "$fqdn" "MASTER${master_num}_FQDN"

            # Vérifier cohérence
            local expected_fqdn="${hostname}.${DOMAIN_NAME}"
            if [ "$fqdn" != "$expected_fqdn" ]; then
                check_error "MASTER${master_num}_FQDN incohérent: '$fqdn' (attendu: '$expected_fqdn')"
            fi
        fi

        # Valider priorité
        local priority="${!priority_var}"
        if [ -n "$priority" ]; then
            if ! [[ $priority =~ ^[0-9]+$ ]] || [ "$priority" -lt 1 ] || [ "$priority" -gt 255 ]; then
                check_error "MASTER${master_num}_PRIORITY: Invalide '$priority' (range: 1-255)"
            else
                # Tracker la priorité la plus haute
                if [ "$priority" -gt "$highest_priority" ]; then
                    highest_priority=$priority
                    highest_master="MASTER${master_num}"
                fi

                # Vérifier doublons priorité
                if [ -n "${seen_priorities[$priority]}" ]; then
                    check_warn "MASTER${master_num}_PRIORITY: Priorité dupliquée '$priority' (aussi utilisée par ${seen_priorities[$priority]})"
                else
                    seen_priorities[$priority]="MASTER${master_num}"
                fi

                check_ok "MASTER${master_num}_PRIORITY: $priority"
            fi
        fi

        ((master_num++))
    done

    # Vérifier le nombre de masters
    if [ "$master_count" -eq 0 ]; then
        check_error "Aucun master configuré (minimum: 1)"
    elif [ "$master_count" -eq 1 ]; then
        check_warn "1 seul master (pas de haute disponibilité)"
        echo -e "${YELLOW}   Recommandation: Configurez 3 masters pour la HA${NC}"
    elif [ "$master_count" -eq 2 ]; then
        check_warn "2 masters (risque de split-brain)"
        echo -e "${YELLOW}   Recommandation: Utilisez 3 masters (nombre impair)${NC}"
    else
        check_ok "Masters: $master_count configurés (HA correcte)"
    fi

    # Afficher le master principal
    if [ -n "$highest_master" ]; then
        check_info "Master principal: $highest_master (priorité: $highest_priority)"
    fi
}

# Validation workers
validate_workers() {
    echo ""
    echo -e "${CYAN}[4/12] Validation des workers${NC}"
    echo ""

    local worker_num=1
    local worker_count=0
    local -A seen_ips
    local -A seen_hostnames

    while true; do
        local ip_var="WORKER${worker_num}_IP"
        local hostname_var="WORKER${worker_num}_HOSTNAME"
        local fqdn_var="WORKER${worker_num}_FQDN"

        local ip="${!ip_var}"

        [ -z "$ip" ] && break

        ((worker_count++))

        # Valider IP
        validate_ip "$ip" "WORKER${worker_num}_IP" || continue

        # Vérifier doublons IP
        if [ -n "${seen_ips[$ip]}" ]; then
            check_error "WORKER${worker_num}_IP: IP dupliquée '$ip' (déjà utilisée par ${seen_ips[$ip]})"
        else
            seen_ips[$ip]="WORKER${worker_num}"
        fi

        # Valider hostname
        local hostname="${!hostname_var}"
        if [ -n "$hostname" ]; then
            validate_hostname "$hostname" "WORKER${worker_num}_HOSTNAME" || continue

            # Vérifier doublons
            if [ -n "${seen_hostnames[$hostname]}" ]; then
                check_error "WORKER${worker_num}_HOSTNAME: Hostname dupliqué '$hostname'"
            else
                seen_hostnames[$hostname]="WORKER${worker_num}"
            fi
        fi

        # Valider FQDN
        local fqdn="${!fqdn_var}"
        if [ -n "$fqdn" ]; then
            validate_fqdn "$fqdn" "WORKER${worker_num}_FQDN"

            local expected_fqdn="${hostname}.${DOMAIN_NAME}"
            if [ "$fqdn" != "$expected_fqdn" ]; then
                check_error "WORKER${worker_num}_FQDN incohérent: '$fqdn' (attendu: '$expected_fqdn')"
            fi
        fi

        ((worker_num++))
    done

    # Afficher le nombre de workers
    if [ "$worker_count" -eq 0 ]; then
        check_warn "Aucun worker configuré (cluster master-only)"
    else
        check_ok "Workers: $worker_count configurés"
    fi
}

# Validation réseau cluster
validate_cluster_network() {
    echo ""
    echo -e "${CYAN}[5/12] Validation réseau cluster${NC}"
    echo ""

    validate_cidr "$CLUSTER_NODES_NETWORK" "CLUSTER_NODES_NETWORK" || return 1

    # Vérifier que tous les nœuds sont dans ce réseau
    local network_ip="${CLUSTER_NODES_NETWORK%/*}"
    local network_mask="${CLUSTER_NODES_NETWORK#*/}"
    local network_int=$(ip_to_int "$network_ip")
    local network_size=$((2 ** (32 - network_mask)))
    local network_end=$((network_int + network_size - 1))

    # Vérifier VIP
    local vip_int=$(ip_to_int "$VIP")
    if [ "$vip_int" -lt "$network_int" ] || [ "$vip_int" -gt "$network_end" ]; then
        check_error "VIP $VIP hors du réseau cluster $CLUSTER_NODES_NETWORK"
    fi

    # Vérifier les masters
    local master_num=1
    while true; do
        local ip_var="MASTER${master_num}_IP"
        local ip="${!ip_var}"
        [ -z "$ip" ] && break

        local ip_int=$(ip_to_int "$ip")
        if [ "$ip_int" -lt "$network_int" ] || [ "$ip_int" -gt "$network_end" ]; then
            check_error "MASTER${master_num}_IP ($ip) hors du réseau cluster"
        fi

        ((master_num++))
    done

    # Vérifier les workers
    local worker_num=1
    while true; do
        local ip_var="WORKER${worker_num}_IP"
        local ip="${!ip_var}"
        [ -z "$ip" ] && break

        local ip_int=$(ip_to_int "$ip")
        if [ "$ip_int" -lt "$network_int" ] || [ "$ip_int" -gt "$network_end" ]; then
            check_error "WORKER${worker_num}_IP ($ip) hors du réseau cluster"
        fi

        ((worker_num++))
    done
}

# Validation MetalLB
validate_metallb() {
    echo ""
    echo -e "${CYAN}[6/12] Validation MetalLB${NC}"
    echo ""

    validate_ip_range "$METALLB_IP_START" "$METALLB_IP_END" "METALLB_IP_RANGE" || return 1

    # Vérifier les chevauchements avec les nœuds
    local start_int=$(ip_to_int "$METALLB_IP_START")
    local end_int=$(ip_to_int "$METALLB_IP_END")
    local has_overlap=false

    # VIP
    local vip_int=$(ip_to_int "$VIP")
    if [ "$vip_int" -ge "$start_int" ] && [ "$vip_int" -le "$end_int" ]; then
        check_error "VIP ($VIP) chevauche la plage MetalLB"
        has_overlap=true
    fi

    # Masters
    local master_num=1
    while true; do
        local ip_var="MASTER${master_num}_IP"
        local ip="${!ip_var}"
        [ -z "$ip" ] && break

        local ip_int=$(ip_to_int "$ip")
        if [ "$ip_int" -ge "$start_int" ] && [ "$ip_int" -le "$end_int" ]; then
            check_error "MASTER${master_num}_IP ($ip) chevauche la plage MetalLB"
            has_overlap=true
        fi

        ((master_num++))
    done

    # Workers
    local worker_num=1
    while true; do
        local ip_var="WORKER${worker_num}_IP"
        local ip="${!ip_var}"
        [ -z "$ip" ] && break

        local ip_int=$(ip_to_int "$ip")
        if [ "$ip_int" -ge "$start_int" ] && [ "$ip_int" -le "$end_int" ]; then
            check_error "WORKER${worker_num}_IP ($ip) chevauche la plage MetalLB"
            has_overlap=true
        fi

        ((worker_num++))
    done

    if [ "$has_overlap" = false ]; then
        check_ok "Aucun chevauchement IP détecté"
    else
        echo -e "${YELLOW}   💡 Solution: Ajustez METALLB_IP_START/END pour éviter les IPs des nœuds${NC}"
    fi
}

# Validation keepalived
validate_keepalived() {
    echo ""
    echo -e "${CYAN}[7/12] Validation keepalived${NC}"
    echo ""

    # VRRP Router ID (1-255)
    if ! [[ $VRRP_ROUTER_ID =~ ^[0-9]+$ ]] || [ "$VRRP_ROUTER_ID" -lt 1 ] || [ "$VRRP_ROUTER_ID" -gt 255 ]; then
        check_error "VRRP_ROUTER_ID: Invalide '$VRRP_ROUTER_ID' (range: 1-255)"
    else
        check_ok "VRRP_ROUTER_ID: $VRRP_ROUTER_ID"
    fi

    # VRRP Advert Interval
    if ! [[ $VRRP_ADVERT_INT =~ ^[0-9]+$ ]] || [ "$VRRP_ADVERT_INT" -lt 1 ]; then
        check_error "VRRP_ADVERT_INT: Invalide '$VRRP_ADVERT_INT' (minimum: 1)"
    else
        check_ok "VRRP_ADVERT_INT: $VRRP_ADVERT_INT secondes"
    fi

    # VRRP Password (chargé depuis .env normalement)
    if [ -n "${VRRP_PASSWORD:-}" ]; then
        local pwd_length=${#VRRP_PASSWORD}
        if [ "$pwd_length" -gt 8 ]; then
            check_warn "VRRP_PASSWORD: Longueur $pwd_length caractères (keepalived limite à 8)"
        else
            check_ok "VRRP_PASSWORD: Configuré ($pwd_length caractères)"
        fi
    else
        check_warn "VRRP_PASSWORD: Non défini (devrait être dans .env)"
    fi
}

# Validation Kubernetes
validate_kubernetes() {
    echo ""
    echo -e "${CYAN}[8/12] Validation Kubernetes${NC}"
    echo ""

    # Version K8s
    if [[ ! $K8S_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        check_error "K8S_VERSION: Format invalide '$K8S_VERSION' (format: X.Y.Z)"
    else
        check_ok "K8S_VERSION: $K8S_VERSION"
    fi

    # K8S Repo Version
    local expected_repo=$(echo "$K8S_VERSION" | cut -d'.' -f1,2)
    if [ "$K8S_REPO_VERSION" != "$expected_repo" ]; then
        check_error "K8S_REPO_VERSION: Incohérent '$K8S_REPO_VERSION' (attendu: '$expected_repo')"
    else
        check_ok "K8S_REPO_VERSION: $K8S_REPO_VERSION"
    fi

    # Pod Subnet
    validate_cidr "$POD_SUBNET" "POD_SUBNET"

    # Service Subnet
    validate_cidr "$SERVICE_SUBNET" "SERVICE_SUBNET"

    # API Server Port
    validate_port "$API_SERVER_PORT" "API_SERVER_PORT"

    # CRI Socket
    if [ -n "$CRI_SOCKET" ]; then
        check_ok "CRI_SOCKET: $CRI_SOCKET"
    else
        check_warn "CRI_SOCKET: Non défini"
    fi
}

# Validation réseaux (chevauchements)
validate_network_overlaps() {
    echo ""
    echo -e "${CYAN}[9/12] Validation chevauchements réseaux${NC}"
    echo ""

    # Fonction pour vérifier chevauchement de deux réseaux CIDR
    check_cidr_overlap() {
        local net1=$1
        local net2=$2
        local name1=$3
        local name2=$4

        local ip1="${net1%/*}"
        local mask1="${net1#*/}"
        local ip2="${net2%/*}"
        local mask2="${net2#*/}"

        local ip1_int=$(ip_to_int "$ip1")
        local ip2_int=$(ip_to_int "$ip2")

        local size1=$((2 ** (32 - mask1)))
        local size2=$((2 ** (32 - mask2)))

        local end1=$((ip1_int + size1 - 1))
        local end2=$((ip2_int + size2 - 1))

        if [ "$ip1_int" -le "$end2" ] && [ "$end1" -ge "$ip2_int" ]; then
            check_error "Chevauchement: $name1 ($net1) et $name2 ($net2)"
            return 1
        fi

        return 0
    }

    # Vérifier POD_SUBNET vs SERVICE_SUBNET
    check_cidr_overlap "$POD_SUBNET" "$SERVICE_SUBNET" "POD_SUBNET" "SERVICE_SUBNET"

    # Vérifier POD_SUBNET vs CLUSTER_NODES_NETWORK
    check_cidr_overlap "$POD_SUBNET" "$CLUSTER_NODES_NETWORK" "POD_SUBNET" "CLUSTER_NODES_NETWORK"

    # Vérifier SERVICE_SUBNET vs CLUSTER_NODES_NETWORK
    check_cidr_overlap "$SERVICE_SUBNET" "$CLUSTER_NODES_NETWORK" "SERVICE_SUBNET" "CLUSTER_NODES_NETWORK"

    check_ok "Pas de chevauchement de réseaux critiques"
}

# Validation Rancher
validate_rancher() {
    echo ""
    echo -e "${CYAN}[10/12] Validation Rancher${NC}"
    echo ""

    # Subdomain
    if [ -n "$RANCHER_SUBDOMAIN" ]; then
        validate_hostname "$RANCHER_SUBDOMAIN" "RANCHER_SUBDOMAIN"
    else
        check_warn "RANCHER_SUBDOMAIN: Non défini"
    fi

    # Hostname
    if [ -n "$RANCHER_HOSTNAME" ]; then
        validate_fqdn "$RANCHER_HOSTNAME" "RANCHER_HOSTNAME"

        local expected_hostname="${RANCHER_SUBDOMAIN}.${DOMAIN_NAME}"
        if [ "$RANCHER_HOSTNAME" != "$expected_hostname" ]; then
            check_error "RANCHER_HOSTNAME incohérent: '$RANCHER_HOSTNAME' (attendu: '$expected_hostname')"
        fi
    fi

    # Password (devrait être dans .env)
    if [ -n "${RANCHER_PASSWORD:-}" ]; then
        check_ok "RANCHER_PASSWORD: Configuré"
    else
        check_warn "RANCHER_PASSWORD: Non défini (devrait être dans .env)"
    fi

    # TLS Source
    if [[ "$RANCHER_TLS_SOURCE" =~ ^(rancher|letsEncrypt|secret)$ ]]; then
        check_ok "RANCHER_TLS_SOURCE: $RANCHER_TLS_SOURCE"
    else
        check_warn "RANCHER_TLS_SOURCE: Valeur non standard '$RANCHER_TLS_SOURCE'"
    fi
}

# Validation Monitoring
validate_monitoring() {
    echo ""
    echo -e "${CYAN}[11/12] Validation Monitoring${NC}"
    echo ""

    # Grafana password
    if [ -n "${GRAFANA_PASSWORD:-}" ]; then
        check_ok "GRAFANA_PASSWORD: Configuré"
    else
        check_warn "GRAFANA_PASSWORD: Non défini (devrait être dans .env)"
    fi

    # Namespace
    if [ -n "$MONITORING_NAMESPACE" ]; then
        validate_hostname "$MONITORING_NAMESPACE" "MONITORING_NAMESPACE"
    else
        check_warn "MONITORING_NAMESPACE: Non défini"
    fi
}

# Validation timeouts
validate_timeouts() {
    echo ""
    echo -e "${CYAN}[12/12] Validation timeouts${NC}"
    echo ""

    # Fonction pour valider un timeout (format: XXXs)
    validate_timeout_value() {
        local timeout=$1
        local name=$2

        if [[ $timeout =~ ^([0-9]+)s$ ]]; then
            local seconds="${BASH_REMATCH[1]}"
            if [ "$seconds" -lt 30 ]; then
                check_warn "$name: Très court ($timeout, minimum recommandé: 30s)"
            elif [ "$seconds" -gt 900 ]; then
                check_warn "$name: Très long ($timeout, maximum recommandé: 900s)"
            else
                check_ok "$name: $timeout"
            fi
        else
            check_error "$name: Format invalide '$timeout' (format: XXXs, ex: 300s)"
        fi
    }

    validate_timeout_value "$KUBECTL_WAIT_TIMEOUT" "KUBECTL_WAIT_TIMEOUT"
    validate_timeout_value "$KUBECTL_WAIT_TIMEOUT_SHORT" "KUBECTL_WAIT_TIMEOUT_SHORT"
    validate_timeout_value "$KUBECTL_WAIT_TIMEOUT_QUICK" "KUBECTL_WAIT_TIMEOUT_QUICK"
    validate_timeout_value "$KUBECTL_WAIT_TIMEOUT_CRITICAL" "KUBECTL_WAIT_TIMEOUT_CRITICAL"
}

################################################################################
# MAIN
################################################################################

# Parser les arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --fix)
            FIX_MODE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
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

# Charger config.sh
if [ ! -f "$SCRIPT_DIR/../config.sh" ]; then
    echo -e "${RED}Erreur: config.sh introuvable dans $SCRIPT_DIR${NC}"
    exit 1
fi

source "$SCRIPT_DIR/../config.sh"

# Header
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Validation de Configuration Kubernetes HA${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"

# Exécuter toutes les validations
validate_domain
validate_vip
validate_masters
validate_workers
validate_cluster_network
validate_metallb
validate_keepalived
validate_kubernetes
validate_network_overlaps
validate_rancher
validate_monitoring
validate_timeouts

# Résumé
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Résumé de la validation${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

echo "  Vérifications: $CHECKS"
echo -e "  ${RED}Erreurs:${NC}       $ERRORS"
echo -e "  ${YELLOW}Avertissements:${NC} $WARNINGS"

echo ""

# Calcul du score de confiance
local success=$((CHECKS - ERRORS - WARNINGS))
local score=$((success * 100 / CHECKS))

if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "${GREEN}✓ CONFIGURATION VALIDE${NC}"
    echo -e "${GREEN}Score de confiance: $score%${NC}"
    echo ""
    echo -e "${BLUE}La configuration est prête pour l'installation${NC}"
    exit 0
elif [ "$ERRORS" -eq 0 ]; then
    echo -e "${YELLOW}⚠ CONFIGURATION ACCEPTABLE${NC}"
    echo -e "${YELLOW}Score de confiance: $score%${NC}"
    echo ""
    echo -e "${BLUE}L'installation peut continuer avec des avertissements${NC}"
    echo -e "${YELLOW}Recommandé: Corrigez les avertissements pour une meilleure fiabilité${NC}"
    exit 0
else
    echo -e "${RED}✗ CONFIGURATION INVALIDE${NC}"
    echo -e "${RED}Score de confiance: $score%${NC}"
    echo ""
    echo -e "${RED}Veuillez corriger les erreurs dans config.sh avant de continuer${NC}"
    echo ""
    echo -e "${YELLOW}Actions recommandées:${NC}"
    echo "  1. Éditez config.sh: nano $SCRIPT_DIR/config.sh"
    echo "  2. Corrigez les erreurs listées ci-dessus"
    echo "  3. Re-validez: $0"
    exit 1
fi
