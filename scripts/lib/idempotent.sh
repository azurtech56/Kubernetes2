#!/bin/bash
################################################################################
# Bibliothèque d'idempotence pour les scripts Kubernetes
# Permet de rendre les scripts ré-exécutables sans effets de bord
# Auteur: azurtech56
# Version: 2.0
################################################################################

STATE_DIR="/var/lib/k8s-setup"
STATE_FILE="$STATE_DIR/installation-state.json"

# Créer le répertoire d'état si nécessaire
init_idempotent() {
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    if [ ! -f "$STATE_FILE" ]; then
        echo '{}' > "$STATE_FILE"
    fi
}

# Vérifier si une opération a déjà été effectuée
# Usage: operation_completed "operation_name"
operation_completed() {
    local operation=$1
    init_idempotent

    if command -v jq &> /dev/null; then
        jq -e ".$operation == true" "$STATE_FILE" &> /dev/null
    else
        grep -q "\"$operation\": *true" "$STATE_FILE" 2>/dev/null
    fi
}

# Marquer une opération comme effectuée
# Usage: mark_operation_completed "operation_name"
mark_operation_completed() {
    local operation=$1
    init_idempotent

    if command -v jq &> /dev/null; then
        jq ".$operation = true" "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
    else
        # Fallback sans jq (moins robuste mais fonctionnel)
        sed -i "s/}/, \"$operation\": true}/" "$STATE_FILE" 2>/dev/null || \
            echo "{\"$operation\": true}" > "$STATE_FILE"
    fi

    [ -n "${LOG_FILE:-}" ] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] [IDEMPOTENT] Operation '$operation' marquée comme effectuée" >> "$LOG_FILE"
}

# Réinitialiser toutes les opérations (--reset-state)
reset_all_operations() {
    init_idempotent
    echo '{}' > "$STATE_FILE"
    [ -n "${LOG_FILE:-}" ] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] [IDEMPOTENT] État réinitialisé" >> "$LOG_FILE"
}

# Exécuter une commande seulement si l'opération n'a pas été effectuée
# Usage: run_once "operation_name" "command" "success_message"
run_once() {
    local operation=$1
    local command=$2
    local success_msg=${3:-"$operation effectué"}

    if operation_completed "$operation"; then
        echo "  ⏭️  $success_msg (déjà fait)"
        return 0
    fi

    if eval "$command"; then
        mark_operation_completed "$operation"
        echo "  ✓ $success_msg"
        return 0
    else
        echo "  ✗ Échec: $operation"
        return 1
    fi
}

################################################################################
# FONCTIONS SPÉCIFIQUES IDEMPOTENTES
################################################################################

# Configuration swap idempotente
setup_swap_idempotent() {
    if operation_completed "swap_disabled"; then
        echo "  ⏭️  Swap désactivé (déjà fait)"
        swapoff -a 2>/dev/null || true
        return 0
    fi

    echo "  🔄 Désactivation du swap..."

    # Désactiver le swap
    swapoff -a

    # Commenter les lignes swap dans /etc/fstab (seulement si pas déjà commentées)
    if grep -E '^[^#].*swap' /etc/fstab &> /dev/null; then
        sed -i.bak '/\sswap\s/ s/^/#/' /etc/fstab
        echo "  ✓ Lignes swap commentées dans /etc/fstab"
    fi

    mark_operation_completed "swap_disabled"
    echo "  ✓ Swap désactivé"
}

