# Exemples de fichiers de configuration

Ce dossier contient des **exemples** de fichiers de configuration YAML pour référence.

> ⚠️ **Note importante** : Ces fichiers sont **automatiquement générés** par les scripts d'installation. Vous n'avez **pas besoin** de les créer manuellement.

## 📄 Fichiers d'exemple

| Fichier | Généré par | Description |
|---------|------------|-------------|
| `cAdvisor.yaml` | `install-monitoring.sh` | DaemonSet cAdvisor pour monitoring des conteneurs |
| `metallb-config.yaml` | `install-metallb.sh` | Configuration MetalLB (IPAddressPool + L2Advertisement) |
| `values.yaml` | `install-monitoring.sh` | Configuration Prometheus pour scraper cAdvisor |
| `prometheus-grafana-service.yaml` | Manuel | Service LoadBalancer pour Grafana (optionnel) |

## 🚀 Utilisation

Ces fichiers sont fournis **à titre d'exemple uniquement**. Les scripts génèrent automatiquement les configurations adaptées à votre environnement en utilisant les variables du fichier `config.sh`.

### Pour installer MetalLB :

```bash
# ❌ NE PAS FAIRE
kubectl apply -f examples/metallb-config.yaml

# ✅ FAIRE
./scripts/install-metallb.sh
# OU
./scripts/k8s-menu.sh  # [3] Installation des Add-ons → [1] MetalLB
```

### Pour installer le monitoring :

```bash
# ❌ NE PAS FAIRE
kubectl apply -f examples/cAdvisor.yaml

# ✅ FAIRE
./scripts/install-monitoring.sh
# OU
./scripts/k8s-menu.sh  # [3] Installation des Add-ons → [3] Monitoring
```

## 🔧 Personnalisation

Si vous voulez personnaliser ces configurations :

1. **Modifier le fichier `scripts/config.sh`** avec vos valeurs
2. **Lancer le script correspondant** qui générera le YAML avec vos paramètres
3. Les fichiers générés seront dans le répertoire courant (et ignorés par Git)

### Exemple de personnalisation :

```bash
# Éditer la configuration
nano scripts/config.sh

# Modifier les variables
export METALLB_IP_START="192.168.1.100"
export METALLB_IP_END="192.168.1.150"

# Lancer l'installation
./scripts/install-metallb.sh

# Le fichier metallb-config.yaml sera généré avec vos IPs
```

## 📝 Modification manuelle (avancé)

Si vous voulez vraiment modifier manuellement un fichier :

```bash
# 1. Copier l'exemple
cp examples/metallb-config.yaml ./metallb-config-custom.yaml

# 2. Modifier
nano metallb-config-custom.yaml

# 3. Appliquer
kubectl apply -f metallb-config-custom.yaml
```

⚠️ **Attention** : Les modifications manuelles ne sont pas recommandées car elles ne seront pas synchronisées avec `config.sh`.

## 🎯 Fichiers de référence

Ces exemples sont utiles pour :
- Comprendre la structure des configurations
- Vérifier les paramètres par défaut
- Créer des configurations personnalisées avancées
- Documentation et apprentissage

---

💡 **Conseil** : Utilisez toujours les scripts d'installation qui génèrent automatiquement les configurations correctes !
