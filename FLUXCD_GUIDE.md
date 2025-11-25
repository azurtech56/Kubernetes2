# 🔄 FluxCD - GitOps pour Kubernetes

## 📋 Qu'est-ce que FluxCD?

**FluxCD** est un **GitOps operator** pour Kubernetes qui synchronise automatiquement l'état de ton cluster avec un dépôt Git.

```
Git Repository (source of truth)
          ↓
    FluxCD Operator
          ↓
    Kubernetes Cluster (synchronisé automatiquement)
```

### Concept Core: GitOps

**GitOps = Infrastructure as Code + Git as Source of Truth**

Au lieu de faire:
```bash
# ❌ Ancien style (Imperative)
kubectl apply -f deployment.yaml
kubectl set image deployment/app app=app:v2
kubectl scale deployment/app --replicas=5
```

Avec FluxCD, tu fais:
```bash
# ✅ GitOps style (Declarative)
# 1. Définis l'état désiré dans Git
# 2. FluxCD synchronise automatiquement le cluster
# 3. Git = source de vérité unique
```

---

## 🏗️ Comment ça Marche?

### Architecture FluxCD

```
┌─────────────────────────────────────────────────────────┐
│                    Git Repository                       │
│  ┌──────────────────────────────────────────────────┐   │
│  │ /deploy/                                         │   │
│  │   ├─ deployments/                               │   │
│  │   │   ├─ app.yaml                               │   │
│  │   │   └─ api.yaml                               │   │
│  │   ├─ services/                                  │   │
│  │   │   └─ ingress.yaml                           │   │
│  │   └─ kustomization.yaml (references)            │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
          ↑
          │ (Poll or Webhook)
          │
┌─────────────────────────────────────────────────────────┐
│           Kubernetes Cluster (FluxCD Installed)         │
│  ┌──────────────────────────────────────────────────┐   │
│  │ flux-system Namespace                            │   │
│  │ ┌──────────────────────────────────────────────┐ │   │
│  │ │ FluxCD Controllers                           │ │   │
│  │ │ • source-controller (watch Git)              │ │   │
│  │ │ • kustomize-controller (build manifests)     │ │   │
│  │ │ • helm-controller (manage Helm releases)     │ │   │
│  │ │ • image-controller (auto-update images)      │ │   │
│  │ │ • notification-controller (webhooks/alerts)  │ │   │
│  │ └──────────────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────┘   │
│                      ↓                                  │
│  ┌──────────────────────────────────────────────────┐   │
│  │ Deployed Resources                              │   │
│  │ • Pods, Services, Deployments                   │   │
│  │ • Auto-synchronized with Git                    │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Flow de Synchronisation

```
1. Configure GitRepository CRD
   ↓
2. FluxCD source-controller
   • Clone le repo Git
   • Détecte les changements
   • Poll toutes les X minutes (default: 1min)
   ↓
3. kustomize-controller
   • Compile les manifests Kubernetes
   • Applique les transformations
   ↓
4. helm-controller (optionnel)
   • Gère les Helm charts
   • Met à jour les dépendances
   ↓
5. Réconciliation
   • Compare état désiré (Git) vs état actuel (cluster)
   • Applique les différences automatiquement
   ↓
6. notification-controller
   • Envoie webhooks/alertes
   • Notifie Slack, Discord, etc.
```

---

## 🎯 Cas d'Usage

### ✅ Quand Utiliser FluxCD

**1. Multi-Environment Deployment**
```
Git Repository Structure:
├─ overlays/
│  ├─ dev/
│  │  └─ deployment.yaml (replicas: 1)
│  ├─ staging/
│  │  └─ deployment.yaml (replicas: 2)
│  └─ production/
│     └─ deployment.yaml (replicas: 5)
│
→ Même code, configuration différente par environnement
→ FluxCD synchronise automatiquement chaque cluster
```

**2. Infrastructure as Code**
```
Tout dans Git:
• Deployments
• ConfigMaps
• Secrets (encrypted)
• RBAC
• NetworkPolicies
• Custom Resources

→ Audit trail complet
→ Rollback facile (git revert)
→ Code review avant déploiement
```

**3. Continuous Deployment**
```
Git → Webhook → FluxCD → Auto-Deploy
(quelques secondes après merge)
```

**4. Multi-Cluster Management**
```
1 Git repo → Multiple clusters
- dev cluster: sync dev/ overlay
- prod cluster: sync prod/ overlay
- staging cluster: sync staging/ overlay
```

**5. Helm Chart Management**
```
FluxCD gère:
• Dépendances Helm
• Upgrades de versions
• Rollbacks automatiques
• Custom values par cluster
```

---

## 📦 Composants Principaux

### 1. **source-controller**
- Monitore les sources Git/Helm
- Clone et synchronise les dépôts
- Détecte les changements
- Supporte: Git (HTTPS/SSH), Helm repos, OCI registries

### 2. **kustomize-controller**
- Compile les manifests Kustomize
- Applique les patches
- Valide les manifests
- Crée les ressources dans le cluster

### 3. **helm-controller**
- Gère les Helm releases
- Résout les dépendances
- Teste les valeurs
- Effectue les upgrades/downgrades

### 4. **image-automation-controller**
- **Scanne les registries Docker**
- Met à jour automatiquement les tags d'image
- Commit les changements dans Git
- Supporte: policy-based (latest, semver, regex)

```yaml
# Exemple: Auto-update images
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImagePolicy
metadata:
  name: app-policy