# Configuration des modules kernel idempotente
# Usage: setup_kernel_modules_idempotent "module1" "module2" ...
setup_kernel_modules_idempotent() {
    local modules=("$@")
    local operation="kernel_modules_loaded"

    if operation_completed "$operation"; then
        echo "  ⏭️  Modules kernel chargés (déjà fait)"
        # Recharger quand même au cas où
        for module in "${modules[@]}"; do
            modprobe "$module" 2>/dev/null || true
        done
        return 0
    fi

    echo "  🔄 Chargement des modules kernel..."

    # Charger les modules
    for module in "${modules[@]}"; do
        modprobe "$module"
        echo "  ✓ Module $module chargé"
    done

    # Ajouter au démarrage (seulement si pas déjà présent)
    for module in "${modules[@]}"; do
        if ! grep -q "^$module$" /etc/modules-load.d/k8s.conf 2>/dev/null; then
            echo "$module" >> /etc/modules-load.d/k8s.conf
        fi
    done

    mark_operation_completed "$operation"
    echo "  ✓ Modules kernel configurés"
}

# Configuration sysctl idempotente
setup_sysctl_idempotent() {
    local operation="sysctl_configured"

    if operation_completed "$operation"; then
        echo "  ⏭️  Paramètres sysctl configurés (déjà fait)"
        sysctl --system &> /dev/null
        return 0
    fi

    echo "  🔄 Configuration des paramètres sysctl..."

    cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

    sysctl --system

    mark_operation_completed "$operation"
    echo "  ✓ Paramètres sysctl configurés"
}

# Installation de packages idempotente
# Usage: install_package_idempotent "package_name" "operation_name"
install_package_idempotent() {
    local package=$1
    local operation=${2:-"install_$package"}

    if operation_completed "$operation"; then
        echo "  ⏭️  Package $package installé (déjà fait)"
        return 0
    fi

    # Vérifier si déjà installé
    if dpkg -l | grep -q "^ii  $package "; then
        echo "  ⏭️  Package $package déjà installé"
        mark_operation_completed "$operation"
        return 0
    fi

    echo "  🔄 Installation de $package..."
    apt-get install -y "$package"

    mark_operation_completed "$operation"
    echo "  ✓ Package $package installé"
}

# Règle UFW idempotente
# Usage: setup_ufw_rule_idempotent <port> <proto> <description> [source]
setup_ufw_rule_idempotent() {
    local port=$1
    local proto=$2
    local description=$3
    local source=${4:-""}

    local rule_signature
    if [ -n "$source" ]; then
        rule_signature="ufw_${port}_${proto}_from_${source}"
        rule_signature="${rule_signature//\//_}"  # Remplacer / par _
    else
        rule_signature="ufw_${port}_${proto}"
    fi

    # Vérifier si la règle existe déjà dans UFW
    if [ -n "$source" ]; then
        if ufw status | grep -qE "${port}/${proto}.*${source}"; then
            echo "  ⏭️  UFW: $description (règle déjà présente)"
            mark_operation_completed "$rule_signature"
            return 0
        fi
    else
        if ufw status | grep -qE "^${port}/${proto}.*ALLOW"; then
            echo "  ⏭️  UFW: $description (règle déjà présente)"
            mark_operation_completed "$rule_signature"
            return 0
        fi
    fi

    if operation_completed "$rule_signature"; then
        echo "  ⏭️  UFW: $description (déjà configuré)"
        return 0
    fi

    echo "  🔄 UFW: Ajout règle $description..."

    if [ -n "$source" ]; then
        ufw allow from "$source" to any port "$port" proto "$proto"
    else
        ufw allow "$port/$proto"
    fi

    mark_operation_completed "$rule_signature"
    echo "  ✓ UFW: $description configuré"
}

# Règle UFW pour réseau idempotente
# Usage: setup_ufw_network_rule_idempotent <network> <direction>
setup_ufw_network_rule_idempotent() {
    local network=$1
    local direction=$2  # "from" ou "to"

    local rule_signature="ufw_network_${direction}_${network}"
    rule_signature="${rule_signature//\//_}"  # Remplacer / par _

    # Vérifier si la règle existe déjà
    if ufw status | grep -qE "ALLOW.*${direction}.*${network}"; then
        echo "  ⏭️  UFW: Réseau $network ($direction) (règle déjà présente)"
        mark_operation_completed "$rule_signature"
        return 0
    fi

    if operation_completed "$rule_signature"; then
        echo "  ⏭️  UFW: Réseau $network ($direction) (déjà configuré)"
        return 0
    fi

    echo "  🔄 UFW: Autorisation réseau $network ($direction)..."

    ufw allow "$direction" "$network"

    mark_operation_completed "$rule_signature"
    echo "  ✓ UFW: Réseau $network ($direction) configuré"
}

