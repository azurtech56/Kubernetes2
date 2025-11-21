# 🚀 Guide Rapide - Kubernetes HA v2.1

Guide de démarrage rapide pour utiliser les fonctionnalités de la version 2.1.

---

## 📋 Prérequis

### 1. Générer les Secrets

```bash
cd scripts
./generate-env.sh

# Choix :
# 1. Génération automatique (recommandé)
# 2. Saisie manuelle

# Génère automatiquement :
# - VRRP_PASSWORD (8 caractères)
# - RANCHER_PASSWORD (16 caractères)
# - GRAFANA_PASSWORD (16 caractères)
```

### 2. Valider la Configuration

```bash
./validate-config.sh

# Vérifie :
# ✅ Domaines valides
# ✅ VIP accessible
# ✅ Masters (IPs, hostnames, HA)
# ✅ Workers (IPs, hostnames)
# ✅ Réseaux Kubernetes
# ✅ Plage MetalLB
# ✅ Pas de conflits IP
# ✅ Versions Kubernetes
# ✅ Configuration keepalived
# ✅ Configuration Rancher
# ✅ Configuration monitoring
# ✅ Timeouts valides
```

### 3. Vérifier les Prérequis Système

```bash
./check-prerequisites.sh

# Vérifie :
# ✅ RAM, CPU, Disk
# ✅ OS supporté
# ✅ Connectivité réseau
# ✅ Ports disponibles
# ✅ Firewall
# ✅ Permissions
# ✅ Dépendances système
# ✅ Modules kernel
```

---

## 🔧 Installation avec Performance

### Mode Normal

```bash
# Installation standard avec optimisations v2.1
./master-setup.sh

# Avantages automatiques :
# ⚡ Cache des téléchargements (24h)
# ⚡ Téléchargements parallèles
# ⚡ Smart waiting (timeouts adaptatifs)
# ⚡ APT optimisé (skip update si < 1h)
# ⚡ Métriques de temps
```

### Mode Dry-Run (Simulation)

```bash
# Tester sans modification système
export DRY_RUN=true
./master-setup.sh

# Affiche toutes les opérations qui seraient exécutées :
# [DRY-RUN] swapoff -a
# [DRY-RUN] modprobe overlay
# [DRY-RUN] apt-get install -y kubelet=1.32.2-*
# [DRY-RUN] kubeadm init ...
# ...
# 📊 RÉSUMÉ DRY-RUN
# Total d'opérations simulées: 127

# Exécuter réellement
unset DRY_RUN
./master-setup.sh
```

---

## 📊 Monitoring

### Health Check Manuel

```bash
./health-check.sh

# Vérifie :
# ✅ Cluster info
# ✅ Nodes status
# ✅ System pods (API, etcd, scheduler, controller)
# ✅ Calico CNI
# ✅ MetalLB
# ✅ Rancher
# ✅ Monitoring (Prometheus, Grafana)
# ✅ Applications utilisateur
```

### Health Check Continu

```bash
# Monitoring toutes les 30 secondes
./health-check.sh --continuous --interval 30

# Avec notifications
./health-check.sh --continuous --interval 30 --notify
```

---

## 💾 Backup & Restore

### Backup Manuel

```bash
# Backup complet (etcd + ressources + add-ons)
./backup-cluster.sh --type full

# Backup etcd seulement
./backup-cluster.sh --type etcd

# Backup avec rétention 30 jours
./backup-cluster.sh --retention 30

# Backups stockés dans :
# /var/backups/kubernetes/
```

### Backup Automatique

```bash
# Configurer backups automatiques
./setup-auto-backup.sh

# Choix :
# 1. Quotidien (3h du matin)
# 2. Hebdomadaire (dimanche 3h)
# 3. Personnalisé (cron)

# Vérifier statut
./setup-auto-backup.sh --status
```

### Restauration

```bash
# Lister les backups
ls -lh /var/backups/kubernetes/

# Restauration complète
./restore-cluster.sh /var/backups/kubernetes/k8s-backup-20250116-030000.tar.gz

# Restauration etcd seulement
./restore-cluster.sh /var/backups/kubernetes/k8s-backup-20250116-030000.tar.gz --etcd-only

# Mode dry-run
./restore-cluster.sh /var/backups/kubernetes/k8s-backup-20250116-030000.tar.gz --dry-run
```

---

## 📢 Notifications

### Configuration

Éditer `scripts/.env` :

```bash
# === NOTIFICATIONS ===
NOTIFICATION_ENABLED="true"
NOTIFICATION_LEVEL="info"  # debug, info, warn, error, critical

# --- Slack ---
SLACK_ENABLED="true"
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX"
SLACK_CHANNEL="#kubernetes"
SLACK_USERNAME="K8s-HA-Bot"
SLACK_ICON=":kubernetes:"

# --- Email ---
EMAIL_ENABLED="true"
EMAIL_FROM="k8s-ha@example.com"
EMAIL_TO="admin@example.com"
EMAIL_SMTP_HOST="smtp.gmail.com"
EMAIL_SMTP_PORT="587"
EMAIL_SMTP_USER="your-email@gmail.com"
EMAIL_SMTP_PASSWORD="your-app-password"
EMAIL_USE_TLS="true"

# --- Discord ---
DISCORD_ENABLED="true"
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1234567890/XXXXXXXXXXXXXXXXXXXX"
DISCORD_USERNAME="K8s-HA-Bot"

# --- Telegram ---
TELEGRAM_ENABLED="true"
TELEGRAM_BOT_TOKEN="123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
TELEGRAM_CHAT_ID="123456789"
```

