#!/bin/bash
################################################################################
# Bibliothèque d'optimisation des performances
# Cache, téléchargements parallèles, timeouts adaptatifs
# Auteur: azurtech56
# Version: 2.1
################################################################################

# Configuration
CACHE_DIR="${CACHE_DIR:-/var/cache/k8s-setup}"
CACHE_EXPIRY="${CACHE_EXPIRY:-86400}"  # 24h par défaut
PARALLEL_DOWNLOADS="${PARALLEL_DOWNLOADS:-true}"
SMART_WAIT="${SMART_WAIT:-true}"

################################################################################
# CACHE SYSTÈME
################################################################################

# Initialiser le cache
init_cache() {
    mkdir -p "$CACHE_DIR"/{manifests,packages,downloads}
    chmod 755 "$CACHE_DIR"

    # Créer index du cache
    touch "$CACHE_DIR/.cache-index"
}

# Nettoyer le cache expiré
cleanup_cache() {
    local current_time=$(date +%s)

    find "$CACHE_DIR" -type f | while read -r file; do
        local file_time=$(stat -c %Y "$file" 2>/dev/null || echo 0)
        local age=$((current_time - file_time))

        if [ "$age" -gt "$CACHE_EXPIRY" ]; then
            rm -f "$file"
            log_debug "Cache expiré supprimé: $(basename "$file")" 2>/dev/null || true
        fi
    done
}

# Obtenir la taille du cache
get_cache_size() {
    du -sh "$CACHE_DIR" 2>/dev/null | cut -f1 || echo "0"
}

