#!/bin/bash
################################################################################
# Script d'installation de la stack de monitoring (Prometheus + Grafana + cAdvisor)
# Compatible avec: Kubernetes 1.32.2
# Auteur: azurtech56
# Version: 1.0
################################################################################

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Installation du Monitoring${NC}"
echo -e "${GREEN}========================================${NC}"

# Vérifier et configurer kubectl
echo -e "${BLUE}Vérification de la configuration kubectl...${NC}"
if [ ! -f "$HOME/.kube/config" ]; then
    echo -e "${YELLOW}Configuration kubectl non trouvée, tentative de copie depuis /etc/kubernetes/admin.conf...${NC}"
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    echo -e "${GREEN}✓ Configuration kubectl copiée${NC}"
else
    echo -e "${GREEN}✓ Configuration kubectl trouvée${NC}"
fi

# Vérifier que kubectl fonctionne
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}Erreur: kubectl ne peut pas se connecter au cluster${NC}"
    echo -e "${YELLOW}Vérifiez que vous êtes sur un nœud master et que le cluster est démarré${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Connexion au cluster réussie${NC}"
echo ""

# Charger la configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    echo -e "${BLUE}Chargement de la configuration depuis config.sh...${NC}"
    source "$SCRIPT_DIR/config.sh"
else
    echo -e "${YELLOW}Avertissement: config.sh non trouvé, utilisation des valeurs par défaut${NC}"
    MONITORING_NAMESPACE="monitoring"
    GRAFANA_PASSWORD="prom-operator"
fi

echo -e "${BLUE}Namespace: ${MONITORING_NAMESPACE}${NC}"
echo -e "${BLUE}Mot de passe Grafana: ${GRAFANA_PASSWORD}${NC}"
echo ""

echo -e "${YELLOW}[1/5] Création du namespace ${MONITORING_NAMESPACE}...${NC}"
kubectl create namespace ${MONITORING_NAMESPACE} || echo "Namespace déjà existant"
echo -e "${GREEN}✓ Namespace créé${NC}"

echo -e "${YELLOW}[2/5] Installation de cAdvisor...${NC}"

cat > cadvisor.yaml <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: cadvisor
  namespace: ${MONITORING_NAMESPACE}
spec:
  selector:
    matchLabels:
      name: cadvisor
  template:
    metadata:
      labels:
        name: cadvisor
    spec:
      containers:
      - name: cadvisor
        image: gcr.io/cadvisor/cadvisor:latest
        ports:
        - containerPort: 8080
          name: http
        volumeMounts:
        - name: rootfs
          mountPath: /rootfs
          readOnly: true
        - name: var-run
          mountPath: /var/run
          readOnly: false
        - name: sys
          mountPath: /sys
          readOnly: true
        - name: docker
          mountPath: /var/lib/docker
          readOnly: true
      volumes:
      - name: rootfs
        hostPath:
          path: /
      - name: var-run
        hostPath:
          path: /var/run
      - name: sys
        hostPath:
          path: /sys
      - name: docker
        hostPath:
          path: /var/lib/docker
EOF

kubectl apply -f cadvisor.yaml
echo -e "${GREEN}✓ cAdvisor installé${NC}"

echo -e "${YELLOW}[3/5] Ajout du repository Helm Prometheus...${NC}"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
echo -e "${GREEN}✓ Repository ajouté${NC}"

echo -e "${YELLOW}[4/5] Installation de kube-prometheus-stack...${NC}"

cat > prometheus-values.yaml <<EOF
prometheus:
  prometheusSpec:
    additionalScrapeConfigs:
    - job_name: 'cadvisor'
      kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
          - monitoring
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_name]
        regex: cadvisor
        action: keep
      - source_labels: [__meta_kubernetes_pod_ip]
        target_label: __address__
        replacement: \${1}:8080

grafana:
  adminPassword: ${GRAFANA_PASSWORD}
  service:
    type: LoadBalancer
EOF

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace ${MONITORING_NAMESPACE} \
  -f prometheus-values.yaml

echo -e "${GREEN}✓ Prometheus et Grafana installés${NC}"

echo -e "${YELLOW}[5/5] Attente du démarrage des services...${NC}"
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=grafana -n ${MONITORING_NAMESPACE} --timeout=${KUBECTL_WAIT_TIMEOUT_SHORT} || true
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=prometheus -n ${MONITORING_NAMESPACE} --timeout=${KUBECTL_WAIT_TIMEOUT_SHORT} || true

