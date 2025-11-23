#!/bin/bash
################################################################################
# Librairie centralisée pour gestion des règles firewall Kubernetes
# Élimine la duplication de règles entre master-setup.sh et worker-setup.sh
# Auteur: azurtech56
# Version: 1.0
################################################################################

# Source les constantes si disponible
if [ -z "$RED" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
fi

# ============================================================================
# FONCTION: Configuration du firewall pour les Masters
# ============================================================================
configure_master_firewall() {
    local pod_network="${1:-11.0.0.0/16}"
    local cluster_network="${2:-192.168.0.0/24}"

    echo -e "${BLUE}Configuration des règles firewall Master...${NC}"

    # Ports SSH et HTTP/HTTPS
    local basic_ports=(
        "22:tcp:SSH"
        "80:tcp:HTTP"
        "443:tcp:HTTPS"
    )

    # Ports Kubernetes API
    local k8s_ports=(
        "6443:tcp:Kubernetes API Server"
        "10250:tcp:Kubelet API"
        "10251:tcp:Kubernetes Scheduler"
        "10252:tcp:Kubernetes Controller Manager"
    )

    # Ports etcd (pour HA avec etcd externe)
    local etcd_ports=(
        "2379:tcp:etcd Client API"
        "2380:tcp:etcd Peer Communication"
    )

    # Ports monitoring optionnels
    local monitoring_ports=(
        "9090:tcp:Prometheus"
        "9100:tcp:Node Exporter"
    )

    # Ajouter tous les ports
    for port_rule in "${basic_ports[@]}" "${k8s_ports[@]}" "${etcd_ports[@]}" "${monitoring_ports[@]}"; do
        IFS=':' read -r port proto desc <<< "$port_rule"
        if type -t setup_ufw_rule_idempotent &>/dev/null; then
            setup_ufw_rule_idempotent "$port" "$proto" "$desc"
        else
            ufw allow "$port/$proto" 2>/dev/null || true
        fi
    done

    # Autoriser trafic depuis réseau cluster
    if type -t setup_ufw_network_rule_idempotent &>/dev/null; then
        setup_ufw_network_rule_idempotent "$cluster_network" "Cluster Nodes"
    else
        ufw allow from "$cluster_network" 2>/dev/null || true
    fi

    # Autoriser trafic entre pods
    if type -t setup_ufw_network_rule_idempotent &>/dev/null; then
        setup_ufw_network_rule_idempotent "$pod_network" "Pod Network"
    else
        ufw allow from "$pod_network" 2>/dev/null || true
    fi

    echo -e "${GREEN}✓ Règles firewall Master configurées${NC}"
}

# ============================================================================
# FONCTION: Configuration du firewall pour les Workers
# ============================================================================
configure_worker_firewall() {
    local pod_network="${1:-11.0.0.0/16}"
    local cluster_network="${2:-192.168.0.0/24}"

    echo -e "${BLUE}Configuration des règles firewall Worker...${NC}"

    # Ports SSH et HTTP/HTTPS
    local basic_ports=(
        "22:tcp:SSH"
        "80:tcp:HTTP"
        "443:tcp:HTTPS"
    )

    # Ports Kubernetes
    local k8s_ports=(
        "10250:tcp:Kubelet API"
        "10256:tcp:Kubernetes Proxy"
    )

    # Ports NodePort (30000-32767)
    local nodeport_rule="30000:32767:tcp:NodePort Range"

    # Ports monitoring optionnels
    local monitoring_ports=(
        "9100:tcp:Node Exporter"
    )

    # Ajouter tous les ports
    for port_rule in "${basic_ports[@]}" "${k8s_ports[@]}" "${monitoring_ports[@]}"; do
        IFS=':' read -r port proto desc <<< "$port_rule"
        if type -t setup_ufw_rule_idempotent &>/dev/null; then
            setup_ufw_rule_idempotent "$port" "$proto" "$desc"
        else
            ufw allow "$port/$proto" 2>/dev/null || true
        fi
    done

    # NodePort range
    IFS=':' read -r port_range proto desc <<< "$nodeport_rule"
    if type -t setup_ufw_rule_idempotent &>/dev/null; then
        setup_ufw_rule_idempotent "$port_range" "$proto" "$desc"
    else
        ufw allow "$port_range/$proto" 2>/dev/null || true
    fi

    # Autoriser trafic depuis réseau cluster
    if type -t setup_ufw_network_rule_idempotent &>/dev/null; then
        setup_ufw_network_rule_idempotent "$cluster_network" "Cluster Nodes"
    else
        ufw allow from "$cluster_network" 2>/dev/null || true
    fi

    # Autoriser trafic entre pods
    if type -t setup_ufw_network_rule_idempotent &>/dev/null; then
        setup_ufw_network_rule_idempotent "$pod_network" "Pod Network"
    else
        ufw allow from "$pod_network" 2>/dev/null || true
    fi

    echo -e "${GREEN}✓ Règles firewall Worker configurées${NC}"
}

# ============================================================================
# FONCTION: Configuration du firewall pour keepalived (VRRP)
# ============================================================================
configure_keepalived_firewall() {
    echo -e "${BLUE}Configuration des règles firewall keepalived...${NC}"

    # Port VRRP (112)
    if type -t setup_ufw_vrrp_idempotent &>/dev/null; then
        setup_ufw_vrrp_idempotent
    else
        ufw allow 112/tcp 2>/dev/null || true
        ufw allow 112/udp 2>/dev/null || true
    fi

    echo -e "${GREEN}✓ Règles firewall keepalived configurées${NC}"
}

# ============================================================================
# FONCTION: Activer le firewall
# ============================================================================
enable_firewall() {
    echo -e "${BLUE}Activation du firewall...${NC}"

    if type -t enable_ufw_idempotent &>/dev/null; then
        enable_ufw_idempotent
    else
        ufw --force enable 2>/dev/null || true
    fi

    echo -e "${GREEN}✓ Firewall activé${NC}"
}

# ============================================================================
# FONCTION: Afficher les règles firewall actives
# ============================================================================
show_firewall_rules() {
    echo ""
    echo -e "${BLUE}═══ Règles Firewall Actives ═══${NC}"
    ufw status numbered || echo "UFW non actif"
    echo ""
}

# ============================================================================
# FONCTION: Vérifier si firewall est disponible
# ============================================================================
is_firewall_available() {
    if command -v ufw &> /dev/null; then
        return 0
    fi
    return 1
}

# Export des fonctions
export -f configure_master_firewall
export -f configure_worker_firewall
export -f configure_keepalived_firewall
export -f enable_firewall
export -f show_firewall_rules
export -f is_firewall_available