spec:
  imageRepositoryRef:
    name: app
  policy:
    semver:
      range: '>=1.0.0'  # Updates to latest 1.x.x
---
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImageUpdateAutomation
metadata:
  name: app-updater
spec:
  sourceRef:
    kind: GitRepository
    name: app-repo
  gitCommitSpec:
    author:
      name: FluxCD
      email: flux@example.com
  interval: 5m
```

### 5. **notification-controller**
- Envoie des alertes
- Support: Slack, Teams, Discord, GitHub, GitLab
- Webhooks personnalisés
- Événements: Success, Error, Reconciliation

---

## 🚀 Installation et Configuration

### Installation Basique

```bash
# 1. Installer FluxCD CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# 2. Vérifier prerequisites
flux check --pre

# 3. Installer dans le cluster
flux bootstrap github \
  --owner=<user> \
  --repo=<repo> \
  --branch=main \
  --path=./clusters/prod \
  --personal
```

### Structure Recommandée

```
git-repo/
├─ clusters/
│  ├─ production/
│  │  ├─ flux-system/
│  │  │  └─ gotk-components.yaml (generated)
│  │  ├─ apps/
│  │  │  ├─ deployment.yaml
│  │  │  ├─ service.yaml
│  │  │  └─ kustomization.yaml
│  │  └─ kustomization.yaml
│  └─ staging/
│     ├─ apps/
│     │  ├─ deployment.yaml
│     │  └─ kustomization.yaml
│     └─ kustomization.yaml
├─ apps/
│  └─ base/
│     ├─ app/
│     │  ├─ deployment.yaml
│     │  ├─ service.yaml
│     │  └─ kustomization.yaml
│     └─ kustomization.yaml
└─ infrastructure/
   ├─ calico/
   │  ├─ calico.yaml
   │  └─ kustomization.yaml
   └─ ingress-nginx/
      ├─ values.yaml
      └─ helmrelease.yaml
```

---

## 📚 Exemples Pratiques

### Exemple 1: GitRepository + Kustomization

```yaml
# 1. Définir la source Git
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 5m
  url: https://github.com/user/my-app.git
  ref:
    branch: main
  secretRef:
    name: github-credentials

---
# 2. Synchroniser avec le cluster
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: my-app
  path: ./deploy/overlays/production
  prune: true  # Supprimer les ressources non déclarées
  validation: client  # Valider avant application
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: app
      namespace: default
```

### Exemple 2: Helm Release Management

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: prometheus-community
  namespace: flux-system
spec:
  interval: 1h
  url: https://prometheus-community.github.io/helm-charts

---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: prometheus
  namespace: monitoring
spec:
  interval: 5m
  chart:
    spec:
      chart: kube-prometheus-stack
      sourceRef:
        kind: HelmRepository
        name: prometheus-community
        namespace: flux-system
      version: '>=50.0.0'  # Auto-upgrade compatible versions
  values:
    prometheus:
      prometheusSpec:
        retention: 7d
        resources:
          requests:
            cpu: 100m
            memory: 200Mi
  test:
    enable: true
  postRenderers:
    - kustomize:
        patchesStrategicMerge:
          - apiVersion: apps/v1
            kind: StatefulSet
            metadata:
              name: prometheus-kube-prometheus-prometheus
            spec:
              template:
                spec:
                  containers:
                    - name: prometheus
                      resources:
                        limits:
                          memory: 1Gi
```

### Exemple 3: Multi-Environment avec Kustomize

```yaml
# Base (commun à tous les environnements)
# clusters/base/apps/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: default
resources:
  - deployment.yaml
  - service.yaml
commonLabels:
  app: myapp
replicas:
  - name: myapp
    count: 1

---
# Overlay Production (surcharge la base)
# clusters/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: production
bases:
  - ../../base/apps
replicas:
  - name: myapp
    count: 5  # Override: 5 replicas en production
patches:
  - target:
      kind: Deployment
    patch: |-
      - op: add
        path: /spec/template/spec/resources
        value:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 250m
            memory: 256Mi
```

---

## ✨ Avantages vs Inconvénients

### ✅ Avantages

