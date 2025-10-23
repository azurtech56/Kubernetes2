#!/bin/bash
################################################################################
# Script d'installation de la stack de monitoring (Prometheus + Grafana + cAdvisor)
# Compatible avec: Kubernetes 1.32
# Auteur: Kubernetes HA Setup
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

echo -e "${YELLOW}[1/5] Création du namespace monitoring...${NC}"
kubectl create namespace monitoring || echo "Namespace déjà existant"
echo -e "${GREEN}✓ Namespace créé${NC}"

echo -e "${YELLOW}[2/5] Installation de cAdvisor...${NC}"

cat > cadvisor.yaml <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: cadvisor
  namespace: monitoring
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
  adminPassword: prom-operator
  service:
    type: LoadBalancer
EOF

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f prometheus-values.yaml

echo -e "${GREEN}✓ Prometheus et Grafana installés${NC}"

echo -e "${YELLOW}[5/5] Attente du démarrage des services...${NC}"
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=grafana -n monitoring --timeout=180s || true
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=prometheus -n monitoring --timeout=180s || true

echo -e "${GREEN}✓ Services démarrés${NC}"

echo ""
echo -e "${YELLOW}Récupération du mot de passe Grafana...${NC}"
GRAFANA_PASSWORD=$(kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d)

echo ""
echo -e "${YELLOW}Services déployés:${NC}"
kubectl get pods -n monitoring
echo ""
kubectl get svc -n monitoring

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
echo "  kubectl get svc -n monitoring prometheus-grafana"
echo "  Utilisez l'IP External pour vous connecter sur le port 80"
echo ""
echo -e "${YELLOW}Dashboards Grafana recommandés:${NC}"
echo "  - Kubernetes / Compute Resources / Cluster"
echo "  - Kubernetes / Compute Resources / Node (Pods)"
echo "  - Node Exporter / Nodes"
