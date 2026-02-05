#!/bin/bash
################################################################################
# Script de validation des prérequis pour Kubernetes HA
# Vérifie les ressources, la connectivité, les ports, etc.
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

ERRORS=0
WARNINGS=0

# Charger la configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../config.sh" ]; then
    source "$SCRIPT_DIR/../config.sh" 2>/dev/null || true
fi

# Déterminer le type de nœud
NODE_TYPE="${1:-auto}"  # master, worker, ou auto

################################################################################
# FONCTIONS
################################################################################

show_usage() {
    cat <<EOF
${CYAN}════════════════════════════════════════════════════════════════${NC}
  Vérification des Prérequis Kubernetes HA
${CYAN}════════════════════════════════════════════════════════════════${NC}

${YELLOW}Usage:${NC}
  $0 [type]

${YELLOW}Arguments:${NC}
  type    Type de nœud: master, worker, auto (défaut: auto)

${YELLOW}Exemples:${NC}
  $0              # Vérification automatique
  $0 master       # Vérification pour un nœud master
  $0 worker       # Vérification pour un nœud worker

${CYAN}════════════════════════════════════════════════════════════════${NC}
EOF
}

check_success() {
    echo -e "${GREEN}✓${NC} $1"
}

check_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

check_error() {
    echo -e "${RED}✗${NC} $1"
    ((ERRORS++))
}

check_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

################################################################################
# DÉBUT DES VÉRIFICATIONS
################################################################################

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Vérification des Prérequis Kubernetes HA${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Type de nœud : ${NODE_TYPE}${NC}"
echo ""

# 1. RESSOURCES MATÉRIELLES
echo -e "${CYAN}[1/9] Ressources matérielles${NC}"
echo ""

# RAM
total_ram=$(free -m | awk '/^Mem:/{print $2}')
if [ "$total_ram" -lt 2048 ]; then
    check_error "RAM insuffisante : ${total_ram} Mo (minimum 2048 Mo requis)"
elif [ "$total_ram" -lt 4096 ]; then
    check_warning "RAM limitée : ${total_ram} Mo (4096 Mo recommandé pour production)"
else
    check_success "RAM : ${total_ram} Mo"
fi

# CPU
cpu_count=$(nproc)
if [ "$cpu_count" -lt 2 ]; then
    check_error "CPU insuffisant : ${cpu_count} cœur(s) (minimum 2 cœurs requis)"
elif [ "$cpu_count" -lt 4 ]; then
    check_warning "CPU limité : ${cpu_count} cœurs (4 cœurs recommandé pour production)"
else
    check_success "CPU : ${cpu_count} cœurs"
fi

# Espace disque /
disk_free=$(df / | awk 'NR==2 {print int($4/1024)}')  # En Mo
if [ "$disk_free" -lt 10240 ]; then
    check_error "Espace disque / insuffisant : ${disk_free} Mo (minimum 10 Go requis)"
elif [ "$disk_free" -lt 20480 ]; then
    check_warning "Espace disque / limité : ${disk_free} Mo (20 Go recommandé)"
else
    check_success "Espace disque / : ${disk_free} Mo"
fi

# Espace disque /var
disk_var=$(df /var | awk 'NR==2 {print int($4/1024)}')
if [ "$disk_var" -lt 10240 ]; then
    check_error "Espace disque /var insuffisant : ${disk_var} Mo (minimum 10 Go requis)"
elif [ "$disk_var" -lt 20480 ]; then
    check_warning "Espace disque /var limité : ${disk_var} Mo (20 Go recommandé)"
else
    check_success "Espace disque /var : ${disk_var} Mo"
fi

echo ""

# 2. SYSTÈME D'EXPLOITATION
echo -e "${CYAN}[2/9] Système d'exploitation${NC}"
echo ""

if [ -f /etc/os-release ]; then
    source /etc/os-release

    case "$ID" in
        ubuntu)
            if [[ "$VERSION_ID" =~ ^(20.04|22.04|24.04)$ ]]; then
                check_success "Distribution : Ubuntu $VERSION_ID"
            else
                check_warning "Version Ubuntu non testée : $VERSION_ID (testées: 20.04, 22.04, 24.04)"
            fi
            ;;
        debian)
            if [[ "$VERSION_ID" =~ ^(11|12|13)$ ]]; then
                check_success "Distribution : Debian $VERSION_ID"
            else
                check_warning "Version Debian non testée : $VERSION_ID (testées: 11, 12, 13)"
            fi
            ;;
        *)
            check_error "Distribution non supportée : $ID $VERSION_ID"
            check_info "Distributions supportées : Ubuntu 20.04/22.04/24.04, Debian 11/12/13"
            ;;
    esac
