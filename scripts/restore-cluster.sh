#!/bin/bash
################################################################################
# Script de restauration du cluster Kubernetes
# Restaure: etcd, certificats, configurations, ressources Kubernetes, add-ons
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
BACKUP_FILE=""
RESTORE_TYPE="full"  # full, etcd, resources
TEMP_RESTORE_DIR="/tmp/k8s-restore-$$"
DRY_RUN=false
VERBOSE=false
SKIP_CONFIRMATION=false

# Initialiser le logging
init_logging 2>/dev/null || true

################################################################################
# FONCTIONS UTILITAIRES
################################################################################

show_usage() {
    cat <<EOF
${CYAN}════════════════════════════════════════════════════════════════${NC}
  Restauration du cluster Kubernetes HA
${CYAN}════════════════════════════════════════════════════════════════${NC}

${YELLOW}Usage:${NC}
  $0 <backup_file> [options]

${YELLOW}Arguments:${NC}
  backup_file         Fichier de backup (.tar.gz)

${YELLOW}Options:${NC}
  --type <type>       Type de restauration: full (défaut), etcd, resources
  --dry-run           Simulation sans restaurer
  --yes               Ne pas demander de confirmation
  --verbose           Mode verbeux
  --list-backups      Lister les backups disponibles
  -h, --help          Afficher cette aide

${YELLOW}Types de restauration:${NC}
  full                Restauration complète (etcd + ressources + configs)
  etcd                Restauration etcd uniquement
  resources           Restauration ressources Kubernetes uniquement

${YELLOW}Exemples:${NC}
  # Lister les backups disponibles
  $0 --list-backups

  # Restauration complète
  $0 /var/backups/k8s-cluster/k8s-backup-20250115_120000.tar.gz

  # Restauration etcd uniquement
  $0 /var/backups/k8s-cluster/k8s-backup-20250115_120000.tar.gz --type etcd

  # Simulation
  $0 /var/backups/k8s-cluster/k8s-backup-20250115_120000.tar.gz --dry-run

${RED}⚠️  AVERTISSEMENT:${NC}
  La restauration peut ÉCRASER les données existantes du cluster.
  Assurez-vous d'avoir un backup récent avant de procéder.
  Utilisez --dry-run pour simuler d'abord.

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

# Lister les backups disponibles
list_backups() {
    local backup_dir="${BACKUP_DIR:-/var/backups/k8s-cluster}"

    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Backups disponibles${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""

    if [ ! -d "$backup_dir" ]; then
        echo -e "${YELLOW}Aucun répertoire de backup trouvé: $backup_dir${NC}"
        return 0
    fi

    local backups=$(find "$backup_dir" -name "k8s-backup-*.tar.gz" -type f 2>/dev/null | sort -r)

    if [ -z "$backups" ]; then
        echo -e "${YELLOW}Aucun backup trouvé dans: $backup_dir${NC}"
        return 0
    fi

    echo -e "${YELLOW}Répertoire: $backup_dir${NC}"
    echo ""
    printf "%-40s %-15s %-20s\n" "FICHIER" "TAILLE" "DATE"
    echo "────────────────────────────────────────────────────────────────────────"

    echo "$backups" | while read -r backup; do
        local filename=$(basename "$backup")
        local size=$(du -h "$backup" | cut -f1)
        local date=$(stat -c %y "$backup" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1)
        printf "%-40s %-15s %-20s\n" "$filename" "$size" "$date"
    done

    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
}

# Confirmation utilisateur
confirm_restore() {
    if [ "$SKIP_CONFIRMATION" = true ] || [ "$DRY_RUN" = true ]; then
        return 0
    fi

    echo ""
    echo -e "${RED}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}⚠️  AVERTISSEMENT - Confirmation requise${NC}"
    echo -e "${RED}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Vous allez restaurer le cluster Kubernetes depuis:${NC}"
    echo "  Backup: $(basename "$BACKUP_FILE")"
    echo "  Type: $RESTORE_TYPE"
    echo ""
    echo -e "${RED}Cette opération peut ÉCRASER les données existantes !${NC}"
    echo ""
    read -p "Êtes-vous sûr de vouloir continuer ? (tapez 'oui' pour confirmer): " confirm

    if [ "$confirm" != "oui" ]; then
        echo ""
        echo -e "${YELLOW}Restauration annulée par l'utilisateur${NC}"
        exit 0
    fi

    echo ""
}

################################################################################
# FONCTIONS DE RESTAURATION
################################################################################

# Extraire le backup
extract_backup() {
    log_step "Extraction du backup..."

    if [ "$DRY_RUN" = true ]; then
        log_step "DRY-RUN: Extraction backup"
        return 0
    fi

    # Vérifier que le fichier existe
    if [ ! -f "$BACKUP_FILE" ]; then
        log_fail "Fichier de backup introuvable: $BACKUP_FILE"
        exit 1
    fi

    # Créer le répertoire temporaire
    mkdir -p "$TEMP_RESTORE_DIR"

    # Extraire l'archive
    tar -xzf "$BACKUP_FILE" -C "$TEMP_RESTORE_DIR"

    # Trouver le répertoire extrait
    local extracted_dir=$(find "$TEMP_RESTORE_DIR" -maxdepth 1 -type d -name "k8s-backup-*" | head -n1)

    if [ -z "$extracted_dir" ]; then
        log_fail "Structure de backup invalide"
        cleanup_temp_dir
        exit 1
    fi

    # Déplacer le contenu à la racine du temp dir
    mv "$extracted_dir"/* "$TEMP_RESTORE_DIR/" 2>/dev/null || true
    rmdir "$extracted_dir" 2>/dev/null || true

    log_ok "Backup extrait: $TEMP_RESTORE_DIR"
}

# Afficher les métadonnées du backup
show_backup_metadata() {
    if [ -f "$TEMP_RESTORE_DIR/backup-metadata.txt" ]; then
        echo ""
        echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}  Informations du backup${NC}"
        echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
        cat "$TEMP_RESTORE_DIR/backup-metadata.txt"
        echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
        echo ""
    fi
}

# Restaurer etcd
restore_etcd() {
    log_step "Restauration etcd..."

    if [ "$DRY_RUN" = true ]; then
        log_step "DRY-RUN: Restauration etcd"
        return 0
    fi

    local snapshot_file="$TEMP_RESTORE_DIR/etcd/snapshot.db"

    if [ ! -f "$snapshot_file" ]; then
        log_fail "Snapshot etcd introuvable dans le backup"
        return 1
    fi

    # Arrêter etcd (via kube-apiserver)
    log_step "Arrêt temporaire de l'API server..."
    mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/kube-apiserver.yaml.backup 2>/dev/null || true
    mv /etc/kubernetes/manifests/etcd.yaml /tmp/etcd.yaml.backup 2>/dev/null || true

    sleep 10

    # Sauvegarder l'etcd actuel
    if [ -d /var/lib/etcd ]; then
        mv /var/lib/etcd "/var/lib/etcd.backup-$(date +%Y%m%d_%H%M%S)"
        log_ok "Ancien etcd sauvegardé"
    fi

    # Restaurer depuis le snapshot
    ETCDCTL_API=3 etcdctl snapshot restore "$snapshot_file" \
        --data-dir=/var/lib/etcd \
        --initial-cluster-token=etcd-cluster-0 \
        --initial-advertise-peer-urls=https://$(hostname -i):2380 \
        --name=$(hostname)

    # Restaurer les permissions
    chown -R root:root /var/lib/etcd
    chmod 700 /var/lib/etcd

    # Redémarrer etcd et l'API server
    log_step "Redémarrage de l'API server..."
    mv /tmp/etcd.yaml.backup /etc/kubernetes/manifests/etcd.yaml 2>/dev/null || true
    mv /tmp/kube-apiserver.yaml.backup /etc/kubernetes/manifests/kube-apiserver.yaml 2>/dev/null || true

    # Attendre que le cluster soit prêt
    log_step "Attente du redémarrage du cluster..."
    local retries=0
    while [ $retries -lt 30 ]; do
        if kubectl cluster-info &> /dev/null; then
            log_ok "Cluster opérationnel"
            break
        fi
        sleep 2
        ((retries++))
    done

    if [ $retries -eq 30 ]; then
        log_fail "Timeout - Cluster non opérationnel après restauration etcd"
        return 1
    fi

    log_ok "etcd restauré avec succès"
}

# Restaurer certificats
restore_certificates() {
    log_step "Restauration certificats PKI..."

    if [ "$DRY_RUN" = true ]; then
        log_step "DRY-RUN: Restauration certificats"
        return 0
    fi

    local pki_archive="$TEMP_RESTORE_DIR/certificates/pki.tar.gz"

    if [ ! -f "$pki_archive" ]; then
        log_warn "Certificats PKI introuvables dans le backup"
        return 0
    fi

    # Sauvegarder les certificats actuels
    if [ -d /etc/kubernetes/pki ]; then
        mv /etc/kubernetes/pki "/etc/kubernetes/pki.backup-$(date +%Y%m%d_%H%M%S)"
        log_ok "Anciens certificats sauvegardés"
    fi

    # Restaurer les certificats
    tar -xzf "$pki_archive" -C /etc/kubernetes/

    log_ok "Certificats PKI restaurés"
}

# Restaurer configurations Kubernetes
restore_k8s_configs() {
    log_step "Restauration configurations Kubernetes..."

    if [ "$DRY_RUN" = true ]; then
        log_step "DRY-RUN: Restauration configs K8s"
        return 0
    fi

    # Restaurer admin.conf
    if [ -f "$TEMP_RESTORE_DIR/kubernetes-configs/admin.conf" ]; then
        cp "$TEMP_RESTORE_DIR/kubernetes-configs/admin.conf" /etc/kubernetes/
        log_ok "admin.conf restauré"
    fi

    # Restaurer manifests statiques
    if [ -d "$TEMP_RESTORE_DIR/kubernetes-configs/manifests" ]; then
        cp -r "$TEMP_RESTORE_DIR/kubernetes-configs/manifests/"* /etc/kubernetes/manifests/ 2>/dev/null || true
        log_ok "Manifests statiques restaurés"
    fi

    # Restaurer kubeadm-config
    if [ -f "$TEMP_RESTORE_DIR/kubernetes-configs/kubeadm-config.yaml" ]; then
        kubectl apply -f "$TEMP_RESTORE_DIR/kubernetes-configs/kubeadm-config.yaml"
        log_ok "kubeadm-config restauré"
    fi
}

# Restaurer ressources Kubernetes
restore_k8s_resources() {
    log_step "Restauration ressources Kubernetes..."

    if [ "$DRY_RUN" = true ]; then
        log_step "DRY-RUN: Restauration ressources K8s"
        return 0
    fi

    # Vérifier que kubectl fonctionne
    if ! kubectl cluster-info &> /dev/null; then
        log_fail "Impossible de se connecter au cluster"
        return 1
    fi

    # Restaurer les namespaces
    if [ -f "$TEMP_RESTORE_DIR/resources/namespaces.yaml" ]; then
        kubectl apply -f "$TEMP_RESTORE_DIR/resources/namespaces.yaml" 2>/dev/null || true
        log_ok "Namespaces restaurés"
    fi

    # Restaurer ressources cluster-wide
    if [ -d "$TEMP_RESTORE_DIR/resources/cluster-wide" ]; then
        log_step "Restauration ressources cluster-wide..."
        for yaml_file in "$TEMP_RESTORE_DIR/resources/cluster-wide"/*.yaml; do
            [ -f "$yaml_file" ] && kubectl apply -f "$yaml_file" 2>/dev/null || true
        done
        log_ok "Ressources cluster-wide restaurées"
    fi

    # Restaurer ressources par namespace
    if [ -d "$TEMP_RESTORE_DIR/resources" ]; then
        log_step "Restauration ressources par namespace..."

        for ns_dir in "$TEMP_RESTORE_DIR/resources"/*; do
            if [ -d "$ns_dir" ]; then
                local ns=$(basename "$ns_dir")

                # Ignorer les répertoires spéciaux
                [ "$ns" = "cluster-wide" ] && continue

                [ "$VERBOSE" = true ] && log_step "  Namespace: $ns"

                # Attendre que le namespace existe
                local retries=0
                while [ $retries -lt 10 ]; do
                    if kubectl get namespace "$ns" &> /dev/null; then
                        break
                    fi
                    sleep 1
                    ((retries++))
                done

                # Restaurer les ressources du namespace
                for yaml_file in "$ns_dir"/*.yaml; do
                    [ -f "$yaml_file" ] && kubectl apply -f "$yaml_file" 2>/dev/null || true
                done
            fi
        done

        log_ok "Ressources par namespace restaurées"
    fi
}

# Restaurer add-ons
restore_addons() {
    log_step "Restauration add-ons..."

    if [ "$DRY_RUN" = true ]; then
        log_step "DRY-RUN: Restauration add-ons"
        return 0
    fi

    if [ ! -d "$TEMP_RESTORE_DIR/addons" ]; then
        log_warn "Aucun add-on dans le backup"
        return 0
    fi

    for addon_file in "$TEMP_RESTORE_DIR/addons"/*.yaml; do
        if [ -f "$addon_file" ]; then
            local addon_name=$(basename "$addon_file" .yaml)
            [ "$VERBOSE" = true ] && log_step "  Restauration: $addon_name"
            kubectl apply -f "$addon_file" 2>/dev/null || true
        fi
    done

    log_ok "Add-ons restaurés"
}

# Nettoyer le répertoire temporaire
cleanup_temp_dir() {
    if [ -d "$TEMP_RESTORE_DIR" ]; then
        rm -rf "$TEMP_RESTORE_DIR"
    fi
}

################################################################################
# MAIN
################################################################################

# Parser les arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --type)
            RESTORE_TYPE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --yes)
            SKIP_CONFIRMATION=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --list-backups)
            list_backups
            exit 0
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            echo "Option inconnue: $1"
            show_usage
            exit 1
            ;;
        *)
            BACKUP_FILE="$1"
            shift
            ;;
    esac
done

# Vérifier qu'un fichier de backup a été fourni
if [ -z "$BACKUP_FILE" ]; then
    echo -e "${RED}Erreur: Aucun fichier de backup spécifié${NC}"
    echo ""
    show_usage
    exit 1
fi

# Vérifier les permissions root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Ce script doit être exécuté en tant que root${NC}"
   exit 1
fi

# Afficher le header
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Restauration Cluster Kubernetes HA${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Backup: $(basename "$BACKUP_FILE")"
echo "  Type de restauration: $RESTORE_TYPE"
[ "$DRY_RUN" = true ] && echo -e "  ${YELLOW}Mode: DRY-RUN (simulation)${NC}"
echo ""

# Trap pour nettoyer en cas d'erreur
trap cleanup_temp_dir EXIT

# Extraire le backup
extract_backup

# Afficher les métadonnées
if [ "$DRY_RUN" = false ]; then
    show_backup_metadata
fi

# Demander confirmation
confirm_restore

# Exécuter la restauration selon le type
case "$RESTORE_TYPE" in
    full)
        log_step "Démarrage de la restauration COMPLÈTE..."
        restore_etcd
        restore_certificates
        restore_k8s_configs
        restore_k8s_resources
        restore_addons
        ;;
    etcd)
        log_step "Démarrage de la restauration ETCD..."
        restore_etcd
        ;;
    resources)
        log_step "Démarrage de la restauration RESSOURCES..."
        restore_k8s_resources
        restore_addons
        ;;
    *)
        echo -e "${RED}Type de restauration invalide: $RESTORE_TYPE${NC}"
        show_usage
        exit 1
        ;;
esac

# Résumé final
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
if [ "$DRY_RUN" = false ]; then
    echo -e "${GREEN}✓ Restauration terminée avec succès${NC}"
else
    echo -e "${YELLOW}Mode DRY-RUN - Aucune modification effectuée${NC}"
fi
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

if [ "$DRY_RUN" = false ]; then
    echo -e "${YELLOW}Prochaines étapes:${NC}"
    echo "  1. Vérifier l'état du cluster: kubectl get nodes"
    echo "  2. Vérifier les pods: kubectl get pods --all-namespaces"
    echo "  3. Vérifier les services: kubectl get svc --all-namespaces"
    echo ""
fi

echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
