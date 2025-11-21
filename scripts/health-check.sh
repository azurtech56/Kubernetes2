#!/bin/bash
################################################################################
# Script de vérification de santé du cluster Kubernetes
# Vérifie les nœuds, pods, services, et composants système
# Auteur: azurtech56
# Version: 2.0
################################################################################

set -e

# Charger les bibliothèques v2.1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/lib/error-codes.sh" ]; then
    source "$SCRIPT_DIR/lib/error-codes.sh"
fi

if [ -f "$SCRIPT_DIR/lib/notifications.sh" ]; then
    source "$SCRIPT_DIR/lib/notifications.sh"
fi

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

# Compteurs
HEALTHY=0
WARNING=0
CRITICAL=0

# Options
VERBOSE=false
CONTINUOUS=false
INTERVAL=60
NOTIFY=false

################################################################################
# FONCTIONS
################################################################################

show_usage() {
    cat <<EOF
${CYAN}════════════════════════════════════════════════════════════════${NC}
  Health Check - Cluster Kubernetes HA
${CYAN}════════════════════════════════════════════════════════════════${NC}

${YELLOW}Usage:${NC}
  $0 [options]

${YELLOW}Options:${NC}
  -v, --verbose           Mode verbeux (afficher plus de détails)
  -c, --continuous        Mode continu (rafraîchir toutes les N secondes)
  -i, --interval <sec>    Intervalle de rafraîchissement (défaut: 60s)
  -n, --notify            Envoyer des notifications en cas de problème
  -h, --help              Afficher cette aide

${YELLOW}Exemples:${NC}
  $0                      # Vérification unique
  $0 -v                   # Vérification détaillée
  $0 -c -i 30             # Monitoring continu toutes les 30s
  $0 --notify             # Avec notifications

${CYAN}════════════════════════════════════════════════════════════════${NC}
EOF
}

check_healthy() {
    echo -e "${GREEN}✓${NC} $1"
    ((HEALTHY++))
}

check_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNING++))
}

check_critical() {
    echo -e "${RED}✗${NC} $1"
    ((CRITICAL++))
}

check_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Fonction de notification (email/Slack)
send_notification() {
    local message=$1
    local severity=$2  # info, warning, critical

    if [ "$NOTIFY" = false ]; then
        return 0
    fi

    # Email (si configuré)
    if [ -n "${NOTIFICATION_EMAIL:-}" ]; then
        echo "$message" | mail -s "[K8s] Health Check Alert - $severity" "$NOTIFICATION_EMAIL" 2>/dev/null || true
    fi

    # Slack (si configuré)
    if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
        local color="good"
        [ "$severity" = "warning" ] && color="warning"
        [ "$severity" = "critical" ] && color="danger"

        curl -X POST "$SLACK_WEBHOOK_URL" \
            -H 'Content-Type: application/json' \
            -d "{\"text\":\"$message\",\"color\":\"$color\"}" \
            2>/dev/null || true
    fi
}

################################################################################
# VÉRIFICATIONS
################################################################################