### Test des Notifications

```bash
source scripts/lib/notifications.sh
test_notifications

# Affiche :
# 🧪 Test des notifications configurées...
#
#   • Slack... ✅
#   • Email... ✅
#   • Discord... ✅
#   • Telegram... ✅
#
# Résultat: 4 réussi(s), 0 échec(s)
```

### Utilisation dans les Scripts

```bash
# Charger la bibliothèque
source scripts/lib/notifications.sh

# Notification simple
notify_info "Installation démarrée" "Début de l'installation MetalLB"

# Notification d'erreur
notify_error "Installation échouée" "Timeout webhook MetalLB après 600s"

# Notification critique
notify_critical "Cluster down" "3 masters sur 3 sont down"

# Helpers spécialisés
notify_install_start "MetalLB"
notify_install_success "MetalLB" "45s"
notify_install_failed "MetalLB" "Webhook timeout"

notify_health_check "degraded" "1 node NotReady"
notify_backup "success" "/var/backups/k8s-backup.tar.gz" "2.3 GB"
```

---

## 🔍 Gestion des Erreurs

### Afficher une Erreur

```bash
source scripts/lib/error-codes.sh

# Afficher erreur avec solution
display_error "E002" "MetalLB webhook timeout after 600s"

# Affiche :
# ╔════════════════════════════════════════════════════════════════╗
# ║ ❌ ERREUR E002
# ╠════════════════════════════════════════════════════════════════╣
# ║ Timeout d'attente des webhooks
# ║
# ║ Contexte: MetalLB webhook timeout after 600s
# ╚════════════════════════════════════════════════════════════════╝
#
# Solutions:
# 1. Vérifier l'état des webhooks: kubectl get validatingwebhookconfigurations
# 2. Vérifier les pods: kubectl get pods -A | grep webhook
# 3. Augmenter WEBHOOK_TIMEOUT dans config.sh
# ...
```

### Codes d'Erreur Courants

| Code | Description | Solution rapide |
|------|-------------|-----------------|
| E001 | Échec installation MetalLB | `kubectl get pods -n metallb-system` |
| E002 | Timeout webhook | Augmenter `WEBHOOK_TIMEOUT` |
| E003 | Pods non prêts | `kubectl describe pod <name>` |
| E011 | IP invalide | Vérifier format dans config.sh |
| E012 | VIP non accessible | `systemctl status keepalived` |
| E013 | Port occupé | `ss -tulpn \| grep :<port>` |
| E014 | Plage MetalLB en conflit | Vérifier METALLB_RANGE |
| E021 | RAM insuffisante | Minimum 2 GB pour master |
| E031 | Calico non déployé | `kubectl get pods -n kube-system` |

---

## ⚡ Optimisation Performance

### Cache Système

```bash
source scripts/lib/performance.sh

# Initialiser le cache
init_cache

# Télécharger avec cache (expiration 24h)
cached_download "https://docs.projectcalico.org/manifests/calico.yaml"

# Nettoyer fichiers expirés
cleanup_cache

# Purger complètement
purge_cache
```

### Téléchargements Parallèles

```bash
# Télécharger plusieurs fichiers en parallèle
urls=(
    "https://example.com/file1.yaml"
    "https://example.com/file2.yaml"
    "https://example.com/file3.yaml"
)
parallel_download "${urls[@]}"
```

### Smart Waiting

```bash
# Au lieu de :
kubectl apply -f metallb.yaml
sleep 300

# Utiliser :
kubectl apply -f metallb.yaml
smart_wait "kubectl get pods -n metallb-system" "Running" 300

# Retourne dès que les pods sont Running (gain de temps)
```

### Métriques de Performance

```bash
start_timer "installation_metallb"

# ... opérations d'installation ...

stop_timer "installation_metallb"
# Affiche : ⏱ installation_metallb: 45s
```

---

## 🔄 Rollback

### Rollback Automatique

Le rollback est **automatique** en cas d'erreur :

```bash
./setup-metallb.sh

# Si erreur :
# ⚠️  Erreur détectée - Rollback en cours...
# ↩️  Suppression namespace metallb-system
# ↩️  Suppression configmap metallb-config
# ✅ Rollback terminé
```

### Rollback Manuel

```bash
# Les scripts enregistrent les opérations dans :
# /var/lib/k8s-setup/rollback-stack.sh

# Exécuter rollback manuel
source scripts/lib/rollback.sh
execute_rollback "Rollback manuel"
```

