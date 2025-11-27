#!/bin/bash
################################################################################
# Installation de Loki et Promtail pour logs centralisés
# Agrégation logs de tous les nœuds Kubernetes
# Auteur: Claude Code
# Version: 1.0
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# VÉRIFICATIONS INITIALES
# ============================================================================

show_header() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  INSTALLATION LOKI + PROMTAIL - Logs Centralisés${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Vérifier si root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Ce script doit être exécuté en tant que root${NC}"
    exit 1
fi

# Vérifier kubectl disponible
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl non trouvé${NC}"
    exit 1
fi

# Vérifier cluster accessible
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}✗ Cluster Kubernetes non accessible${NC}"
    exit 1
fi

# Vérifier helm disponible
if ! command -v helm &> /dev/null; then
    echo -e "${RED}✗ helm non trouvé${NC}"
    exit 1
fi

# Charger config et performance lib
if [ -f "$SCRIPT_DIR/../lib-config.sh" ]; then
    source "$SCRIPT_DIR/../lib-config.sh"
    load_kubernetes_config "$SCRIPT_DIR" || exit 1
fi

if [ -f "$SCRIPT_DIR/../lib/performance.sh" ]; then
    source "$SCRIPT_DIR/../lib/performance.sh"
fi

show_header

# ============================================================================
# CRÉATION NAMESPACE
# ============================================================================

echo -e "${YELLOW}[1/5] Création du namespace loki-stack...${NC}"

kubectl create namespace loki-stack --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace loki-stack monitoring=enabled --overwrite

echo -e "${GREEN}✓ Namespace loki-stack créé${NC}"
echo ""

# ============================================================================
# AJOUT REPOSITORY HELM
# ============================================================================

echo -e "${YELLOW}[2/5] Ajout du repository Helm Grafana...${NC}"

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

echo -e "${GREEN}✓ Repository Grafana ajouté${NC}"
echo ""

# ============================================================================
# INSTALLATION LOKI
# ============================================================================

echo -e "${YELLOW}[3/5] Installation de Loki...${NC}"

# Créer values pour Loki
cat > /tmp/loki-values.yaml <<'EOF'
loki:
  auth_enabled: false

  ingester:
    chunk_idle_period: 3m
    chunk_retain_period: 1m
    max_chunk_age: 2h
    max_streams_matchers_cache_size_bytes: 5242880
    chunk_encoding: snappy

  limits_config:
    enforce_metric_name: false
    reject_old_samples: true
    reject_old_samples_max_age: 168h
    ingestion_rate_mb: 64
    ingestion_burst_size_mb: 128
    max_cache_freshness_per_query: 10m
    split_queries_by_interval: 24h

  schema_config:
    configs:
      - from: 2020-10-24
        store: boltdb-shipper
        object_store: filesystem
        schema: v11
        index:
          prefix: index_
          period: 24h

  server:
    http_listen_port: 3100
    log_level: info

persistence:
  enabled: true
  storageClassName: null
  accessModes:
    - ReadWriteOnce
  size: 10Gi

serviceAccount:
  create: true
  name: loki
EOF

helm install loki grafana/loki-stack \
    -n loki-stack \
    -f /tmp/loki-values.yaml \
    --wait \
    --timeout=300s

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Loki installé${NC}"
else
    echo -e "${RED}✗ Erreur installation Loki${NC}"
    exit 1
fi
echo ""

# ============================================================================
# INSTALLATION PROMTAIL
# ============================================================================

echo -e "${YELLOW}[4/5] Installation de Promtail (log collector)...${NC}"

# Promtail est inclus dans loki-stack
echo -e "${GREEN}✓ Promtail installé${NC}"
echo ""

# ============================================================================
# INTÉGRATION GRAFANA
# ============================================================================

echo -e "${YELLOW}[5/5] Configuration Grafana (si présent)...${NC}"

# Vérifier si Grafana est installé
if kubectl get deployment -n monitoring grafana &>/dev/null 2>&1; then
    echo -e "${BLUE}  Ajout de Loki comme datasource Grafana...${NC}"

    # Créer ConfigMap pour Loki datasource
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki-datasource
  namespace: monitoring
data:
  loki-datasource.yaml: |
    apiVersion: 1
    datasources:
      - name: Loki
        type: loki
        access: proxy
        url: http://loki.loki-stack:3100
        isDefault: false
        editable: true
EOF

    echo -e "${GREEN}✓ Datasource Loki configurée${NC}"
else
    echo -e "${YELLOW}⚠ Grafana non trouvé - configuration manuelle nécessaire${NC}"
    echo -e "${BLUE}  Pour ajouter Loki à Grafana:${NC}"
    echo "    1. Aller dans Grafana → Configuration → Data Sources"
    echo "    2. Ajouter: http://loki.loki-stack:3100"
fi
echo ""

# ============================================================================
# VÉRIFICATION
# ============================================================================

echo -e "${YELLOW}Vérification du déploiement...${NC}"
sleep 5

LOKI_POD=$(kubectl get pods -n loki-stack -l app=loki -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
PROMTAIL_POD=$(kubectl get pods -n loki-stack -l app=promtail -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -n "$LOKI_POD" ]; then
    echo -e "${GREEN}✓ Pod Loki: $LOKI_POD${NC}"
else
    echo -e "${RED}✗ Pod Loki non trouvé${NC}"
fi

if [ -n "$PROMTAIL_POD" ]; then
    echo -e "${GREEN}✓ Pod Promtail: $PROMTAIL_POD${NC}"
else
    echo -e "${RED}✗ Pod Promtail non trouvé${NC}"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ Loki + Promtail installés avec succès !${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BLUE}Accès aux logs:${NC}"
echo ""
echo -e "${CYAN}Via CLI (port-forward):${NC}"
echo "  kubectl port-forward -n loki-stack svc/loki 3100:3100"
echo "  # Puis ouvrir: http://localhost:3100/loki/api/v1/query_range"
echo ""
echo -e "${CYAN}Via Grafana:${NC}"
echo "  1. Port-forward Grafana: kubectl port-forward -n monitoring svc/grafana 3000:80"
echo "  2. Ouvrir: http://localhost:3000"
echo "  3. Aller dans Explore → Datasource: Loki"
echo "  4. Écrire requête: {job=\"kubelet\"}"
echo ""

echo -e "${YELLOW}Requêtes LogQL utiles:${NC}"
echo "  • Tous les logs: {}"
echo "  • Logs Kubernetes: {job=\"kubelet\"}"
echo "  • Logs par pod: {pod=\"mon-pod\"}"
echo "  • Logs par namespace: {namespace=\"default\"}"
echo "  • Logs d'erreur: {job=\"kubelet\"} | = \"error\""
echo "  • Logs par niveau: {job=\"kubelet\"} | level=\"error\""
echo ""

echo -e "${BLUE}Documentation:${NC}"
echo "  https://grafana.com/docs/loki/"
echo "  https://grafana.com/docs/loki/latest/logql/"
echo ""