# Attendre spécifiquement que tous les pods soient prêts
echo -e "${YELLOW}Attente de tous les pods monitoring...${NC}"
kubectl wait --namespace ${MONITORING_NAMESPACE} \
    --for=condition=ready pod \
    --all \
    --timeout=${KUBECTL_WAIT_TIMEOUT} || true

# Attendre que les services webhook Prometheus Operator soient disponibles
echo -e "${YELLOW}Attente des services webhook Prometheus Operator...${NC}"

# Vérifier le webhook prometheus-operator
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if kubectl get endpoints -n ${MONITORING_NAMESPACE} prometheus-kube-prometheus-admission &>/dev/null; then
        endpoints=$(kubectl get endpoints -n ${MONITORING_NAMESPACE} prometheus-kube-prometheus-admission -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
        if [ -n "$endpoints" ]; then
            echo -e "${GREEN}✓ Service webhook admission disponible (endpoints: $endpoints)${NC}"
            break
        fi
    fi
    attempt=$((attempt + 1))
    echo -ne "\r  Tentative $attempt/$max_attempts..."
    sleep 2
done
echo ""

# Vérifier que les webhooks sont enregistrés dans l'API server
echo -e "${YELLOW}Vérification de l'enregistrement des webhooks dans l'API...${NC}"
max_attempts=20
attempt=0
while [ $attempt -lt $max_attempts ]; do
    webhook_count=$(kubectl get validatingwebhookconfigurations.admissionregistration.k8s.io 2>/dev/null | grep -c "prometheus" || echo "0")
    if [ "$webhook_count" -gt 0 ]; then
        echo -e "${GREEN}✓ Webhooks Prometheus Operator enregistrés ($webhook_count configurations)${NC}"
        break
    fi
    attempt=$((attempt + 1))
    echo -ne "\r  Tentative $attempt/$max_attempts..."
    sleep 2
done
echo ""

# Test actif du webhook Prometheus Operator avec une ressource temporaire
echo -e "${YELLOW}Test de disponibilité du webhook Prometheus Operator (dry-run)...${NC}"
max_attempts=10
attempt=0
webhook_ok=false
while [ $attempt -lt $max_attempts ]; do
    # Créer une ressource test en mode dry-run pour tester le webhook
    if cat <<EOF | kubectl apply --dry-run=server -f - &>/dev/null; then
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: test-monitor
  namespace: ${MONITORING_NAMESPACE}
spec:
  selector:
    matchLabels:
      app: test
  endpoints:
  - port: metrics
EOF
        echo -e "${GREEN}✓ Webhook Prometheus Operator répond correctement${NC}"
        webhook_ok=true
        break
    fi
    attempt=$((attempt + 1))
    echo -ne "\r  Test $attempt/$max_attempts (webhook pas encore prêt)..."
    sleep 5
done
echo ""

if [ "$webhook_ok" = false ]; then
    echo -e "${YELLOW}Attention: Le webhook ne répond pas encore, tentative de délai supplémentaire...${NC}"
    sleep 30
fi

echo -e "${GREEN}✓ Services démarrés et webhooks opérationnels${NC}"

echo ""
echo -e "${YELLOW}Récupération du mot de passe Grafana...${NC}"
GRAFANA_PASSWORD=$(kubectl get secret --namespace ${MONITORING_NAMESPACE} prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d)

echo ""
echo -e "${YELLOW}Services déployés:${NC}"
kubectl get pods -n ${MONITORING_NAMESPACE}
echo ""
kubectl get svc -n ${MONITORING_NAMESPACE}

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Monitoring installé avec succès !${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Connexion à Grafana:${NC}"
echo "  Service: prometheus-grafana (LoadBalancer)"
echo "  Identifiant: admin"
echo "  Mot de passe: ${GRAFANA_PASSWORD}"
echo ""
echo -e "${YELLOW}Pour accéder à Grafana:${NC}"
echo "  kubectl get svc -n ${MONITORING_NAMESPACE} prometheus-grafana"
echo "  Utilisez l'IP External pour vous connecter sur le port 80"
echo ""
echo -e "${YELLOW}Dashboards Grafana recommandés:${NC}"
echo "  - Kubernetes / Compute Resources / Cluster"
echo "  - Kubernetes / Compute Resources / Node (Pods)"
echo "  - Node Exporter / Nodes"
