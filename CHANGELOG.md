# Changelog

Tous les changements notables de ce projet seront documentés dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère au [Semantic Versioning](https://semver.org/lang/fr/).

---

## [2.0.0] - 2025-01-15

### 🎉 Version Majeure - Production-Ready

Cette version apporte des améliorations **critiques** pour la production : sécurité, fiabilité, et tests automatisés.

### ✨ Ajouté

#### 🔄 Rollback Automatique
- **Nouveau** : Système de rollback automatique en cas d'échec d'installation
- Fichier : `scripts/lib/rollback.sh`
- Annulation automatique des modifications lors d'erreurs
- Stack LIFO pour annuler dans l'ordre inverse
- Support Ctrl+C pour interruption propre
- **Impact** : Récupération automatique sans intervention manuelle

#### 🔒 Sécurité Renforcée
- **Nouveau** : Gestion des secrets via fichier `.env` (non versionné)
- Fichiers : `.env.example`, `generate-env.sh`, `.gitignore`
- Séparation complète des secrets et de la configuration
- Script de génération automatique de mots de passe forts
- Masquage des mots de passe dans les logs
- **Impact** : Aucun secret versionné dans Git

#### ♻️ Idempotence Complète
- **Nouveau** : Scripts ré-exécutables sans effets de bord
- Fichier : `scripts/lib/idempotent.sh`
- Détection automatique des opérations déjà effectuées
- Tracking d'état dans `/var/lib/k8s-setup/installation-state.json`
- Options `--force` et `--reset-state` pour forcer la ré-exécution
- **Impact** : Scripts ré-exécutables en <5s au lieu de 2-5 minutes

#### 💾 Backup & Restore
- **Nouveau** : Système complet de sauvegarde du cluster
- Fichiers : `backup-cluster.sh`, `restore-cluster.sh`, `setup-auto-backup.sh`
- Backup etcd, certificats, ressources Kubernetes, add-ons
- Restauration complète ou partielle (etcd only, resources only)
- Backups automatiques via cron (quotidien/hebdomadaire)
- Rétention configurable (défaut: 7 jours)
- Mode `--dry-run` pour simulation
- **Impact** : Récupération en cas de désastre en <30 minutes

#### ✅ Tests Automatisés
- **Nouveau** : Suite complète de tests d'intégration
- Répertoire : `tests/`
- Framework de tests custom avec assertions
- Tests unitaires : `test-common-setup.sh`, `test-cluster.sh`
- Tests d'intégration : `test-integration.sh` (déploiement nginx réel)
- Suite complète : `run-all-tests.sh`
- Support CI/CD avec `--ci` flag
- **Impact** : Détection automatique des régressions

#### 📊 Logging Avancé
- **Nouveau** : Système de logging structuré et persistant
- Fichier : `scripts/lib/logging.sh`
- Logs horodatés avec niveaux (DEBUG, INFO, WARN, ERROR)
- Logs persistants dans `/var/log/k8s-setup/`
- Support couleurs pour console
- Mode DEBUG pour traçage détaillé
- **Impact** : Débogage facilité, audit complet

#### 🎨 Améliorations du Menu Interactif
- **Nouveau** : Fonctions de désinstallation des add-ons
- Désinstallation propre : MetalLB, Rancher, Monitoring
- Confirmation avant suppression
- Architecture du cluster affichée dynamiquement depuis `config.sh`
- Alignement du header corrigé (62 caractères)
- Version Kubernetes affichée dynamiquement

### 🔧 Modifié

#### Configuration Centralisée
- `config.sh` charge maintenant `.env` pour les secrets
- Validation automatique des secrets au démarrage
- Messages d'erreur détaillés si `.env` manquant
- Guide pas-à-pas pour première configuration

#### Scripts de Setup Améliorés
- `common-setup.sh` : Idempotent, logs structurés
- `master-setup.sh` : Idempotent, règles UFW sans doublons
- `worker-setup.sh` : Idempotent, ports optimisés
- `setup-keepalived.sh` : Mot de passe VRRP masqué dans logs

#### Scripts d'Installation Améliorés
- `install-metallb.sh` : Rollback + vérification webhook complète
- `install-rancher.sh` : Rollback + validation cert-manager
- `install-monitoring.sh` : Rollback + timeout optimisé
- `install-calico.sh` : Logs améliorés, timeout configurables

#### Menu Interactif
- `k8s-menu.sh` :
  - Configuration chargée globalement (1 seule fois)
  - Header avec version dynamique et padding automatique
  - Architecture dynamique (1 à N masters/workers)
  - Ordre d'installation dynamique
  - Fonctions de désinstallation

### 🐛 Corrigé

- **Webhook timeout** : Vérification en 4 niveaux (pods → endpoints → WebhookConfig → dry-run)
- **SSH bloqué** : Port 22 ajouté à UFW dans master-setup.sh et worker-setup.sh
- **Calico pods 0/1** : Réseau des pods (11.0.0.0/16) autorisé dans UFW
- **Inter-node communication** : Réseau cluster (192.168.0.0/24) autorisé dans UFW
- **Alignement menu** : Header réduit à 62 caractères (au lieu de 64)
- **Duplication UFW rules** : Vérification avant ajout de règles
- **Swap /etc/fstab** : Double commentage évité avec idempotence

### 📚 Documentation

- **Nouveau** : `CHANGELOG.md` - Historique détaillé des versions
- **Nouveau** : `.env.example` - Template des secrets avec documentation
- **Nouveau** : `.gitignore` - Protection des fichiers sensibles
- **Amélioré** : `README.md` - Documentation complète version 2.0
- **Amélioré** : Commentaires dans tous les scripts

### 🔒 Sécurité

- ✅ Secrets séparés de la configuration (`.env`)
- ✅ Mots de passe jamais versionnés dans Git
- ✅ Permissions fichiers restrictives (600 pour .env)
- ✅ Mots de passe masqués dans les logs
- ✅ Validation des mots de passe forts (force checking)
- ✅ Backups chiffrables (permissions 600)

### ⚡ Performance

- ✅ Scripts idempotents : ré-exécution en <5s
- ✅ Configuration chargée 1 seule fois dans k8s-menu.sh
- ✅ Timeouts optimisés et configurables
- ✅ Opérations redondantes éliminées

### 🧪 Tests

- ✅ 24 tests pour common-setup.sh
- ✅ 18 tests pour le cluster
- ✅ 12 tests d'intégration
- ✅ **54 tests au total**
- ✅ Support CI/CD avec fichier de résultats

### 📊 Statistiques Version 2.0

- **Lignes de code ajoutées** : ~3000
- **Nouveaux fichiers** : 13
- **Scripts modifiés** : 11
- **Tests créés** : 54
- **Temps d'implémentation** : 10 jours (estimé)

### ⚠️ Breaking Changes

#### Migration 1.x → 2.0

**IMPORTANT** : Les mots de passe sont maintenant dans `.env`

1. **Créer le fichier `.env`** :
   ```bash
   cd scripts/
   cp .env.example .env
   nano .env  # Remplacer tous les "CHANGEME"
   ```

2. **Supprimer les mots de passe de config.sh** (ils seront chargés depuis `.env`) :
   ```bash
   # Ces lignes sont maintenant obsolètes dans config.sh:
   # export VRRP_PASSWORD="K8s_HA_Pass"
   # export RANCHER_PASSWORD="admin"
   # export GRAFANA_PASSWORD="prom-operator"
   ```

3. **Tester la configuration** :
   ```bash
   ./k8s-menu.sh  # Doit afficher la version sans erreur
   ```

### 🔮 Prochaine Version (2.1.0)

Fonctionnalités prévues :
- [ ] Health checks automatiques (`health-check.sh`)
- [ ] Notifications (email, Slack, webhook)
- [ ] Mode dry-run global pour tous les scripts
- [ ] Support multi-OS (RHEL/CentOS)
- [ ] Mise à jour Kubernetes (`upgrade-cluster.sh`)

---

## [1.0.0] - 2025-01-10

### ✨ Version Initiale

#### Ajouté

- **Scripts d'installation** :
  - `common-setup.sh` : Configuration commune (swap, containerd, Kubernetes)
  - `master-setup.sh` : Configuration des masters (UFW, ports)
  - `worker-setup.sh` : Configuration des workers
  - `setup-keepalived.sh` : Configuration haute disponibilité
  - `init-cluster.sh` : Initialisation du cluster
  - `install-calico.sh` : Installation CNI Calico
  - `install-metallb.sh` : Installation Load Balancer
  - `install-rancher.sh` : Installation interface web
  - `install-monitoring.sh` : Installation Prometheus + Grafana

- **Utilitaires** :
  - `generate-hosts.sh` : Génération automatique de /etc/hosts
  - `check-prerequisites.sh` : Vérification des prérequis
  - `k8s-menu.sh` : Menu interactif d'installation

- **Configuration** :
  - `config.sh` : Configuration centralisée
  - Support 3 masters + 3 workers (configuration fixe)

- **Documentation** :
  - `README.md` : Documentation de base
  - `QUICKSTART.md` : Guide de démarrage rapide

#### Fonctionnalités

- ✅ Cluster Kubernetes 1.32.2
- ✅ Haute disponibilité avec keepalived
- ✅ Réseau Calico (CNI)
- ✅ Load Balancer MetalLB
- ✅ Interface web Rancher
- ✅ Monitoring Prometheus + Grafana
- ✅ Menu interactif
- ✅ Support Ubuntu 20.04/22.04/24.04
- ✅ Support Debian 12/13

#### Limitations Connues

- ⚠️ Mots de passe hardcodés dans config.sh
- ⚠️ Scripts non idempotents (erreurs si ré-exécutés)
- ⚠️ Pas de rollback en cas d'échec
- ⚠️ Pas de tests automatisés
- ⚠️ Configuration fixe (3 masters + 3 workers)
- ⚠️ Pas de backup/restore

---

## [Unreleased]

### En Cours de Développement

- Health checks automatiques avec script dédié
- Système de notifications (email, Slack, webhook)
- Support RHEL/CentOS/Rocky Linux
- Migration Kubernetes (upgrade-cluster.sh)
- Documentation additionnelle :
  - `docs/ARCHITECTURE.md`
  - `docs/TROUBLESHOOTING.md`
  - `docs/UPGRADE.md`
  - `docs/FAQ.md`

---

## Format du Changelog

### Types de Changements

- **Ajouté** : Nouvelles fonctionnalités
- **Modifié** : Changements de fonctionnalités existantes
- **Déprécié** : Fonctionnalités qui seront supprimées
- **Supprimé** : Fonctionnalités supprimées
- **Corrigé** : Corrections de bugs
- **Sécurité** : Corrections de vulnérabilités

### Niveaux de Versions

- **MAJOR** (X.0.0) : Changements incompatibles avec l'API
- **MINOR** (1.X.0) : Ajout de fonctionnalités rétro-compatibles
- **PATCH** (1.0.X) : Corrections de bugs rétro-compatibles

---

## Liens

- **Repository** : https://github.com/azurtech56/Kubernetes2
- **Issues** : https://github.com/azurtech56/Kubernetes2/issues
- **Releases** : https://github.com/azurtech56/Kubernetes2/releases

---

**Note** : Pour les versions < 1.0.0, voir l'historique Git
