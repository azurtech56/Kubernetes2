#!/bin/bash
################################################################################
# Script de backup complet du cluster Kubernetes
# Sauvegarde: etcd, certificats, configurations, ressources Kubernetes, add-ons
# Auteur: azurtech56
# Version: 2.0
################################################################################

set -e

# Charger les bibliothèques
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh" 2>/dev/null || true

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BACKUP_BASE_DIR="${BACKUP_DIR:-/var/backups/k8s-cluster}"
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="k8s-backup-${BACKUP_DATE}"
BACKUP_DIR="$BACKUP_BASE_DIR/$BACKUP_NAME"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"

# Options
BACKUP_TYPE="full"  # full, etcd, resources
DRY_RUN=false
VERBOSE=false

# Initialiser le logging
init_logging 2>/dev/null || true

################################################################################
# FONCTIONS UTILITAIRES
################################################################################

show_usage() {
    cat <<EOF
${CYAN}════════════════════════════════════════════════════════════════${NC}
  Backup du cluster Kubernetes HA
${CYAN}════════════════════════════════════════════════════════════════${NC}

${YELLOW}Usage:${NC}
  $0 [options]

${YELLOW}Options:${NC}
  --type <type>       Type de backup: full (défaut), etcd, resources
  --dir <directory>   Répertoire de destination (défaut: $BACKUP_BASE_DIR)
  --retention <days>  Durée de rétention en jours (défaut: $BACKUP_RETENTION_DAYS)
  --dry-run           Simulation sans sauvegarder
  --verbose           Mode verbeux
  -h, --help          Afficher cette aide

${YELLOW}Types de backup:${NC}
  full                Backup complet (etcd + ressources + certificats + configs)
  etcd                Backup etcd uniquement (rapide)
  resources           Backup ressources Kubernetes uniquement

${YELLOW}Exemples:${NC}
  # Backup complet (recommandé)
  $0

  # Backup etcd seulement (rapide pour sauvegarde fréquente)
  $0 --type etcd

  # Backup avec rétention de 30 jours
  $0 --retention 30

  # Simulation
  $0 --dry-run

${CYAN}════════════════════════════════════════════════════════════════${NC}
EOF
}

log_step() {
    echo -e "${CYAN}[$(date +%H:%M:%S)]${NC} $1"
    [ -n "${LOG_FILE:-}" ] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log_ok() {
    echo -e "${GREEN}✓${NC} $1"
    [ -n "${LOG_FILE:-}" ] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] [OK] $1" >> "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    [ -n "${LOG_FILE:-}" ] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] [WARN] $1" >> "$LOG_FILE"
}

log_fail() {
    echo -e "${RED}✗${NC} $1"
    [ -n "${LOG_FILE:-}" ] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] [FAIL] $1" >> "$LOG_FILE"
}

################################################################################
# FONCTIONS DE BACKUP
################################################################################

# Créer la structure de répertoires
create_backup_structure() {
    if [ "$DRY_RUN" = true ]; then
        log_step "DRY-RUN: Création structure $BACKUP_DIR"
        return 0
    fi

    mkdir -p "$BACKUP_DIR"/{etcd,certificates,kubernetes-configs,resources,addons,manifests}
    log_ok "Structure créée: $BACKUP_DIR"
}