perform_health_check() {
    clear
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Health Check - Cluster Kubernetes HA${NC}"
    echo -e "${CYAN}  $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Réinitialiser les compteurs
    HEALTHY=0
    WARNING=0
    CRITICAL=0

    # 1. CLUSTER INFO
    echo -e "${CYAN}[1/8] Informations du cluster${NC}"
    echo ""

    if kubectl cluster-info &> /dev/null; then
        check_healthy "Cluster accessible"

        # Version Kubernetes
        k8s_version=$(kubectl version --short 2>/dev/null | grep Server || echo "N/A")
        check_info "Version: $k8s_version"
    else
        check_critical "Impossible d'accéder au cluster"
        send_notification "Cluster Kubernetes inaccessible" "critical"
        return 1
    fi

    echo ""

    # 2. NODES
    echo -e "${CYAN}[2/8] État des nœuds${NC}"
    echo ""

    # Compter les nœuds
    total_nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready" || echo 0)
    not_ready_nodes=$((total_nodes - ready_nodes))

    if [ "$total_nodes" -eq 0 ]; then
        check_critical "Aucun nœud trouvé"
        send_notification "Aucun nœud dans le cluster" "critical"
    elif [ "$not_ready_nodes" -eq 0 ]; then
        check_healthy "Tous les nœuds sont Ready ($total_nodes/$total_nodes)"
    else
        check_critical "$not_ready_nodes nœud(s) NOT Ready sur $total_nodes"
        send_notification "$not_ready_nodes nœuds NOT Ready" "critical"
    fi

    # Détails des nœuds (mode verbeux)
    if [ "$VERBOSE" = true ]; then
        echo ""
        kubectl get nodes -o wide 2>/dev/null || true
        echo ""
    fi

    # Vérifier les masters
    master_count=$(kubectl get nodes --selector=node-role.kubernetes.io/control-plane --no-headers 2>/dev/null | wc -l)
    if [ "$master_count" -ge 3 ]; then
        check_healthy "Masters HA: $master_count nœuds control-plane"
    elif [ "$master_count" -eq 1 ]; then
        check_warning "Single master (pas de HA)"
    else
        check_info "Masters: $master_count nœud(s)"
    fi

    echo ""

    # 3. PODS SYSTÈME
    echo -e "${CYAN}[3/8] Pods système (kube-system)${NC}"
    echo ""

    # Pods critiques
    critical_pods=(
        "kube-apiserver"
        "kube-controller-manager"
        "kube-scheduler"
        "kube-proxy"
        "etcd"
        "coredns"
    )

    for pod_name in "${critical_pods[@]}"; do
        pod_count=$(kubectl get pods -n kube-system -l "component=${pod_name}" --no-headers 2>/dev/null | wc -l)

        if [ "$pod_count" -eq 0 ]; then
            # Essayer avec le nom du pod directement
            pod_count=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c "^${pod_name}" || echo 0)
        fi

        if [ "$pod_count" -gt 0 ]; then
            running_count=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep "^${pod_name}" | grep -c "Running" || echo 0)

            if [ "$running_count" -eq "$pod_count" ]; then
                check_healthy "$pod_name: $running_count/$pod_count Running"
            else
                check_critical "$pod_name: $running_count/$pod_count Running"
                send_notification "Pod système $pod_name en erreur" "critical"
            fi
        else
            check_info "$pod_name: non trouvé (normal si externe)"
        fi
    done

    # Tous les pods kube-system
    total_system_pods=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l)
    running_system_pods=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c "Running" || echo 0)

    if [ "$running_system_pods" -eq "$total_system_pods" ]; then
        check_healthy "Tous les pods système Running ($running_system_pods/$total_system_pods)"
    else
        not_running=$((total_system_pods - running_system_pods))
        check_warning "$not_running pod(s) système non Running"
    fi

    echo ""

    # 4. CALICO
    echo -e "${CYAN}[4/8] Calico CNI${NC}"
    echo ""

    calico_pods=$(kubectl get pods -n calico-system --no-headers 2>/dev/null | wc -l)
    if [ "$calico_pods" -eq 0 ]; then
        # Essayer dans kube-system (Calico peut être là)
        calico_pods=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c "calico" || echo 0)
        calico_ns="kube-system"
    else
        calico_ns="calico-system"
    fi

    if [ "$calico_pods" -gt 0 ]; then
        calico_ready=$(kubectl get pods -n "$calico_ns" --no-headers 2>/dev/null | grep "calico" | grep -c "Running" || echo 0)

        if [ "$calico_ready" -eq "$calico_pods" ]; then
            check_healthy "Calico: $calico_ready/$calico_pods pods Running"
        else
            check_critical "Calico: $calico_ready/$calico_pods pods Running"
            send_notification "Calico CNI en erreur" "critical"
        fi
    else
        check_warning "Calico non trouvé"
    fi

    echo ""

    # 5. METALLB
    echo -e "${CYAN}[5/8] MetalLB Load Balancer${NC}"
    echo ""

    if kubectl get namespace metallb-system &> /dev/null; then
        metallb_controller=$(kubectl get pods -n metallb-system -l app=metallb,component=controller --no-headers 2>/dev/null | grep -c "Running" || echo 0)
        metallb_speaker=$(kubectl get pods -n metallb-system -l app=metallb,component=speaker --no-headers 2>/dev/null | grep -c "Running" || echo 0)

        if [ "$metallb_controller" -gt 0 ]; then
            check_healthy "MetalLB controller: Running"
        else
            check_critical "MetalLB controller: NOT Running"
        fi

        if [ "$metallb_speaker" -gt 0 ]; then
            check_healthy "MetalLB speaker: $metallb_speaker pod(s) Running"
        else
            check_critical "MetalLB speaker: NOT Running"
        fi
    else
        check_info "MetalLB non installé"
    fi

    echo ""

    # 6. RANCHER
    echo -e "${CYAN}[6/8] Rancher Management${NC}"
    echo ""

    if kubectl get namespace cattle-system &> /dev/null; then
        rancher_pods=$(kubectl get pods -n cattle-system -l app=rancher --no-headers 2>/dev/null | wc -l)
        rancher_ready=$(kubectl get pods -n cattle-system -l app=rancher --no-headers 2>/dev/null | grep -c "Running" || echo 0)

        if [ "$rancher_ready" -eq "$rancher_pods" ] && [ "$rancher_pods" -gt 0 ]; then
            check_healthy "Rancher: $rancher_ready/$rancher_pods pods Running"
        elif [ "$rancher_pods" -gt 0 ]; then
            check_warning "Rancher: $rancher_ready/$rancher_pods pods Running"
        fi
    else
        check_info "Rancher non installé"
    fi

    echo ""

    # 7. MONITORING
    echo -e "${CYAN}[7/8] Monitoring (Prometheus + Grafana)${NC}"
    echo ""

    if kubectl get namespace monitoring &> /dev/null; then
        # Prometheus
        prom_pods=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus --no-headers 2>/dev/null | wc -l)
        prom_ready=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus --no-headers 2>/dev/null | grep -c "Running" || echo 0)

        if [ "$prom_ready" -eq "$prom_pods" ] && [ "$prom_pods" -gt 0 ]; then
            check_healthy "Prometheus: Running"
        elif [ "$prom_pods" -gt 0 ]; then
            check_warning "Prometheus: $prom_ready/$prom_pods Running"
        fi

        # Grafana
        grafana_pods=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana --no-headers 2>/dev/null | wc -l)
        grafana_ready=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana --no-headers 2>/dev/null | grep -c "Running" || echo 0)

        if [ "$grafana_ready" -eq "$grafana_pods" ] && [ "$grafana_pods" -gt 0 ]; then
            check_healthy "Grafana: Running"
        elif [ "$grafana_pods" -gt 0 ]; then
            check_warning "Grafana: $grafana_ready/$grafana_pods Running"
        fi
    else
        check_info "Monitoring non installé"
    fi

    echo ""

    # 8. APPLICATIONS UTILISATEUR
    echo -e "${CYAN}[8/8] Applications utilisateur${NC}"
    echo ""

    # Compter les pods dans les namespaces non-système
    system_namespaces="kube-system|kube-public|kube-node-lease|metallb-system|cattle-system|calico-system|monitoring|cert-manager"

    user_pods=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | grep -Ev "$system_namespaces" | wc -l)
    user_running=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | grep -Ev "$system_namespaces" | grep -c "Running" || echo 0)

    if [ "$user_pods" -gt 0 ]; then
        if [ "$user_running" -eq "$user_pods" ]; then
            check_healthy "Applications: $user_running/$user_pods pods Running"
        else
            check_warning "Applications: $user_running/$user_pods pods Running"
        fi

        # Afficher les namespaces utilisateur
        if [ "$VERBOSE" = true ]; then
            echo ""
            echo "  Namespaces utilisateur:"
            kubectl get namespaces --no-headers 2>/dev/null | grep -Ev "$system_namespaces" | awk '{print "    - " $1}'
        fi
    else
        check_info "Aucune application utilisateur déployée"
    fi

    echo ""

    ############################################################################
    # RÉSUMÉ
    ############################################################################

    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Résumé de santé${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""

    total_checks=$((HEALTHY + WARNING + CRITICAL))

    echo -e "  ${GREEN}Sain:${NC}       $HEALTHY/$total_checks vérifications"
    echo -e "  ${YELLOW}Avertissement:${NC} $WARNING/$total_checks vérifications"
    echo -e "  ${RED}Critique:${NC}   $CRITICAL/$total_checks vérifications"

    echo ""

    # État global
    if [ "$CRITICAL" -eq 0 ] && [ "$WARNING" -eq 0 ]; then
        echo -e "${GREEN}✓ ÉTAT: SAIN${NC}"
        echo -e "${GREEN}Le cluster fonctionne normalement${NC}"
        exit_code=0
        # Notification v2.1
        if type -t notify_health_check &>/dev/null; then
            notify_health_check "healthy" "Cluster OK - $HEALTHY/$total_checks vérifications réussies"
        fi
    elif [ "$CRITICAL" -eq 0 ]; then
        echo -e "${YELLOW}⚠ ÉTAT: AVERTISSEMENT${NC}"
        echo -e "${YELLOW}Le cluster fonctionne mais nécessite attention${NC}"
        exit_code=1
        # Notification v2.1
        if type -t notify_health_check &>/dev/null; then
            notify_health_check "degraded" "$WARNING avertissement(s) détecté(s)"
        fi
    else
        echo -e "${RED}✗ ÉTAT: CRITIQUE${NC}"
        echo -e "${RED}Le cluster a des problèmes critiques${NC}"
        send_notification "Cluster Kubernetes en état CRITIQUE: $CRITICAL problème(s)" "critical"
        exit_code=2
        # Notification v2.1
        if type -t notify_health_check &>/dev/null; then
            notify_health_check "critical" "$CRITICAL problème(s) critique(s)"
        fi
    fi

    echo ""

    # Recommandations
    if [ "$CRITICAL" -gt 0 ] || [ "$WARNING" -gt 0 ]; then
        echo -e "${YELLOW}Recommandations:${NC}"

        if [ "$not_ready_nodes" -gt 0 ] 2>/dev/null; then
            echo "  • Vérifiez les nœuds NOT Ready: kubectl describe nodes"
        fi

        if [ "$CRITICAL" -gt 0 ]; then
            echo "  • Consultez les logs: kubectl logs <pod-name> -n <namespace>"
            echo "  • Vérifiez les événements: kubectl get events --all-namespaces --sort-by='.lastTimestamp'"
        fi

        echo ""
    fi

    return $exit_code
}

################################################################################
# MAIN
################################################################################

# Parser les arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -c|--continuous)
            CONTINUOUS=true
            shift
            ;;
        -i|--interval)
            INTERVAL=$2
            shift 2
            ;;
        -n|--notify)
            NOTIFY=true
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

# Charger les variables d'environnement pour notifications
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env" 2>/dev/null || true
fi

# Vérifier que kubectl est disponible
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl non trouvé. Veuillez l'installer.${NC}"
    exit 1
fi

# Mode continu ou unique
if [ "$CONTINUOUS" = true ]; then
    echo -e "${CYAN}Mode monitoring continu (Ctrl+C pour arrêter)${NC}"
    echo -e "${CYAN}Intervalle: ${INTERVAL}s${NC}"
    echo ""

    while true; do
        perform_health_check
        sleep "$INTERVAL"
    done
else
    perform_health_check
    exit $?
fi
