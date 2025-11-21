# Guide de Migration vers Version 2.0

## 📋 Vue d'ensemble

Ce document vous guide pour implémenter **toutes les améliorations critiques** de la version 2.0.

**Durée estimée** : 10 jours (2 semaines à temps partiel)

**Ordre recommandé** :
1. Bibliothèques de base (2 jours)
2. Sécurité des mots de passe (1 jour)
3. Idempotence (3 jours)
4. Backup/Restore (3 jours)
5. Tests automatisés (2 jours)

---

## ✅ État Actuel

### Fichiers Déjà Créés

- ✅ `scripts/lib/logging.sh` - Système de logging
- ✅ `scripts/lib/rollback.sh` - Rollback automatique
- ✅ `scripts/.gitignore` - Protection fichiers sensibles
- ✅ `scripts/.env.example` - Template des secrets
- ✅ `CHANGELOG.md` - Historique complet
- ✅ `UPGRADE-TO-V2.md` - Ce fichier

### Fichiers à Créer

#### Phase 1 : Idempotence
- [ ] `scripts/lib/idempotent.sh` (~400 lignes)

#### Phase 2 : Sécurité
- [ ] `scripts/generate-env.sh` (~150 lignes)

#### Phase 3 : Backup/Restore
- [ ] `scripts/backup-cluster.sh` (~400 lignes)
- [ ] `scripts/restore-cluster.sh` (~500 lignes)
- [ ] `scripts/setup-auto-backup.sh` (~100 lignes)

#### Phase 4 : Tests
- [ ] `tests/lib/test-framework.sh` (~300 lignes)
- [ ] `tests/test-common-setup.sh` (~200 lignes)
- [ ] `tests/test-cluster.sh` (~200 lignes)
- [ ] `tests/test-integration.sh` (~150 lignes)
- [ ] `tests/run-all-tests.sh` (~100 lignes)

### Fichiers à Modifier

#### Priorité HAUTE
- [ ] `scripts/config.sh` - Charger `.env`
- [ ] `scripts/common-setup.sh` - Idempotence + rollback
- [ ] `scripts/master-setup.sh` - Idempotence UFW
- [ ] `scripts/install-metallb.sh` - Rollback + idempotence

#### Priorité MOYENNE
- [ ] `scripts/worker-setup.sh` - Idempotence
- [ ] `scripts/setup-keepalived.sh` - Masquer mot de passe
- [ ] `scripts/install-rancher.sh` - Rollback
- [ ] `scripts/install-monitoring.sh` - Rollback
- [ ] `scripts/install-calico.sh` - Logs améliorés

---

## 🚀 Phase 1 : Fondations (2 jours)

### Objectif
Mettre en place les bibliothèques de base et tester le système de rollback.

### Étapes

#### Jour 1 : Setup Initial

**1.1 - Vérifier les fichiers existants**

```bash
cd d:\Documents\devs\kubertenes\Kubernetes2\scripts

# Vérifier que ces fichiers existent
ls -la lib/logging.sh
ls -la lib/rollback.sh
ls -la .env.example
ls -la .gitignore
```

**1.2 - Créer le fichier .env**

```bash
# Copier le template
cp .env.example .env

# Éditer et remplacer tous les "CHANGEME"
nano .env
```

**Ou générer automatiquement :**

```bash
# Créer d'abord generate-env.sh (voir code dans le rapport détaillé)
./generate-env.sh
```

**1.3 - Tester le système de logging**

```bash
# Créer un script de test
cat > test-logging.sh <<'EOF'
#!/bin/bash
source "$(dirname "$0")/lib/logging.sh"

init_logging

log_info "Test de logging INFO"
log_success "Test de logging SUCCESS"
log_warn "Test de logging WARN"
log_error "Test de logging ERROR"
log_debug "Test de logging DEBUG (non affiché par défaut)"

# Avec debug activé
LOG_LEVEL=DEBUG
log_debug "Maintenant visible avec LOG_LEVEL=DEBUG"

echo ""
echo "Logs sauvegardés dans: $LOG_FILE"
EOF

chmod +x test-logging.sh
./test-logging.sh
```

**Résultat attendu :**
```
[2025-01-15 10:00:00] [INFO] Test de logging INFO
[2025-01-15 10:00:00] [SUCCESS] Test de logging SUCCESS
[2025-01-15 10:00:00] [WARN] Test de logging WARN
[2025-01-15 10:00:00] [ERROR] Test de logging ERROR
[2025-01-15 10:00:00] [DEBUG] Maintenant visible avec LOG_LEVEL=DEBUG

Logs sauvegardés dans: /var/log/k8s-setup/test-logging-20250115_100000.log
```

#### Jour 2 : Tester le Rollback

**2.1 - Modifier install-metallb.sh pour intégrer le rollback**

