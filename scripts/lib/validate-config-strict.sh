#!/bin/bash
################################################################################
# Validation Stricte de Configuration Kubernetes HA
# Détection d'erreurs avant déploiement
# Auteur: Claude Code
# Version: 1.0
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# FONCTION: Valider VIP non dupliquée avec IPs de nœuds
# ============================================================================

validate_vip_not_in_nodes() {
    local vip="$1"
    local error=0

    echo -e "${BLUE}Vérification VIP unique...${NC}"

    # Vérifier VIP != masters
    for i in {1..10}; do
        local var="MASTER${i}_IP"
        local ip="${!var:-}"
        if [ -n "$ip" ] && [ "$ip" = "$vip" ]; then
            echo -e "${RED}✗ VIP ($vip) identique à MASTER${i}_IP ($ip)${NC}"
            ((error++))
        fi
    done

    # Vérifier VIP != workers
    for i in {1..20}; do
        local var="WORKER${i}_IP"
        local ip="${!var:-}"
        if [ -n "$ip" ] && [ "$ip" = "$vip" ]; then
            echo -e "${RED}✗ VIP ($vip) identique à WORKER${i}_IP ($ip)${NC}"
            ((error++))
        fi
    done

    if [ $error -eq 0 ]; then
        echo -e "${GREEN}✓ VIP unique et disponible${NC}"
        return 0
    else
        return 1
    fi
}

# ============================================================================
# FONCTION: Valider pas de chevauchement réseaux
# ============================================================================

validate_network_overlap() {
    local pod_network="$1"
    local service_subnet="$2"
    local cluster_network="$3"
    local error=0

    echo -e "${BLUE}Vérification chevauchement réseaux...${NC}"

    # Extraire les parts en réseau (très simplifié)
    local pod_prefix=$(echo "$pod_network" | cut -d'.' -f1-2)
    local service_prefix=$(echo "$service_subnet" | cut -d'.' -f1-2)
    local cluster_prefix=$(echo "$cluster_network" | cut -d'.' -f1-2)

    if [ "$pod_prefix" = "$service_prefix" ]; then
        echo -e "${RED}✗ Chevauchement: POD_NETWORK ($pod_network) et SERVICE_SUBNET ($service_subnet)${NC}"
        ((error++))
    fi

    if [ "$pod_prefix" = "$cluster_prefix" ]; then
        echo -e "${RED}✗ Chevauchement: POD_NETWORK ($pod_network) et CLUSTER_NODES_NETWORK ($cluster_network)${NC}"
        ((error++))
    fi

    if [ "$service_prefix" = "$cluster_prefix" ]; then
        echo -e "${RED}✗ Chevauchement: SERVICE_SUBNET ($service_subnet) et CLUSTER_NODES_NETWORK ($cluster_network)${NC}"
        ((error++))
    fi

    if [ $error -eq 0 ]; then
        echo -e "${GREEN}✓ Aucun chevauchement réseau détecté${NC}"
        return 0
    else
        return 1
    fi
}

# ============================================================================
# FONCTION: Valider hostnames uniques
# ============================================================================