# Backup etcd
backup_etcd() {
    log_step "Backup etcd..."

    if [ "$DRY_RUN" = true ]; then
        log_step "DRY-RUN: Sauvegarde etcd"
        return 0
    fi

    # Vérifier que etcdctl est disponible
    if ! command -v etcdctl &> /dev/null; then
        log_fail "etcdctl non trouvé - Installation de etcd-client"
        apt-get update && apt-get install -y etcd-client
    fi

    # Trouver les certificats etcd
    local etcd_ca="/etc/kubernetes/pki/etcd/ca.crt"
    local etcd_cert="/etc/kubernetes/pki/etcd/server.crt"
    local etcd_key="/etc/kubernetes/pki/etcd/server.key"

    if [ ! -f "$etcd_ca" ] || [ ! -f "$etcd_cert" ] || [ ! -f "$etcd_key" ]; then
        log_fail "Certificats etcd introuvables"
        return 1
    fi

    # Créer le snapshot etcd
    ETCDCTL_API=3 etcdctl snapshot save "$BACKUP_DIR/etcd/snapshot.db" \
        --endpoints=https://127.0.0.1:2379 \
        --cacert="$etcd_ca" \
        --cert="$etcd_cert" \
        --key="$etcd_key"

    # Vérifier le snapshot
    ETCDCTL_API=3 etcdctl snapshot status "$BACKUP_DIR/etcd/snapshot.db" \
        --write-out=table > "$BACKUP_DIR/etcd/snapshot-status.txt"

    log_ok "Snapshot etcd créé: $(du -h "$BACKUP_DIR/etcd/snapshot.db" | cut -f1)"
}

# Backup certificats
backup_certificates() {
    log_step "Backup certificats PKI..."

    if [ "$DRY_RUN" = true ]; then
        log_step "DRY-RUN: Sauvegarde certificats"
        return 0
    fi

    if [ -d /etc/kubernetes/pki ]; then
        tar -czf "$BACKUP_DIR/certificates/pki.tar.gz" -C /etc/kubernetes pki
        log_ok "Certificats PKI sauvegardés"
    else
        log_warn "Répertoire PKI introuvable"
    fi
}

# Backup configurations Kubernetes
backup_k8s_configs() {
    log_step "Backup configurations Kubernetes..."

    if [ "$DRY_RUN" = true ]; then
        log_step "DRY-RUN: Sauvegarde configs K8s"
        return 0
    fi

    # Sauvegarder admin.conf
    if [ -f /etc/kubernetes/admin.conf ]; then
        cp /etc/kubernetes/admin.conf "$BACKUP_DIR/kubernetes-configs/"
        log_ok "admin.conf sauvegardé"
    fi

    # Sauvegarder manifests statiques
    if [ -d /etc/kubernetes/manifests ]; then
        cp -r /etc/kubernetes/manifests "$BACKUP_DIR/kubernetes-configs/"
        log_ok "Manifests statiques sauvegardés"
    fi

    # Sauvegarder kubeadm-config
    if kubectl get cm kubeadm-config -n kube-system &> /dev/null; then
        kubectl get cm kubeadm-config -n kube-system -o yaml > "$BACKUP_DIR/kubernetes-configs/kubeadm-config.yaml"
        log_ok "kubeadm-config sauvegardé"
    fi
}

# Backup ressources Kubernetes
backup_k8s_resources() {
    log_step "Backup ressources Kubernetes..."

    if [ "$DRY_RUN" = true ]; then
        log_step "DRY-RUN: Sauvegarde ressources K8s"
        return 0
    fi

    # Vérifier que kubectl fonctionne
    if ! kubectl cluster-info &> /dev/null; then
        log_fail "Impossible de se connecter au cluster"
        return 1
    fi

    # Sauvegarder tous les namespaces
    kubectl get namespaces -o yaml > "$BACKUP_DIR/resources/namespaces.yaml"
    log_ok "Namespaces sauvegardés"

    # Sauvegarder les ressources par namespace
    local namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}')

    for ns in $namespaces; do
        [ "$VERBOSE" = true ] && log_step "  Namespace: $ns"

        mkdir -p "$BACKUP_DIR/resources/$ns"

        # Sauvegarder différents types de ressources
        for resource in pods deployments statefulsets daemonsets services configmaps secrets \
                        persistentvolumeclaims ingresses networkpolicies serviceaccounts \
                        roles rolebindings; do

            if kubectl get "$resource" -n "$ns" &> /dev/null; then
                kubectl get "$resource" -n "$ns" -o yaml > "$BACKUP_DIR/resources/$ns/${resource}.yaml" 2>/dev/null || true
            fi
        done
    done

    log_ok "Ressources Kubernetes sauvegardées"

    # Sauvegarder ressources cluster-wide
    log_step "Backup ressources cluster-wide..."
    mkdir -p "$BACKUP_DIR/resources/cluster-wide"

    for resource in clusterroles clusterrolebindings persistentvolumes storageclasses \
                    customresourcedefinitions; do
        kubectl get "$resource" -o yaml > "$BACKUP_DIR/resources/cluster-wide/${resource}.yaml" 2>/dev/null || true
    done

    log_ok "Ressources cluster-wide sauvegardées"
}