# Purger complètement le cache
purge_cache() {
    rm -rf "$CACHE_DIR"/*
    log_info "Cache purgé" 2>/dev/null || echo "✓ Cache purgé"
}

################################################################################
# TÉLÉCHARGEMENTS OPTIMISÉS
################################################################################

# Téléchargement avec cache
cached_download() {
    local url=$1
    local output_file=${2:-}
    local force_refresh=${3:-false}

    init_cache

    # Générer nom de fichier cache
    local filename=$(basename "$url" | sed 's/[^a-zA-Z0-9._-]/_/g')
    local cache_file="$CACHE_DIR/manifests/$filename"

    # Vérifier le cache
    if [ "$force_refresh" = false ] && [ -f "$cache_file" ]; then
        local age=$(($(date +%s) - $(stat -c %Y "$cache_file")))

        if [ "$age" -lt "$CACHE_EXPIRY" ]; then
            log_info "Utilisation cache: $filename (âge: ${age}s)" 2>/dev/null || echo "✓ Cache: $filename"

            if [ -n "$output_file" ]; then
                cp "$cache_file" "$output_file"
            else
                cat "$cache_file"
            fi
            return 0
        else
            log_debug "Cache expiré pour $filename" 2>/dev/null || true
        fi
    fi

    # Télécharger
    log_info "Téléchargement: $filename" 2>/dev/null || echo "⬇ $filename"

    if [ -n "$output_file" ]; then
        if wget -qO "$output_file" "$url"; then
            cp "$output_file" "$cache_file"
            return 0
        fi
    else
        if wget -qO- "$url" | tee "$cache_file"; then
            return 0
        fi
    fi

    return 1
}

# Téléchargements parallèles
parallel_download() {
    local -a urls=("$@")
    local -a pids=()
    local -a results=()
    local failed=0

    if [ "$PARALLEL_DOWNLOADS" = false ]; then
        # Mode séquentiel
        for url in "${urls[@]}"; do
            cached_download "$url" || ((failed++))
        done
        return $failed
    fi

    # Mode parallèle
    log_info "Téléchargements parallèles: ${#urls[@]} fichiers" 2>/dev/null || echo "⬇ ${#urls[@]} fichiers..."

    for url in "${urls[@]}"; do
        cached_download "$url" > /dev/null 2>&1 &
        pids+=($!)
    done

    # Attendre tous les téléchargements
    for i in "${!pids[@]}"; do
        if wait "${pids[$i]}"; then
            results[$i]="OK"
        else
            results[$i]="FAILED"
            ((failed++))
        fi
    done

    # Afficher résultats
    for i in "${!urls[@]}"; do
        local filename=$(basename "${urls[$i]}")
        if [ "${results[$i]}" = "OK" ]; then
            log_success "✓ $filename" 2>/dev/null || echo "✓ $filename"
        else
            log_error "✗ $filename" 2>/dev/null || echo "✗ $filename"
        fi
    done

    return $failed
}

################################################################################
# SMART WAITING (Timeouts adaptatifs)
################################################################################

# Attente intelligente avec vérification rapide
smart_wait() {
    local selector=$1
    local namespace=${2:-default}
    local max_timeout=${3:-300}
    local check_interval=${4:-2}

    if [ "$SMART_WAIT" = false ]; then
        # Mode standard
        kubectl wait --for=condition=ready pod -l "$selector" -n "$namespace" --timeout="${max_timeout}s" 2>/dev/null
        return $?
    fi

    local elapsed=0
    local last_status=""

    log_info "Attente pods: $selector (max: ${max_timeout}s)" 2>/dev/null || echo "⏳ $selector"

    while [ $elapsed -lt $max_timeout ]; do
        # Compter les pods
        local total_pods=$(kubectl get pods -n "$namespace" -l "$selector" --no-headers 2>/dev/null | wc -l)

        if [ "$total_pods" -eq 0 ]; then
            log_debug "Aucun pod trouvé pour $selector" 2>/dev/null || true
            sleep $check_interval
            ((elapsed += check_interval))
            continue
        fi

        # Compter les pods Ready
        local ready_pods=$(kubectl get pods -n "$namespace" -l "$selector" \
            -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null \
            | grep -o "True" | wc -l)

        # Tous les pods sont prêts
        if [ "$ready_pods" -eq "$total_pods" ]; then
            log_success "Pods prêts en ${elapsed}s ($ready_pods/$total_pods)" 2>/dev/null || echo "✓ Prêts en ${elapsed}s"
            return 0
        fi

        # Afficher progression (toutes les 10s ou changement de statut)
        local current_status="$ready_pods/$total_pods"
        if [ $((elapsed % 10)) -eq 0 ] || [ "$current_status" != "$last_status" ]; then
            log_info "  $ready_pods/$total_pods Running... (${elapsed}s/${max_timeout}s)" 2>/dev/null || echo "  $ready_pods/$total_pods (${elapsed}s)"
            last_status="$current_status"
        fi

        sleep $check_interval
        ((elapsed += check_interval))
    done

    log_warn "Timeout après ${elapsed}s ($ready_pods/$total_pods prêts)" 2>/dev/null || echo "⚠ Timeout ${elapsed}s"
    return 1
}

# Attente avec retry automatique
smart_wait_with_retry() {
    local selector=$1
    local namespace=${2:-default}
    local max_timeout=${3:-300}
    local max_retries=${4:-3}
    local retry=0

    while [ $retry -lt $max_retries ]; do
        if smart_wait "$selector" "$namespace" "$max_timeout"; then
            return 0
        fi

        ((retry++))

        if [ $retry -lt $max_retries ]; then
            log_warn "Retry $retry/$max_retries après 10s..." 2>/dev/null || echo "⚠ Retry $retry/$max_retries"
            sleep 10
        fi
    done

    log_error "Échec après $max_retries tentatives" 2>/dev/null || echo "✗ Échec après $max_retries tentatives"
    return 1
}

################################################################################
# OPTIMISATION APT
################################################################################

# Optimisation apt avec cache
optimize_apt() {
    local force_update=${1:-false}

    # Vérifier l'âge du cache apt
    local apt_cache_file="/var/cache/apt/pkgcache.bin"

    if [ ! -f "$apt_cache_file" ]; then
        log_info "Premier apt update..." 2>/dev/null || echo "⏳ apt update"
        apt-get update -qq
        return 0
    fi

    local cache_age=$(($(date +%s) - $(stat -c %Y "$apt_cache_file")))
    local cache_age_hours=$((cache_age / 3600))

    # Forcer mise à jour si demandé
    if [ "$force_update" = true ]; then
        log_info "apt update forcé..." 2>/dev/null || echo "⏳ apt update (forcé)"
        apt-get update -qq
        return 0
    fi

    # Rafraîchir si > 1h
    if [ "$cache_age" -gt 3600 ]; then
        log_info "Rafraîchissement cache apt (${cache_age_hours}h)..." 2>/dev/null || echo "⏳ apt update (${cache_age_hours}h)"
        apt-get update -qq
    else
        log_info "Cache apt récent (${cache_age}s), skip update" 2>/dev/null || echo "✓ Cache apt récent"
    fi
}

# Installation groupée de packages
install_packages_bulk() {
    local -a packages=("$@")
    local -a to_install=()

    # Vérifier quels packages ne sont pas installés
    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            to_install+=("$pkg")
        fi
    done

    # Installer tous les packages manquants en une fois
    if [ ${#to_install[@]} -gt 0 ]; then
        log_info "Installation de ${#to_install[@]} packages: ${to_install[*]}" 2>/dev/null || echo "⏳ ${#to_install[@]} packages"
        apt-get install -y -qq "${to_install[@]}"
    else
        log_success "Tous les packages sont déjà installés" 2>/dev/null || echo "✓ Packages OK"
    fi
}

################################################################################
# OPTIMISATION KUBERNETES
################################################################################

# Vérification rapide de disponibilité du cluster
quick_cluster_check() {
    local max_retries=${1:-5}
    local retry=0

    while [ $retry -lt $max_retries ]; do
        if kubectl cluster-info &> /dev/null; then
            return 0
        fi

        ((retry++))
        sleep 1
    done

    return 1
}

# Apply avec retry intelligent
kubectl_apply_smart() {
    local manifest=$1
    local max_retries=${2:-3}
    local retry=0

    while [ $retry -lt $max_retries ]; do
        if kubectl apply -f "$manifest" 2>&1 | tee /tmp/kubectl-apply.log; then
            return 0
        fi

        # Vérifier si erreur de webhook (retry)
        if grep -q "webhook" /tmp/kubectl-apply.log; then
            ((retry++))
            log_warn "Webhook pas prêt, retry $retry/$max_retries après 10s..." 2>/dev/null || echo "⚠ Retry $retry"
            sleep 10
        else
            # Autre erreur, pas de retry
            return 1
        fi
    done

    return 1
}

################################################################################
# MÉTRIQUES DE PERFORMANCE
################################################################################

# Démarrer un chronomètre
start_timer() {
    local timer_name=${1:-default}
    declare -g "TIMER_START_${timer_name}=$(date +%s)"
}

# Arrêter et afficher le temps écoulé
stop_timer() {
    local timer_name=${1:-default}
    local start_var="TIMER_START_${timer_name}"
    local start_time=${!start_var}

    if [ -z "$start_time" ]; then
        log_warn "Timer '$timer_name' non démarré" 2>/dev/null || echo "⚠ Timer non démarré"
        return 1
    fi

    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    local minutes=$((elapsed / 60))
    local seconds=$((elapsed % 60))

    if [ $minutes -gt 0 ]; then
        log_info "⏱ $timer_name: ${minutes}min ${seconds}s" 2>/dev/null || echo "⏱ ${minutes}min ${seconds}s"
    else
        log_info "⏱ $timer_name: ${seconds}s" 2>/dev/null || echo "⏱ ${seconds}s"
    fi

    # Nettoyer
    unset "TIMER_START_${timer_name}"

    return 0
}

################################################################################
# OPTIMISATION RÉSEAU
################################################################################

# Test de bande passante
test_download_speed() {
    local test_url=${1:-"http://speedtest.tele2.net/1MB.zip"}
    local test_file="/tmp/speedtest-$$"

    log_info "Test de vitesse de téléchargement..." 2>/dev/null || echo "⏳ Test vitesse"

    local start_time=$(date +%s.%N)

    if wget -qO "$test_file" "$test_url" 2>/dev/null; then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc)
        local file_size=$(stat -c %s "$test_file")
        local speed_mbps=$(echo "scale=2; ($file_size * 8) / ($duration * 1000000)" | bc)

        rm -f "$test_file"

        log_info "Vitesse: ${speed_mbps} Mbps" 2>/dev/null || echo "✓ ${speed_mbps} Mbps"

        # Ajuster les stratégies selon la vitesse
        if (( $(echo "$speed_mbps < 10" | bc -l) )); then
            log_warn "Connexion lente détectée, optimisations activées" 2>/dev/null || echo "⚠ Connexion lente"
            export PARALLEL_DOWNLOADS=false  # Désactiver parallélisme
        fi

        return 0
    fi

    rm -f "$test_file"
    log_warn "Impossible de tester la vitesse" 2>/dev/null || echo "⚠ Test échoué"
    return 1
}

# Optimiser les timeouts selon la latence réseau
optimize_timeouts() {
    local test_host=${1:-8.8.8.8}

    # Mesurer latence
    local latency=$(ping -c 3 "$test_host" 2>/dev/null | tail -1 | awk '{print $4}' | cut -d '/' -f 2)

    if [ -n "$latency" ]; then
        local latency_int=$(echo "$latency" | cut -d '.' -f 1)

        # Ajuster timeouts selon latence
        if [ "$latency_int" -gt 100 ]; then
            log_warn "Latence élevée (${latency}ms), augmentation des timeouts" 2>/dev/null || echo "⚠ Latence: ${latency}ms"
            export KUBECTL_WAIT_TIMEOUT="600s"
            export KUBECTL_WAIT_TIMEOUT_SHORT="300s"
        else
            log_info "Latence: ${latency}ms (normale)" 2>/dev/null || echo "✓ Latence: ${latency}ms"
        fi
    fi
}

################################################################################
# PRÉCHARGEMENT
################################################################################

# Précharger les images Docker en parallèle
preload_images() {
    local -a images=("$@")
    local -a pids=()

    if [ ${#images[@]} -eq 0 ]; then
        return 0
    fi

    log_info "Préchargement de ${#images[@]} images..." 2>/dev/null || echo "⏳ ${#images[@]} images"

    for image in "${images[@]}"; do
        (
            if ctr -n k8s.io images pull "$image" &> /dev/null; then
                log_success "✓ $(basename "$image")" 2>/dev/null || echo "✓ $(basename "$image")"
            fi
        ) &
        pids+=($!)
    done

    # Attendre tous les pulls
    for pid in "${pids[@]}"; do
        wait "$pid"
    done

    log_success "Images préchargées" 2>/dev/null || echo "✓ Images OK"
}

################################################################################
# EXPORT DES FONCTIONS
################################################################################

export -f init_cache
export -f cleanup_cache
export -f get_cache_size
export -f purge_cache
export -f cached_download
export -f parallel_download
export -f smart_wait
export -f smart_wait_with_retry
export -f optimize_apt
export -f install_packages_bulk
export -f quick_cluster_check
export -f kubectl_apply_smart
export -f start_timer
export -f stop_timer
export -f test_download_speed
export -f optimize_timeouts
export -f preload_images