# Règle UFW pour VRRP idempotente
setup_ufw_vrrp_idempotent() {
    local operation="ufw_vrrp_configured"

    # Vérifier si la règle existe déjà
    if ufw status | grep -qE "ALLOW.*vrrp"; then
        echo "  ⏭️  UFW: VRRP (règle déjà présente)"
        mark_operation_completed "$operation"
        return 0
    fi

    if operation_completed "$operation"; then
        echo "  ⏭️  UFW: VRRP (déjà configuré)"
        return 0
    fi

    echo "  🔄 UFW: Autorisation VRRP..."

    ufw allow from any to any proto vrrp

    mark_operation_completed "$operation"
    echo "  ✓ UFW: VRRP configuré"
}

# Activation UFW idempotente
enable_ufw_idempotent() {
    local operation="ufw_enabled"

    # Vérifier si UFW est déjà actif
    if ufw status | grep -q "Status: active"; then
        echo "  ⏭️  UFW déjà actif"
        mark_operation_completed "$operation"
        return 0
    fi

    if operation_completed "$operation"; then
        echo "  ⏭️  UFW activé (déjà fait)"
        ufw --force enable
        return 0
    fi

    echo "  🔄 Activation de UFW..."

    ufw --force enable
    ufw reload

    mark_operation_completed "$operation"
    echo "  ✓ UFW activé"
}

# Ajout d'un repository Kubernetes idempotent
setup_k8s_repo_idempotent() {
    local operation="k8s_repo_added"

    if operation_completed "$operation"; then
        echo "  ⏭️  Repository Kubernetes configuré (déjà fait)"
        return 0
    fi

    # Vérifier si le repo existe déjà
    if [ -f /etc/apt/sources.list.d/kubernetes.list ]; then
        echo "  ⏭️  Repository Kubernetes déjà présent"
        mark_operation_completed "$operation"
        return 0
    fi

    echo "  🔄 Configuration du repository Kubernetes..."

    # Installation des dépendances
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gpg

    # Ajout de la clé GPG
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | \
        gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    # Ajout du repository
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | \
        tee /etc/apt/sources.list.d/kubernetes.list

    apt-get update

    mark_operation_completed "$operation"
    echo "  ✓ Repository Kubernetes configuré"
}

# Ajout d'un repository Docker idempotent
setup_docker_repo_idempotent() {
    local operation="docker_repo_added"

    if operation_completed "$operation"; then
        echo "  ⏭️  Repository Docker configuré (déjà fait)"
        return 0
    fi

    # Vérifier si le repo existe déjà
    if [ -f /etc/apt/sources.list.d/docker.list ]; then
        echo "  ⏭️  Repository Docker déjà présent"
        mark_operation_completed "$operation"
        return 0
    fi

    echo "  🔄 Configuration du repository Docker..."

    # Installation des dépendances
    apt-get update
    apt-get install -y ca-certificates curl gnupg

    # Ajout de la clé GPG
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Ajout du repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update

    mark_operation_completed "$operation"
    echo "  ✓ Repository Docker configuré"
}

# Exporter les fonctions
export -f init_idempotent
export -f operation_completed
export -f mark_operation_completed
export -f reset_all_operations
export -f run_once
export -f setup_swap_idempotent
export -f setup_kernel_modules_idempotent
export -f setup_sysctl_idempotent
export -f install_package_idempotent
export -f setup_ufw_rule_idempotent
export -f setup_ufw_network_rule_idempotent
export -f setup_ufw_vrrp_idempotent
export -f enable_ufw_idempotent
export -f setup_k8s_repo_idempotent
export -f setup_docker_repo_idempotent