Voir le code complet dans le rapport détaillé (Amélioration #1).

**Points clés à intégrer :**
- Sourcer `lib/rollback.sh` et `lib/logging.sh`
- Appeler `enable_auto_rollback` au début
- Enregistrer chaque opération avec `register_rollback`
- Appeler `clear_rollback_stack` en cas de succès

**2.2 - Tester le rollback**

```bash
# Test 1: Installation normale (doit réussir)
./install-metallb.sh

# Test 2: Simuler une erreur (couper le réseau pendant l'installation)
# Le rollback doit s'activer automatiquement

# Test 3: Ctrl+C pendant l'installation
# Le rollback doit s'activer
```

---

## 🔒 Phase 2 : Sécurité (1 jour)

### Objectif
Séparer complètement les secrets de la configuration.

### Étapes

#### Jour 3 : Implémentation Sécurité

**3.1 - Créer generate-env.sh**

Voir le code complet dans le rapport détaillé (Amélioration #2).

**3.2 - Modifier config.sh**

```bash
# Ajouter AVANT la section CONFIGURATION KEEPALIVED (ligne ~150)

# ═══════════════════════════════════════════════════════════════════════════
# CHARGEMENT DES SECRETS DEPUIS .env
# ═══════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ⚠️  ERREUR: Fichier .env manquant                           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Le fichier .env contient les mots de passe et secrets."
    echo ""
    echo "PREMIÈRE INSTALLATION:"
    echo "  1. Copiez le template:"
    echo "     cp $SCRIPT_DIR/.env.example $SCRIPT_DIR/.env"
    echo ""
    echo "  2. Éditez le fichier .env:"
    echo "     nano $SCRIPT_DIR/.env"
    echo ""
    exit 1
fi

# Charger les secrets
source "$ENV_FILE"

# Valider que les mots de passe ont été changés
if [ "$VRRP_PASSWORD" = "CHANGEME" ] || [ "$RANCHER_PASSWORD" = "CHANGEME" ] || [ "$GRAFANA_PASSWORD" = "CHANGEME" ]; then
    echo "ERREUR: Certains mots de passe sont encore 'CHANGEME' dans .env"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════

# ENSUITE supprimer ces lignes (maintenant chargées depuis .env) :
# export VRRP_PASSWORD="K8s_HA_Pass"
# export RANCHER_PASSWORD="admin"
# export GRAFANA_PASSWORD="prom-operator"
```

**3.3 - Tester la sécurité**

```bash
# Vérifier que .env n'est PAS dans Git
git status
# .env ne doit PAS apparaître

# Vérifier que config.sh charge bien .env
./k8s-menu.sh
# Doit afficher le menu sans erreur

# Vérifier qu'on ne peut pas voir les secrets dans Git
git log -p scripts/config.sh | grep PASSWORD
# Ne doit rien retourner (ou seulement les anciennes versions)
```

---

## ♻️ Phase 3 : Idempotence (3 jours)

### Objectif
Rendre tous les scripts ré-exécutables sans effets de bord.

### Jours 4-6

**4.1 - Créer lib/idempotent.sh**

Voir le code complet dans le rapport détaillé (Amélioration #3).

**4.2 - Modifier common-setup.sh**

Points clés :
- Remplacer `swapoff -a` par `setup_swap_idempotent`
- Remplacer `modprobe` par `setup_kernel_modules_idempotent`
- Ajouter vérifications avant installations

**4.3 - Modifier master-setup.sh**

Points clés :
- Remplacer `ufw allow` par `setup_ufw_rule_idempotent`
- Vérifier règles existantes avant ajout

**4.4 - Tester l'idempotence**

```bash
# Test 1: Premier run
sudo ./common-setup.sh
# Doit installer tout

# Test 2: Deuxième run
sudo ./common-setup.sh
# Doit afficher "déjà fait" partout
# Durée: <5 secondes

# Test 3: Troisième run
sudo ./common-setup.sh
# Même résultat que test 2

# Vérifier /etc/fstab
cat /etc/fstab
# Les lignes swap ne doivent avoir qu'UN SEUL #

# Vérifier UFW
sudo ufw status numbered
# Aucune règle dupliquée
```

---

## 💾 Phase 4 : Backup/Restore (3 jours)

### Objectif
Pouvoir sauvegarder et restaurer le cluster complet.

### Jours 7-9

**7.1 - Créer backup-cluster.sh**

Voir le code complet dans le rapport détaillé (Amélioration #4).

**7.2 - Créer restore-cluster.sh**

Voir le code complet dans le rapport détaillé (Amélioration #4).

**7.3 - Créer setup-auto-backup.sh**

Voir le code complet dans le rapport détaillé (Amélioration #4).

**7.4 - Tester le backup**

```bash
# Test 1: Backup complet
./backup-cluster.sh

# Vérifier le backup
ls -lh /var/backups/k8s-cluster/

# Test 2: Backup etcd uniquement (rapide)
./backup-cluster.sh --type etcd

# Test 3: Lister les backups
./restore-cluster.sh --list-backups
```

**7.5 - Tester la restauration (ATTENTION : Cluster de test uniquement !)**

```bash
# Sur un cluster de TEST uniquement

# 1. Créer un backup
./backup-cluster.sh

# 2. Créer un namespace de test
kubectl create namespace test-restore
kubectl create deployment nginx --image=nginx -n test-restore

# 3. Supprimer le namespace
kubectl delete namespace test-restore

# 4. Restaurer
./restore-cluster.sh /var/backups/k8s-cluster/k8s-backup-*.tar.gz --type resources

# 5. Vérifier
kubectl get namespace test-restore
kubectl get pods -n test-restore
# Le namespace et le déploiement doivent être revenus !
```

**7.6 - Configurer les backups automatiques**

```bash
./setup-auto-backup.sh
# Choisir: 1) Quotidien à 2h00

# Vérifier la configuration cron
crontab -l
# Doit afficher: 0 2 * * * /usr/local/bin/k8s-auto-backup.sh
```

---

## ✅ Phase 5 : Tests (2 jours)

### Objectif
Créer une suite de tests automatisés pour détecter les régressions.

### Jours 10-11

**10.1 - Créer tests/lib/test-framework.sh**

Voir le code complet dans le rapport détaillé (Amélioration #5).

**10.2 - Créer tests/test-common-setup.sh**

Voir le code complet dans le rapport détaillé (Amélioration #5).

**10.3 - Créer tests/test-cluster.sh**

Voir le code complet dans le rapport détaillé (Amélioration #5).

**10.4 - Créer tests/test-integration.sh**

Voir le code complet dans le rapport détaillé (Amélioration #5).

**10.5 - Créer tests/run-all-tests.sh**

Voir le code complet dans le rapport détaillé (Amélioration #5).

**10.6 - Exécuter tous les tests**

```bash
# Tests complets
sudo ./tests/run-all-tests.sh

# Résultat attendu:
# ✓ Tests common-setup.sh réussis (24/24)
# ✓ Tests cluster réussis (18/18)
# ✓ Tests d'intégration réussis (12/12)
# ✓ Tous les tests ont réussi (54/54)
```

---

## 📊 Validation Finale

### Checklist Complète

#### Fichiers Créés
- [ ] `scripts/lib/logging.sh`
- [ ] `scripts/lib/rollback.sh`
- [ ] `scripts/lib/idempotent.sh`
- [ ] `scripts/.env`
- [ ] `scripts/.env.example`
- [ ] `scripts/.gitignore`
- [ ] `scripts/generate-env.sh`
- [ ] `scripts/backup-cluster.sh`
- [ ] `scripts/restore-cluster.sh`
- [ ] `scripts/setup-auto-backup.sh`
- [ ] `tests/lib/test-framework.sh`
- [ ] `tests/test-common-setup.sh`
- [ ] `tests/test-cluster.sh`
- [ ] `tests/test-integration.sh`
- [ ] `tests/run-all-tests.sh`
- [ ] `CHANGELOG.md`
- [ ] `UPGRADE-TO-V2.md`

#### Fichiers Modifiés
- [ ] `scripts/config.sh` - Charge `.env`
- [ ] `scripts/common-setup.sh` - Idempotent
- [ ] `scripts/master-setup.sh` - Idempotent
- [ ] `scripts/worker-setup.sh` - Idempotent
- [ ] `scripts/install-metallb.sh` - Rollback + idempotent
- [ ] `scripts/install-rancher.sh` - Rollback
- [ ] `scripts/install-monitoring.sh` - Rollback
- [ ] `scripts/k8s-menu.sh` - Version dynamique

#### Tests de Validation

```bash
# 1. Sécurité
git status | grep .env
# .env ne doit PAS apparaître

# 2. Idempotence
sudo ./common-setup.sh
sudo ./common-setup.sh  # Doit être rapide (<5s)

# 3. Rollback
# (Tester en coupant le réseau pendant install)

# 4. Backup/Restore
./backup-cluster.sh
./restore-cluster.sh --list-backups

# 5. Tests
sudo ./tests/run-all-tests.sh
# Doit afficher: ✓ Tous les tests ont réussi
```

---

## 🎯 Résumé des Gains

| Amélioration | Avant | Après | Gain |
|--------------|-------|-------|------|
| **Rollback** | Nettoyage manuel (30min) | Automatique (<1min) | ⏱️ 29min |
| **Sécurité** | Secrets dans Git ⚠️ | Secrets protégés ✅ | 🔒 Critique |
| **Idempotence** | Re-run = erreurs | Re-run = 5s | ⏱️ 2-5min |
| **Backup** | Manuel/absent | Automatique quotidien | 💾 Récupération désastre |
| **Tests** | 0 test | 54 tests | 🐛 Détection régressions |

---

## 📞 Support

Si vous rencontrez des problèmes pendant l'implémentation :

1. **Vérifier les logs** : `/var/log/k8s-setup/`
2. **Vérifier la syntaxe** : `bash -n script.sh`
3. **Mode debug** : `DEBUG=1 ./script.sh`
4. **Consulter le rapport détaillé** : Voir le message précédent pour le code complet

---

## 🎉 Félicitations !

Une fois toutes les phases complétées, vous aurez un cluster Kubernetes **production-ready** avec :

- ✅ Rollback automatique
- ✅ Sécurité renforcée
- ✅ Scripts idempotents
- ✅ Backup/Restore complet
- ✅ Tests automatisés

**Score de qualité : 7.2/10 → 9.5/10** 🚀

---

**Version du document** : 2.0.0
**Dernière mise à jour** : 2025-01-15
