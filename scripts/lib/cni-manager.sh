#!/bin/bash
################################################################################
# CNI Manager - Abstraction pour gestion Calico/Cilium
# Permet sélection flexible du plugin réseau
# Auteur: Claude Code
# Version: 1.0
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================================
# VARIABLES CNI
# ============================================================================

# CNI par défaut (peut être overridé par config)
CNI_TYPE="${CNI_TYPE:-calico}"
CALICO_VERSION="${CALICO_VERSION:-latest}"
CILIUM_VERSION="${CILIUM_VERSION:-latest}"

# ============================================================================
# FONCTION: Afficher options CNI
# ============================================================================

show_cni_options() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Choix du Plugin Réseau (CNI)${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}1) CALICO${NC}"
    echo -e "   ${GREEN}✓ BGP Layer 3 routing${NC}"
    echo "   • Simple et bien compris"
    echo "   • Ressources: ultra-léger (50-200MB par nœud)"
    echo "   • Performance: 100Gbps native"
    echo "   • Recommandé pour: on-premises, clusters < 1000 nœuds"
    echo ""
    echo -e "${CYAN}2) CILIUM${NC}"
    echo -e "   ${GREEN}✓ eBPF kernel-level networking${NC}"
    echo "   • Moderne et performant"
    echo "   • L7 policies (HTTP/DNS/gRPC)"
    echo "   • Hubble: observabilité complète"
    echo "   • Recommandé pour: sécurité stricte, clusters massifs"
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

# ============================================================================
# FONCTION: Sélectionner CNI interactivement
# ============================================================================

select_cni_interactive() {
    show_cni_options

    read -p "Choisir CNI (1=Calico, 2=Cilium) [1]: " cni_choice
    cni_choice=${cni_choice:-1}

    case $cni_choice in
        1)
            CNI_TYPE="calico"
            echo -e "${GREEN}✓ Calico sélectionné${NC}"
            ;;
        2)
            CNI_TYPE="cilium"
            echo -e "${GREEN}✓ Cilium sélectionné${NC}"
            ;;
        *)
            echo -e "${YELLOW}Choix invalide - Calico par défaut${NC}"
            CNI_TYPE="calico"
            ;;
    esac

    echo ""
}

# ============================================================================
# FONCTION: Valider CNI type
# ============================================================================

validate_cni_type() {
    local cni="$1"

    case "$cni" in
        calico|cilium)
            return 0
            ;;
        *)
            echo -e "${RED}✗ CNI inconnu: $cni${NC}"
            echo -e "${YELLOW}Options valides: calico, cilium${NC}"
            return 1
            ;;
    esac
}

# ============================================================================
# FONCTION: Obtenir script d'installation
# ============================================================================

get_cni_install_script() {
    local cni="$1"

    case "$cni" in
        calico)
            echo "install-calico.sh"
            ;;
        cilium)
            echo "install-cilium.sh"
            ;;
        *)
            return 1
            ;;
    esac
}

# ============================================================================
# FONCTION: Afficher informations CNI
# ============================================================================

show_cni_info() {
    local cni="$1"

    echo -e "${BLUE}Informations CNI sélectionné: ${CYAN}$(echo $cni | tr '[:lower:]' '[:upper:]')${NC}"
    echo ""

    case "$cni" in
        calico)
            echo -e "${GREEN}✓ CALICO - BGP Layer 3 Routing${NC}"
            echo ""
            echo "Architecture:"
            echo "  • Felix agent configures routing"
            echo "  • BIRD BGP speaker announces routes"
            echo "  • Direct IP routing between pods"
            echo ""
            echo "Caractéristiques:"
            echo "  ✓ Simple et léger"
            echo "  ✓ BGP standard (networking connu)"
            echo "  ✓ Très léger: 50-200MB CPU par nœud"
            echo "  ✓ Excellent performance: 100Gbps native"
            echo "  ✓ Network policies L3/L4"
            echo "  ✗ Pas d'inspection L7"
            echo "  ✗ Pas de service mesh"
            echo ""
            echo "Recommandé pour:"
            echo "  • Infrastructure on-premises"
            echo "  • Clusters < 1000 nœuds"
            echo "  • Budget limité en ressources"
            echo "  • Équipes avec expertise BGP"
            ;;

        cilium)
            echo -e "${GREEN}✓ CILIUM - eBPF Kernel Networking${NC}"
            echo ""
            echo "Architecture:"
            echo "  • Cilium agent loads eBPF programs"
            echo "  • Kernel TC hooks for interception"
            echo "  • Direct kernel-level processing"
            echo "  • Ultra-fast networking + security"
            echo ""
            echo "Caractéristiques:"
            echo "  ✓ eBPF kernel-level (très rapide)"
            echo "  ✓ L7 policies (HTTP, DNS, gRPC)"
            echo "  ✓ Hubble observabilité complète"
            echo "  ✓ Service mesh integration (Istio)"
            echo "  ✓ Zero-trust security"
            echo "  ✓ Scalable à 5000+ nœuds"
            echo "  ✗ Kernel >= 5.8 requis"
            echo "  ✗ Plus complexe à comprendre"
            echo ""
            echo "Recommandé pour:"
            echo "  • Sécurité stricte requise"
            echo "  • Inspection L7 nécessaire"
            echo "  • Service mesh Istio planned"
            echo "  • Clusters très grands (> 5000 nœuds)"
            echo "  • Observabilité critique"
            ;;
    esac

    echo ""
}

# ============================================================================
# FONCTION: Résumer configuration CNI
# ============================================================================

cni_summary() {
    local cni="$1"

    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  Configuration CNI${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Plugin: ${CYAN}$(echo $cni | tr '[:lower:]' '[:upper:]')${NC}"

    case "$cni" in
        calico)
            echo -e "  Version: ${CYAN}${CALICO_VERSION}${NC}"
            echo -e "  Performance: ${GREEN}100Gbps native routing${NC}"
            echo -e "  Ressources: ${GREEN}Ultra-léger (50-200MB/nœud)${NC}"
            echo -e "  L7 Policies: ${RED}Non${NC}"
            echo -e "  Observabilité: ${YELLOW}Basique${NC}"
            ;;
        cilium)
            echo -e "  Version: ${CYAN}${CILIUM_VERSION}${NC}"
            echo -e "  Performance: ${GREEN}eBPF kernel-level${NC}"
            echo -e "  Ressources: ${GREEN}Léger (100-400MB/nœud)${NC}"
            echo -e "  L7 Policies: ${GREEN}Oui (HTTP/DNS/gRPC)${NC}"
            echo -e "  Observabilité: ${GREEN}Hubble (excellente)${NC}"
            ;;
    esac

    echo ""
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ============================================================================
# FONCTION: Installer CNI
# ============================================================================

install_cni() {
    local cni="$1"
    local script_dir="$2"

    if ! validate_cni_type "$cni"; then
        return 1
    fi

    local install_script=$(get_cni_install_script "$cni")
    local script_path="$script_dir/$install_script"

    if [ ! -f "$script_path" ]; then
        echo -e "${RED}✗ Script d'installation non trouvé: $script_path${NC}"
        return 1
    fi

    echo -e "${YELLOW}Installation de $(echo $cni | tr '[:lower:]' '[:upper:]')...${NC}"
    echo ""

    bash "$script_path"

    return $?
}

# ============================================================================
# EXPORT FUNCTIONS
# ============================================================================

export -f show_cni_options
export -f select_cni_interactive
export -f validate_cni_type
export -f get_cni_install_script
export -f show_cni_info
export -f cni_summary
export -f install_cni

echo -e "${GREEN}✓ CNI manager library loaded${NC}"