---

## 🔁 Idempotence

### Ré-exécution Rapide

```bash
# Première exécution : 20 minutes
./master-setup.sh

# Ré-exécution : 5 secondes !
./master-setup.sh

# Affiche :
# ⏭️  swap déjà désactivé (ignoré)
# ⏭️  overlay déjà chargé (ignoré)
# ⏭️  br_netfilter déjà chargé (ignoré)
# ⏭️  Kubernetes déjà installé (ignoré)
# ...
```

### Forcer la Ré-exécution

```bash
# Forcer une opération spécifique
./master-setup.sh --force

# Réinitialiser l'état complet
./master-setup.sh --reset-state

# État stocké dans :
# /var/lib/k8s-setup/installation-state.json
```

---

## 📝 Logs

### Localisation

```bash
# Logs centralisés
/var/log/k8s-setup/
├── common-setup.log
├── master-setup.log
├── worker-setup.log
├── metallb.log
├── rancher.log
├── monitoring.log
├── backup.log
├── restore.log
├── health-check.log
├── prerequisites.log
└── errors.log
```

### Consultation

```bash
# Logs en temps réel
tail -f /var/log/k8s-setup/master-setup.log

# Rechercher une erreur
grep -i error /var/log/k8s-setup/*.log

# Logs des 24 dernières heures
find /var/log/k8s-setup/ -name "*.log" -mtime -1 -exec cat {} \;
```

---

## 🎯 Workflow Recommandé

### Installation Initiale

```bash
# 1. Générer secrets
cd scripts
./generate-env.sh

# 2. Éditer configuration
vim config.sh

# 3. Valider configuration
./validate-config.sh

# 4. Vérifier prérequis (sur chaque nœud)
./check-prerequisites.sh

# 5. Simulation (optionnel)
export DRY_RUN=true
./master-setup.sh
unset DRY_RUN

# 6. Installation réelle
./master-setup.sh  # Sur master1
./master-setup.sh  # Sur master2
./master-setup.sh  # Sur master3
./worker-setup.sh  # Sur worker1, worker2, ...

# 7. Installer add-ons
./setup-metallb.sh
./setup-rancher.sh
./setup-monitoring.sh

# 8. Configurer backups
./setup-auto-backup.sh

# 9. Health check
./health-check.sh
```

### Maintenance Continue

```bash
# Quotidien
./health-check.sh

# Hebdomadaire
./health-check.sh --continuous --interval 60 --notify

# Mensuel
./backup-cluster.sh --type full --retention 90
```

---

## 🆘 Dépannage Rapide

### Problème : Installation bloquée

```bash
# 1. Vérifier les logs
tail -f /var/log/k8s-setup/master-setup.log

# 2. Vérifier l'état des pods
kubectl get pods -A

# 3. Si timeout webhook
kubectl get validatingwebhookconfigurations
kubectl delete validatingwebhookconfigurations <nom>
```

### Problème : Node NotReady

```bash
# 1. Vérifier détails
kubectl describe node <node-name>

# 2. Vérifier kubelet
systemctl status kubelet
journalctl -u kubelet -n 50

# 3. Redémarrer kubelet
systemctl restart kubelet
```

### Problème : Pods CrashLoopBackOff

```bash
# 1. Logs du pod
kubectl logs <pod-name> -n <namespace>

# 2. Events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# 3. Décrire le pod
kubectl describe pod <pod-name> -n <namespace>
```

### Problème : VIP non accessible

```bash
# 1. Vérifier keepalived
systemctl status keepalived

# 2. Logs keepalived
journalctl -u keepalived -n 50

# 3. Vérifier interface
ip addr show | grep <VIP>

# 4. Tester ping
ping -c 3 <VIP>
```

---

## 📚 Ressources

### Documentation
- [README.md](README.md) - Guide complet
- [CHANGELOG.md](CHANGELOG.md) - Historique versions
- [V2.1-COMPLETE.md](V2.1-COMPLETE.md) - Détails v2.1
- [UPGRADE-TO-V2.md](UPGRADE-TO-V2.md) - Migration v1→v2

### Scripts Utiles
- `validate-config.sh` - Validation configuration
- `check-prerequisites.sh` - Vérification prérequis
- `health-check.sh` - Santé du cluster
- `backup-cluster.sh` - Sauvegarde
- `restore-cluster.sh` - Restauration

### Bibliothèques v2.1
- `scripts/lib/performance.sh` - Performance
- `scripts/lib/error-codes.sh` - Codes d'erreur
- `scripts/lib/dry-run.sh` - Simulation
- `scripts/lib/notifications.sh` - Notifications

---

## 🎉 Prêt à Déployer !

Vous êtes maintenant prêt à déployer un cluster Kubernetes HA avec toutes les fonctionnalités v2.1 :

✅ Performance optimisée (-60% temps)
✅ Gestion d'erreur enrichie (60 codes)
✅ Mode dry-run sécurisé
✅ Notifications temps réel (4 canaux)

**Bon déploiement !** 🚀