| Avantage | Description |
|----------|-------------|
| **Git as Source of Truth** | Single source of truth pour l'infrastructure |
| **Audit Trail** | Historique complet des changements |
| **Rollback Simple** | `git revert` = instant rollback |
| **Code Review** | PR avant déploiement |
| **Declarative** | État désiré défini dans Git |
| **Auto-Remediation** | Cluster drifts sont auto-corrigés |
| **Multi-Environment** | Gère dev/staging/prod facilement |
| **GitOps Best Practice** | Implémente les standards GitOps |
| **Secure** | Secrets peuvent être encrypted (Sealed Secrets) |
| **Observable** | Notifications de chaque réconciliation |

### ❌ Inconvénients

| Inconvénient | Description |
|--------------|-------------|
| **Learning Curve** | Concept GitOps peut être nouveau |
| **Git Dependency** | Git repo doit toujours être disponible |
| **Debugging Complexe** | Erreurs de sync plus difficiles à déboguer |
| **Secret Management** | Secrets dans Git nécessite encryption |
| **Latency** | Sync prend quelques minutes (polling) |
| **Merge Conflicts** | Conflit Git = conflit de déploiement |
| **Overhead CPU** | Controllers consomment des ressources |
| **Webhook Setup** | Besoin webhooks pour sync rapide |

---

## 🔐 Sécurité avec Sealed Secrets

```bash
# 1. Installer Sealed Secrets controller
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets -n kube-system sealed-secrets/sealed-secrets

# 2. Créer un secret normal
kubectl create secret generic my-secret \
  --from-literal=password=mysecretpassword \
  --dry-run=client -o yaml > secret.yaml

# 3. Chiffrer le secret
kubeseal -f secret.yaml -w sealed-secret.yaml

# 4. Commiter sealed-secret.yaml dans Git (safe!)
# Le secret ne peut être déchiffré que par ce cluster
```

---

## 🎯 FluxCD vs ArgoCD

| Feature | FluxCD | ArgoCD |
|---------|--------|--------|
| **Architecture** | Pull-based | Pull-based (web UI better) |
| **Learning Curve** | Moyenne | Plus douce |
| **UI/Dashboard** | Minimal | Excellent |
| **CLI** | Excellent | Bon |
| **Image Automation** | ✅ Native | ❌ Extension nécessaire |
| **RBAC** | Native | Native |
| **Multi-Cluster** | ✅ Bon | ✅ Excellent |
| **Communauté** | CNCF | Strong (Helm-centric) |
| **Performance** | Excellent | Bon |
| **Customization** | High | Medium |

**Choix:**
- **FluxCD** → Automatisation image, DevOps avancé
- **ArgoCD** → Équipes commençant avec GitOps, besoin UI

---

## 🚀 Cas d'Usage: Ton Projet Kubernetes HA

### Comment Intégrer FluxCD?

```
clusters/
├─ production/
│  ├─ flux-system/
│  │  └─ gotk-components.yaml
│  ├─ infrastructure/
│  │  ├─ calico/
│  │  │  └─ helmrelease.yaml
│  │  ├─ metallb/
│  │  │  └─ helmrelease.yaml
│  │  └─ ingress-nginx/
│  │     └─ helmrelease.yaml
│  ├─ apps/
│  │  ├─ deployment.yaml
│  │  ├─ service.yaml
│  │  └─ kustomization.yaml
│  └─ kustomization.yaml
└─ staging/
   └─ ...
```

### Avantages pour ton Projet

✅ **Version Control Complet**
- Tous les manifests dans Git
- Historique complet avec git log

✅ **Multi-Cluster Facile**
- Same repo, different overlays
- Dev, staging, production synchronized

✅ **Réconciliation Automatique**
- Configuration drift = auto-fixed
- Garantit l'état désiré

✅ **Image Auto-Update (Bonus!)**
```yaml
# Quand une nouvelle image Docker est publiée,
# FluxCD peut auto-update les deployments et commiter dans Git
```

---

## 📝 Commandes Utiles

```bash
# Voir l'état des sources
flux get sources git

# Voir l'état des kustomizations
flux get kustomizations

# Forcer une réconciliation
flux reconcile source git my-app

# Voir les logs du controller
flux logs --all-namespaces -f

# Voir les alertes
flux get alerts

# Vérifier les dépendances
flux check

# Bootstrap automatique
flux bootstrap github --owner=user --repo=repo
```

---

## Conclusion

**FluxCD = GitOps Automation pour Kubernetes**

- ✅ Git = Source de vérité
- ✅ Synchronisation automatique
- ✅ Audit trail complet
- ✅ Multi-environment support
- ✅ Image automation
- ✅ CNCF project

**Parfait pour:** Infrastructure as Code, continuous deployment, multi-cluster management

**Ressources:**
- Docs: https://fluxcd.io
- GitHub: https://github.com/fluxcd/flux2
- Community: Slack, GitHub discussions
