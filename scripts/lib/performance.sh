#!/bin/bash
################################################################################
# Optimisations de Performance pour Installation Kubernetes
# Parallélisation, caching, smart waiting
# Auteur: Claude Code
# Version: 1.0
################################################################################

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================================
# CACHE MANAGEMENT
# ============================================================================

CACHE_DIR="/var/cache/k8s-setup"
CACHE_MANIFEST_DIR="$CACHE_DIR/manifests"
CACHE_IMAGES_DIR="$CACHE_DIR/images"

# Initialiser le système de cache
init_cache() {
    mkdir -p "$CACHE_MANIFEST_DIR"
    mkdir -p "$CACHE_IMAGES_DIR"
    chmod 755 "$CACHE_DIR"
    echo -e "${GREEN}✓ Cache système initialisé: $CACHE_DIR${NC}"
}

# Télécharger un fichier avec cache
# Usage: cached_download <url> <cache_key> [output_file]
cached_download() {
    local url="$1"
    local cache_key="$2"
    local output="${3:-.}"
    local cache_file="$CACHE_MANIFEST_DIR/${cache_key}.yaml"

    if [ -f "$cache_file" ]; then
        echo -e "${GREEN}✓ Cache valide: $cache_key${NC}"
        if [ "$output" != "." ]; then
            cat "$cache_file" > "$output"
        else
            cat "$cache_file"
        fi
        return 0
    fi

    echo -e "${YELLOW}↓ Téléchargement: $cache_key...${NC}"
    if curl -fsSL "$url" -o "$cache_file"; then
        echo -e "${GREEN}✓ Téléchargement réussi${NC}"
        if [ "$output" != "." ]; then
            cat "$cache_file" > "$output"
        else
            cat "$cache_file"
        fi
        return 0
    else
        echo -e "${RED}✗ Erreur téléchargement: $url${NC}"
        rm -f "$cache_file"
        return 1
    fi
}

# Vérifier et nettoyer le cache (fichiers >1 jour)
cleanup_old_cache() {
    echo -e "${YELLOW}Nettoyage cache ancien...${NC}"

    find "$CACHE_MANIFEST_DIR" -type f -mtime +1 -delete
    find "$CACHE_IMAGES_DIR" -type f -mtime +1 -delete

    echo -e "${GREEN}✓ Cache nettoyé${NC}"
}

# ============================================================================
# SMART WAITING - Vérification intelligente d'état
# ============================================================================

smart_wait() {
    local condition="Ready"
    local resource_type="pods"
    local selector=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --for=*)
                condition="${1#--for=}"
                shift
                ;;
            *)
                if [ -z "$resource_type" ] || [ "$resource_type" = "pods" ]; then
                    resource_type="$1"
                else
                    selector="$1"
                fi
                shift
                ;;
        esac
    done

    local timeout=300
    local check_interval=2
    local elapsed=0

    echo -e "${BLUE}⏳ Attente: $resource_type${NC}"

    while [ $elapsed -lt $timeout ]; do
        if kubectl get "$resource_type" $selector &>/dev/null; then
            if kubectl wait --for=condition="$condition" "$resource_type" $selector --timeout=1s 2>/dev/null; then
                echo -e "${GREEN}✓ Condition atteinte${NC}"
                return 0
            fi
        fi

        echo -ne "\r${YELLOW}  [$(printf "%3ds" $elapsed)/$timeout]${NC}"
        sleep $check_interval
        ((elapsed += check_interval))
    done

    echo ""
    echo -e "${RED}✗ Timeout après ${timeout}s${NC}"
    return 1
}

smart_wait_with_retry() {
    local max_retries=3
    local retry=0

    while [ $retry -lt $max_retries ]; do
        if smart_wait "$@"; then
            return 0
        fi

        ((retry++))
        if [ $retry -lt $max_retries ]; then
            echo -e "${YELLOW}⚠ Tentative $((retry + 1))/$max_retries...${NC}"
            sleep 5
        fi
    done

    echo -e "${RED}✗ Échec après $max_retries tentatives${NC}"
    return 1
}

# ============================================================================
# PARALLÉLISATION
# ============================================================================