validate_hostnames_unique() {
    local error=0
    local -a hostnames=()

    echo -e "${BLUE}Vérification unicité hostnames...${NC}"

    # Collecter tous les hostnames
    for i in {1..10}; do
        local var="MASTER${i}_HOSTNAME"
        local hostname="${!var:-}"
        if [ -n "$hostname" ]; then
            hostnames+=("$hostname")
        fi
    done

    for i in {1..20}; do
        local var="WORKER${i}_HOSTNAME"
        local hostname="${!var:-}"
        if [ -n "$hostname" ]; then
            hostnames+=("$hostname")
        fi
    done

    # Vérifier unicité
    local sorted_hostnames=($(printf '%s\n' "${hostnames[@]}" | sort))
    for ((i=0; i<${#sorted_hostnames[@]}-1; i++)); do
        if [ "${sorted_hostnames[$i]}" = "${sorted_hostnames[$((i+1))]}" ]; then
            echo -e "${RED}✗ Hostname dupliqué: ${sorted_hostnames[$i]}${NC}"
            ((error++))
        fi
    done

    if [ $error -eq 0 ]; then
        echo -e "${GREEN}✓ Tous les hostnames sont uniques${NC}"
        return 0
    else
        return 1
    fi
}

# ============================================================================
# FONCTION: Valider priorités keepalived
# ============================================================================

validate_keepalived_priorities() {
    local error=0
    local -a priorities=()

    echo -e "${BLUE}Vérification priorités keepalived...${NC}"

    # Collecter les priorités
    for i in {1..10}; do
        local var="MASTER${i}_PRIORITY"
        local priority="${!var:-}"
        if [ -n "$priority" ]; then
            priorities+=("$priority")

            # Vérifier entre 1 et 255
            if [ "$priority" -lt 1 ] || [ "$priority" -gt 255 ]; then
                echo -e "${RED}✗ MASTER${i}_PRIORITY ($priority) hors limites (1-255)${NC}"
                ((error++))
            fi
        fi
    done

    # Vérifier qu'elles sont en ordre décroissant
    local prev_priority=256
    for i in {1..10}; do
        local var="MASTER${i}_PRIORITY"
        local priority="${!var:-}"
        if [ -n "$priority" ]; then
            if [ "$priority" -ge "$prev_priority" ]; then
                echo -e "${YELLOW}⚠ MASTER${i}_PRIORITY ($priority) >= MASTER$((i-1))_PRIORITY ($prev_priority)${NC}"
                echo -e "${YELLOW}  → Les priorités doivent être décroissantes${NC}"
            fi
            prev_priority=$priority
        fi
    done

    if [ $error -eq 0 ]; then
        echo -e "${GREEN}✓ Priorités keepalived valides${NC}"
        return 0
    else
        return 1
    fi
}

# ============================================================================
# FONCTION: Valider force des mots de passe
# ============================================================================

validate_password_strength() {
    local vrrp_password="${1:-}"
    local rancher_password="${2:-}"
    local grafana_password="${3:-}"
    local error=0

    echo -e "${BLUE}Vérification force des mots de passe...${NC}"

    # VRRP: max 8 caractères (limite keepalived)
    if [ -n "$vrrp_password" ]; then
        if [ ${#vrrp_password} -gt 8 ]; then
            echo -e "${RED}✗ VRRP_PASSWORD: ${#vrrp_password} caractères (max 8)${NC}"
            ((error++))
        elif [ ${#vrrp_password} -lt 4 ]; then
            echo -e "${RED}✗ VRRP_PASSWORD: trop court (${#vrrp_password} caractères, min 4)${NC}"
            ((error++))
        else
            echo -e "${GREEN}✓ VRRP_PASSWORD correct${NC}"
        fi
    fi

    # Autres: min 12 caractères
    if [ -n "$rancher_password" ]; then
        if [ ${#rancher_password} -lt 12 ]; then
            echo -e "${RED}✗ RANCHER_PASSWORD: trop court (${#rancher_password} caractères, min 12)${NC}"
            ((error++))
        else
            echo -e "${GREEN}✓ RANCHER_PASSWORD correct${NC}"
        fi
    fi

    if [ -n "$grafana_password" ]; then
        if [ ${#grafana_password} -lt 12 ]; then
            echo -e "${RED}✗ GRAFANA_PASSWORD: trop court (${#grafana_password} caractères, min 12)${NC}"
            ((error++))
        else
            echo -e "${GREEN}✓ GRAFANA_PASSWORD correct${NC}"
        fi
    fi

    return $error
}

# ============================================================================
# FONCTION: Valider IPs en format correct
# ============================================================================

validate_ip_format() {
    local ip="$1"
    local name="$2"

    if [[ ! $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo -e "${RED}✗ Format IP invalide: $name = $ip${NC}"
        return 1
    fi

    # Vérifier chaque octet
    IFS='.' read -ra octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if [ "$octet" -lt 0 ] || [ "$octet" -gt 255 ]; then
            echo -e "${RED}✗ IP invalide: $name = $ip (octet $octet > 255)${NC}"
            return 1
        fi
    done

    return 0
}

# ============================================================================
# FONCTION: Validation complète
# ============================================================================

validate_config_strict() {
    local config_file="${1:-.}"
    local total_errors=0

    echo -e "${YELLOW}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  VALIDATION STRICTE - Configuration Kubernetes HA     ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Valider VIP unique
    validate_vip_not_in_nodes "$VIP" || ((total_errors++))
    echo ""

    # Valider réseaux sans chevauchement
    validate_network_overlap "$POD_NETWORK" "$SERVICE_SUBNET" "$CLUSTER_NODES_NETWORK" || ((total_errors++))
    echo ""

    # Valider hostnames uniques
    validate_hostnames_unique || ((total_errors++))
    echo ""

    # Valider priorités keepalived
    validate_keepalived_priorities || ((total_errors++))
    echo ""

    # Valider force mots de passe
    validate_password_strength "$VRRP_PASSWORD" "$RANCHER_PASSWORD" "$GRAFANA_PASSWORD" || ((total_errors++))
    echo ""

    # Valider IPs format
    for i in {1..10}; do
        local master_ip_var="MASTER${i}_IP"
        local master_ip="${!master_ip_var:-}"
        if [ -n "$master_ip" ]; then
            validate_ip_format "$master_ip" "MASTER${i}_IP" || ((total_errors++))
        fi
    done
    echo ""

    # Résumé
    echo -e "${YELLOW}════════════════════════════════════════════════════════${NC}"
    if [ $total_errors -eq 0 ]; then
        echo -e "${GREEN}✓ Configuration VALIDE - Pas d'erreurs détectées${NC}"
        echo -e "${YELLOW}════════════════════════════════════════════════════════${NC}"
        return 0
    else
        echo -e "${RED}✗ Configuration INVALIDE - $total_errors erreur(s) détectée(s)${NC}"
        echo -e "${YELLOW}════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${YELLOW}Veuillez corriger les erreurs dans config.sh et relancer${NC}"
        return 1
    fi
}

# ============================================================================
# EXPORT FUNCTIONS
# ============================================================================

export -f validate_vip_not_in_nodes
export -f validate_network_overlap
export -f validate_hostnames_unique
export -f validate_keepalived_priorities
export -f validate_password_strength
export -f validate_ip_format
export -f validate_config_strict

echo -e "${GREEN}✓ Strict validation library loaded${NC}"