else
    check_error "Impossible de détecter la distribution (/etc/os-release manquant)"
fi

# Architecture
arch=$(uname -m)
if [ "$arch" = "x86_64" ]; then
    check_success "Architecture : $arch"
elif [ "$arch" = "aarch64" ]; then
    check_info "Architecture ARM64 détectée : $arch (support expérimental)"
else
    check_warning "Architecture non standard : $arch"
fi

# Version du kernel
kernel_version=$(uname -r)
kernel_major=$(echo $kernel_version | cut -d. -f1)
kernel_minor=$(echo $kernel_version | cut -d. -f2)

if [ "$kernel_major" -lt 4 ] || ([ "$kernel_major" -eq 4 ] && [ "$kernel_minor" -lt 15 ]); then
    check_warning "Kernel ancien : $kernel_version (4.15+ recommandé)"
else
    check_success "Kernel : $kernel_version"
fi

echo ""

# 3. CONNECTIVITÉ RÉSEAU
echo -e "${CYAN}[3/9] Connectivité réseau${NC}"
echo ""

# DNS
if timeout 5 nslookup google.com > /dev/null 2>&1; then
    check_success "Résolution DNS opérationnelle"
else
    check_error "Résolution DNS échouée (vérifiez /etc/resolv.conf)"
fi

# Kubernetes repo
if timeout 5 curl -s https://pkgs.k8s.io > /dev/null 2>&1; then
    check_success "Accès à pkgs.k8s.io (repository Kubernetes)"
else
    check_error "Impossible de joindre pkgs.k8s.io (requis pour installation)"
fi

# GitHub (Calico, MetalLB)
if timeout 5 curl -s https://github.com > /dev/null 2>&1; then
    check_success "Accès à github.com (manifests Calico/MetalLB)"
else
    check_warning "Impossible de joindre github.com (requis pour Calico/MetalLB)"
fi

# Docker Hub (pour images containerd)
if timeout 5 curl -s https://registry-1.docker.io > /dev/null 2>&1; then
    check_success "Accès à Docker Hub (images de conteneurs)"
else
    check_warning "Impossible de joindre Docker Hub"
fi

# Test de latence réseau (important pour etcd)
if ping -c 3 8.8.8.8 > /dev/null 2>&1; then
    ping_time=$(ping -c 3 8.8.8.8 | tail -1 | awk '{print $4}' | cut -d '/' -f 2)
    if (( $(echo "$ping_time > 100" | bc -l 2>/dev/null || echo 0) )); then
        check_warning "Latence réseau élevée : ${ping_time}ms (peut impacter etcd)"
    else
        check_success "Latence réseau : ${ping_time}ms"
    fi
else
    check_warning "Impossible de tester la latence réseau"
fi

echo ""

# 4. PORTS DISPONIBLES
echo -e "${CYAN}[4/9] Ports disponibles${NC}"
echo ""

check_port() {
    local port=$1
    local service=$2

    if ss -tunlp 2>/dev/null | grep -q ":$port "; then
        local process=$(ss -tunlp 2>/dev/null | grep ":$port " | awk '{print $7}' | head -1)
        check_error "Port $port occupé par $process ($service)"
        return 1
    else
        check_success "Port $port libre ($service)"
        return 0
    fi
}