parallel_download_manifests() {
    local -a urls=("$@")
    local -a pids=()
    local -a names=()

    echo -e "${BLUE}📥 Téléchargement parallèle...${NC}"

    for url in "${urls[@]}"; do
        local filename=$(basename "$url" | cut -d'?' -f1)
        names+=("$filename")

        (
            if curl -fsSL "$url" -o "/tmp/$filename"; then
                echo -e "${GREEN}  ✓ $filename${NC}"
            else
                echo -e "${RED}  ✗ $filename${NC}"
                exit 1
            fi
        ) &

        pids+=($!)
    done

    local failed=0
    for i in "${!pids[@]}"; do
        if ! wait "${pids[$i]}"; then
            ((failed++))
        fi
    done

    [ $failed -eq 0 ] && echo -e "${GREEN}✓ Tous les manifests téléchargés${NC}" || return 1
}

preload_docker_images() {
    local -a images=("$@")
    local -a pids=()

    echo -e "${BLUE}🐳 Préchargement images Docker...${NC}"

    for image in "${images[@]}"; do
        (
            docker pull "$image" &>/dev/null && echo -e "${GREEN}  ✓ $image${NC}" || echo -e "${RED}  ✗ $image${NC}"
        ) &
        pids+=($!)
    done

    wait
    echo -e "${GREEN}✓ Images chargées${NC}"
}

# ============================================================================
# APT OPTIMIZATION
# ============================================================================

optimized_apt_update() {
    local cache_file="/var/lib/apt/periodic/update-success-stamp"
    local cache_max_age=$((60 * 60))

    if [ -f "$cache_file" ]; then
        local cache_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0)))
        if [ "$cache_age" -lt "$cache_max_age" ]; then
            echo -e "${GREEN}✓ Cache APT valide${NC}"
            return 0
        fi
    fi

    echo -e "${YELLOW}Mise à jour APT...${NC}"
    apt-get update -qq && echo -e "${GREEN}✓ APT à jour${NC}" || return 1
}

optimized_apt_install() {
    local -a packages=("$@")

    optimized_apt_update || return 1

    echo -e "${BLUE}📦 Installation: ${packages[*]}${NC}"

    apt-get install -y --no-install-recommends "${packages[@]}" -qq && echo -e "${GREEN}✓ Paquets installés${NC}" || return 1
}

# ============================================================================
# PERFORMANCE MONITORING
# ============================================================================

# Tableau associatif pour stocker les timers
declare -gA TIMER_START_TIMES

# Démarrer un timer
# Usage: start_timer "timer_name"
start_timer() {
    local timer_name="$1"
    TIMER_START_TIMES["$timer_name"]=$(date +%s)
}

# Arrêter un timer et afficher le temps écoulé
# Usage: stop_timer "timer_name"
stop_timer() {
    local timer_name="$1"
    local start_time="${TIMER_START_TIMES[$timer_name]}"

    if [ -z "$start_time" ]; then
        echo -e "${YELLOW}⚠ Timer '$timer_name' non démarré${NC}"
        return 1
    fi

    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))

    local minutes=$((elapsed / 60))
    local seconds=$((elapsed % 60))

    if [ $minutes -gt 0 ]; then
        echo -e "${GREEN}✓ [$timer_name] Temps d'exécution: ${minutes}m ${seconds}s${NC}"
    else
        echo -e "${GREEN}✓ [$timer_name] Temps d'exécution: ${seconds}s${NC}"
    fi

    unset TIMER_START_TIMES["$timer_name"]
}

time_execution() {
    local start=$(date +%s%N)

    "$@"
    local exit_code=$?

    local end=$(date +%s%N)
    local elapsed=$(( (end - start) / 1000000 ))

    local seconds=$((elapsed / 1000))
    local milliseconds=$((elapsed % 1000))

    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ Exécution: ${seconds}s ${milliseconds}ms${NC}"
    else
        echo -e "${RED}✗ Échec (${seconds}s ${milliseconds}ms)${NC}"
    fi

    return $exit_code
}

# ============================================================================
# EXPORT FUNCTIONS
# ============================================================================

export -f init_cache
export -f cached_download
export -f cleanup_old_cache
export -f smart_wait
export -f smart_wait_with_retry
export -f parallel_download_manifests
export -f preload_docker_images
export -f optimized_apt_update
export -f optimized_apt_install
export -f start_timer
export -f stop_timer
export -f time_execution

echo -e "${GREEN}✓ Performance library loaded${NC}"