# Backup add-ons spécifiques
backup_addons() {
    log_step "Backup add-ons..."

    if [ "$DRY_RUN" = true ]; then
        log_step "DRY-RUN: Sauvegarde add-ons"
        return 0
    fi

    # MetalLB
    if kubectl get namespace metallb-system &> /dev/null; then
        kubectl get all,configmaps,secrets -n metallb-system -o yaml > "$BACKUP_DIR/addons/metallb.yaml"
        log_ok "MetalLB sauvegardé"
    fi

    # Rancher
    if kubectl get namespace cattle-system &> /dev/null; then
        kubectl get all,configmaps,secrets -n cattle-system -o yaml > "$BACKUP_DIR/addons/rancher.yaml" 2>/dev/null || true
        log_ok "Rancher sauvegardé"
    fi

    # cert-manager
    if kubectl get namespace cert-manager &> /dev/null; then
        kubectl get all,configmaps,secrets -n cert-manager -o yaml > "$BACKUP_DIR/addons/cert-manager.yaml"
        log_ok "cert-manager sauvegardé"
    fi

    # Monitoring (Prometheus + Grafana)
    if kubectl get namespace monitoring &> /dev/null; then
        kubectl get all,configmaps,secrets,servicemonitors,prometheusrules -n monitoring -o yaml > "$BACKUP_DIR/addons/monitoring.yaml" 2>/dev/null || true
        log_ok "Monitoring sauvegardé"
    fi

    # Calico
    if kubectl get namespace calico-system &> /dev/null; then
        kubectl get all,configmaps -n calico-system -o yaml > "$BACKUP_DIR/addons/calico.yaml" 2>/dev/null || true
        log_ok "Calico sauvegardé"
    fi
}

# Créer les métadonnées du backup
create_backup_metadata() {
    log_step "Création métadonnées..."

    if [ "$DRY_RUN" = true ]; then
        log_step "DRY-RUN: Création métadonnées"
        return 0
    fi

    cat > "$BACKUP_DIR/backup-metadata.txt" <<EOF
Backup Kubernetes Cluster
=========================

Date: $(date)
Hostname: $(hostname)
Backup Type: $BACKUP_TYPE
Kubernetes Version: $(kubectl version --short 2>/dev/null | grep Server || echo "N/A")

Cluster Info:
-------------
$(kubectl cluster-info 2>/dev/null || echo "N/A")

Nodes:
------
$(kubectl get nodes -o wide 2>/dev/null || echo "N/A")

Namespaces:
-----------
$(kubectl get namespaces 2>/dev/null || echo "N/A")

Backup Size:
------------
$(du -sh "$BACKUP_DIR" 2>/dev/null || echo "N/A")
EOF

    log_ok "Métadonnées créées"
}

# Compresser le backup
compress_backup() {
    log_step "Compression du backup..."

    if [ "$DRY_RUN" = true ]; then
        log_step "DRY-RUN: Compression backup"
        return 0
    fi

    cd "$BACKUP_BASE_DIR"
    tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"

    local size=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)
    log_ok "Backup compressé: ${BACKUP_NAME}.tar.gz ($size)"

    # Supprimer le répertoire non compressé
    rm -rf "$BACKUP_NAME"
}