# Ports selon le type de nœud
if [ "$NODE_TYPE" = "master" ] || [ "$NODE_TYPE" = "auto" ]; then
    check_port 6443 "Kubernetes API Server"
    check_port 2379 "etcd client"
    check_port 2380 "etcd peer"
    check_port 10250 "kubelet API"
    check_port 10251 "kube-scheduler"
    check_port 10252 "kube-controller-manager"
fi

if [ "$NODE_TYPE" = "worker" ] || [ "$NODE_TYPE" = "auto" ]; then
    check_port 10250 "kubelet API"
fi

echo ""

# 5. CONFIGURATION RÉSEAU
echo -e "${CYAN}[5/9] Configuration réseau${NC}"
echo ""

# Hostname
current_hostname=$(hostname)
if [ -n "$current_hostname" ]; then
    check_success "Hostname : $current_hostname"
else
    check_error "Hostname non configuré"
fi

# Interface réseau principale
main_iface=$(ip route | grep default | awk '{print $5}' | head -n1)
if [ -n "$main_iface" ]; then
    check_success "Interface principale : $main_iface"

    # Obtenir l'IP de l'interface principale
    main_ip=$(ip addr show $main_iface | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
    if [ -n "$main_ip" ]; then
        check_info "IP principale : $main_ip"
    fi
else
    check_warning "Interface réseau par défaut introuvable"
fi

# Vérifier /etc/hosts
if [ -f /etc/hosts ]; then
    if grep -q "127.0.1.1\|127.0.0.1" /etc/hosts; then
        check_success "Fichier /etc/hosts présent"
    else
        check_warning "/etc/hosts incomplet"
    fi
else
    check_error "/etc/hosts manquant"
fi

# Vérifier la configuration swap (doit être désactivé pour Kubernetes)
swap_status=$(swapon --show 2>/dev/null)
if [ -z "$swap_status" ]; then
    check_success "Swap désactivé (requis pour Kubernetes)"
else
    check_warning "Swap actif (sera désactivé lors de l'installation)"
fi

echo ""

# 6. PARE-FEU
echo -e "${CYAN}[6/9] Pare-feu${NC}"
echo ""

# UFW
if command -v ufw &> /dev/null; then
    ufw_status=$(ufw status 2>/dev/null | head -1)
    if echo "$ufw_status" | grep -q "inactive"; then
        check_info "UFW installé mais inactif (sera configuré lors de l'installation)"
    elif echo "$ufw_status" | grep -q "active"; then
        check_info "UFW actif (vérifiez que les ports nécessaires sont ouverts)"
    else
        check_success "UFW installé"
    fi
else
    check_info "UFW non installé (sera installé lors de l'installation)"
fi

# iptables
if command -v iptables &> /dev/null; then
    iptables_rules=$(iptables -L 2>/dev/null | wc -l)
    if [ "$iptables_rules" -gt 20 ]; then
        check_warning "iptables contient des règles personnalisées ($iptables_rules lignes)"
        check_info "Assurez-vous qu'elles ne bloquent pas Kubernetes"
    else
        check_success "iptables disponible"
    fi
else
    check_error "iptables non disponible (requis pour Kubernetes)"
fi

echo ""

# 7. PERMISSIONS ET PRIVILÈGES
echo -e "${CYAN}[7/9] Permissions et privilèges${NC}"
echo ""

# Root
if [[ $EUID -eq 0 ]]; then
    check_success "Exécution en tant que root"
else
    check_error "Doit être exécuté en tant que root (utilisez sudo)"
fi

# systemd
if pidof systemd &> /dev/null; then
    systemd_version=$(systemctl --version | head -1 | awk '{print $2}')
    check_success "systemd actif (version $systemd_version)"
else
    check_error "systemd non détecté (requis pour Kubernetes)"
fi

# SELinux (si présent)
if command -v getenforce &> /dev/null; then
    selinux_status=$(getenforce)
    if [ "$selinux_status" = "Disabled" ]; then
        check_success "SELinux désactivé"
    else
        check_warning "SELinux actif ($selinux_status) - peut causer des problèmes"
    fi
fi

# AppArmor (normal sur Ubuntu)
if systemctl is-active apparmor > /dev/null 2>&1; then
    check_info "AppArmor actif (normal sur Ubuntu)"
fi

echo ""

# 8. DÉPENDANCES SYSTÈME
echo -e "${CYAN}[8/9] Dépendances système${NC}"
echo ""

required_commands=("curl" "wget" "tar" "gzip" "awk" "sed" "grep" "ip" "ss" "systemctl" "gpg")
missing_commands=()

for cmd in "${required_commands[@]}"; do
    if command -v $cmd &> /dev/null; then
        check_success "Commande $cmd présente"
    else
        check_error "Commande $cmd manquante"
        missing_commands+=("$cmd")
    fi
done

if [ ${#missing_commands[@]} -gt 0 ]; then
    check_info "Installez avec : apt update && apt install -y ${missing_commands[*]}"
fi

echo ""

# 9. MODULES KERNEL
echo -e "${CYAN}[9/9] Modules kernel${NC}"
echo ""

# Vérifier les modules nécessaires
check_module() {
    local module=$1
    if lsmod | grep -q "^$module "; then
        check_success "Module $module chargé"
    else
        if modinfo $module &> /dev/null; then
            check_info "Module $module disponible (sera chargé lors de l'installation)"
        else
            check_warning "Module $module non disponible"
        fi
    fi
}

check_module "overlay"
check_module "br_netfilter"

# Vérifier les paramètres sysctl
if sysctl net.bridge.bridge-nf-call-iptables &> /dev/null; then
    bridge_iptables=$(sysctl -n net.bridge.bridge-nf-call-iptables 2>/dev/null || echo "0")
    if [ "$bridge_iptables" = "1" ]; then
        check_success "net.bridge.bridge-nf-call-iptables = 1"
    else
        check_info "net.bridge.bridge-nf-call-iptables = 0 (sera configuré)"
    fi
fi

if sysctl net.ipv4.ip_forward &> /dev/null; then
    ip_forward=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "0")
    if [ "$ip_forward" = "1" ]; then
        check_success "net.ipv4.ip_forward = 1"
    else
        check_info "net.ipv4.ip_forward = 0 (sera configuré)"
    fi
fi

echo ""

################################################################################
# RÉSUMÉ
################################################################################

echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Résumé de la vérification${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ Tous les prérequis sont satisfaits !${NC}"
    echo ""
    echo -e "${BLUE}Le système est prêt pour l'installation de Kubernetes${NC}"
    echo ""
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ $WARNINGS avertissement(s) détecté(s)${NC}"
    echo ""
    echo -e "${BLUE}L'installation peut continuer mais peut rencontrer des problèmes mineurs${NC}"
    echo -e "${BLUE}Les avertissements seront généralement résolus automatiquement${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}✗ $ERRORS erreur(s) critique(s), $WARNINGS avertissement(s)${NC}"
    echo ""
    echo -e "${RED}Veuillez corriger les erreurs critiques avant de continuer${NC}"
    echo ""
    echo -e "${YELLOW}Actions recommandées :${NC}"

    if [ "$total_ram" -lt 2048 ] 2>/dev/null; then
        echo "  • Augmentez la RAM à minimum 2 Go (4 Go recommandé)"
    fi

    if [ "$cpu_count" -lt 2 ] 2>/dev/null; then
        echo "  • Augmentez le nombre de CPU à minimum 2 cœurs"
    fi

    if [ ${#missing_commands[@]} -gt 0 ]; then
        echo "  • Installez les commandes manquantes : apt install -y ${missing_commands[*]}"
    fi

    if [[ $EUID -ne 0 ]]; then
        echo "  • Exécutez le script avec sudo : sudo $0 $NODE_TYPE"
    fi

    echo ""
    exit 1
fi