# Nettoyer les anciens backups
cleanup_old_backups() {
    log_step "Nettoyage des backups (rétention: $BACKUP_RETENTION_DAYS jours)..."

    if [ "$DRY_RUN" = true ]; then
        log_step "DRY-RUN: Nettoyage anciens backups"
        local old_backups=$(find "$BACKUP_BASE_DIR" -name "k8s-backup-*.tar.gz" -mtime +$BACKUP_RETENTION_DAYS 2>/dev/null || true)
        if [ -n "$old_backups" ]; then
            echo "$old_backups" | while read -r backup; do
                log_step "  Supprimerait: $(basename "$backup")"
            done
        fi
        return 0
    fi

    local deleted_count=0
    find "$BACKUP_BASE_DIR" -name "k8s-backup-*.tar.gz" -mtime +$BACKUP_RETENTION_DAYS -exec rm -f {} \; 2>/dev/null || true
    deleted_count=$(find "$BACKUP_BASE_DIR" -name "k8s-backup-*.tar.gz" -mtime +$BACKUP_RETENTION_DAYS 2>/dev/null | wc -l)

    if [ "$deleted_count" -gt 0 ]; then
        log_ok "$deleted_count ancien(s) backup(s) supprimé(s)"
    else
        log_ok "Aucun backup à supprimer"
    fi
}

################################################################################
# MAIN
################################################################################

# Parser les arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --type)
            BACKUP_TYPE="$2"
            shift 2
            ;;
        --dir)
            BACKUP_BASE_DIR="$2"
            shift 2
            ;;
        --retention)
            BACKUP_RETENTION_DAYS="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
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

# Vérifier les permissions root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Ce script doit être exécuté en tant que root${NC}"
   exit 1
fi

# Afficher le header
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Backup Cluster Kubernetes HA${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Type de backup: $BACKUP_TYPE"
echo "  Destination: $BACKUP_BASE_DIR"
echo "  Rétention: $BACKUP_RETENTION_DAYS jours"
[ "$DRY_RUN" = true ] && echo -e "  ${YELLOW}Mode: DRY-RUN (simulation)${NC}"
echo ""

# Créer le répertoire de base
mkdir -p "$BACKUP_BASE_DIR"

# Mettre à jour les variables avec le nouveau base dir
BACKUP_DIR="$BACKUP_BASE_DIR/$BACKUP_NAME"

# Exécuter le backup selon le type
case "$BACKUP_TYPE" in
    full)
        log_step "Démarrage du backup COMPLET..."
        create_backup_structure
        backup_etcd
        backup_certificates
        backup_k8s_configs
        backup_k8s_resources
        backup_addons
        create_backup_metadata
        compress_backup
        cleanup_old_backups
        ;;
    etcd)
        log_step "Démarrage du backup ETCD..."
        create_backup_structure
        backup_etcd
        create_backup_metadata
        compress_backup
        cleanup_old_backups
        ;;
    resources)
        log_step "Démarrage du backup RESSOURCES..."
        create_backup_structure
        backup_k8s_resources
        backup_addons
        create_backup_metadata
        compress_backup
        cleanup_old_backups
        ;;
    *)
        echo -e "${RED}Type de backup invalide: $BACKUP_TYPE${NC}"
        show_usage
        exit 1
        ;;
esac

# Résumé final
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Backup terminé avec succès${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

if [ "$DRY_RUN" = false ]; then
    echo -e "${YELLOW}Résumé:${NC}"
    echo "  Fichier: ${BACKUP_NAME}.tar.gz"
    echo "  Taille: $(du -h "$BACKUP_BASE_DIR/${BACKUP_NAME}.tar.gz" 2>/dev/null | cut -f1 || echo "N/A")"
    echo "  Emplacement: $BACKUP_BASE_DIR"
    echo ""
    echo -e "${YELLOW}Pour restaurer ce backup:${NC}"
    echo "  ./restore-cluster.sh $BACKUP_BASE_DIR/${BACKUP_NAME}.tar.gz"
    echo ""
else
    echo -e "${YELLOW}Mode DRY-RUN - Aucune modification effectuée${NC}"
    echo ""
fi

echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
