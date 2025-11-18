# 📝 Guide de Configuration

Ce guide explique comment personnaliser votre cluster Kubernetes en modifiant le fichier `scripts/config.sh`.

## 📍 Fichier de configuration

```bash
scripts/config.sh
```

**Important** : Modifiez ce fichier **AVANT** de lancer l'installation.

## 🔧 Variables principales

### 🌐 Domaine

```bash
# Nom de domaine utilisé pour tous les FQDN
export DOMAIN_NAME="home.local"
```

**Exemples** :
- `home.local` (par défaut, pour homelab)
- `k8s.example.com`
- `cluster.internal`
- `mydomain.net`

Tous les FQDN seront automatiquement générés :
- `k8s.home.local` → `k8s.${DOMAIN_NAME}`
- `k8s01-1.home.local` → `k8s01-1.${DOMAIN_NAME}`
- `rancher.home.local` → `rancher.${DOMAIN_NAME}`

### 🎯 IP Virtuelle (VIP)

```bash
export VIP="192.168.0.200"
export VIP_HOSTNAME="k8s"
# FQDN généré automatiquement: ${VIP_HOSTNAME}.${DOMAIN_NAME}
```

**Règles** :
- Doit être sur le même subnet que les masters
- Ne doit PAS être assignée manuellement à une machine
- Sera gérée automatiquement par keepalived

### 🖥️ Masters

```bash
# Master 1 (Priority la plus haute)
export MASTER1_IP="192.168.0.201"
export MASTER1_HOSTNAME="k8s01-1"
export MASTER1_PRIORITY="101"

# Master 2
export MASTER2_IP="192.168.0.202"
export MASTER2_HOSTNAME="k8s01-2"
export MASTER2_PRIORITY="100"

# Master 3
export MASTER3_IP="192.168.0.203"
export MASTER3_HOSTNAME="k8s01-3"
export MASTER3_PRIORITY="99"
```

**Notes** :
- Les FQDN sont générés automatiquement avec `${DOMAIN_NAME}`
- Les priorités déterminent l'ordre de basculement (plus haut = préféré)
- Master 1 doit avoir la priorité la plus haute

### 👷 Workers

```bash
# Worker 1
export WORKER1_IP="192.168.0.211"
export WORKER1_HOSTNAME="k8s-worker-1"

# Worker 2
export WORKER2_IP="192.168.0.212"
export WORKER2_HOSTNAME="k8s-worker-2"

# Worker 3
export WORKER3_IP="192.168.0.213"
export WORKER3_HOSTNAME="k8s-worker-3"

# Nombre total de workers
export WORKER_COUNT=3
```

**Personnalisation** :
- Modifiez `WORKER_COUNT` selon le nombre réel de workers
- Ajoutez/supprimez des workers selon vos besoins
- Les FQDN sont générés automatiquement

**Exemple avec 2 workers** :
```bash
export WORKER1_IP="192.168.0.211"
export WORKER1_HOSTNAME="k8s-worker-1"

export WORKER2_IP="192.168.0.212"
export WORKER2_HOSTNAME="k8s-worker-2"

# Commentez ou supprimez WORKER3
# export WORKER3_IP="192.168.0.213"
# export WORKER3_HOSTNAME="k8s-worker-3"

export WORKER_COUNT=2
```

**Exemple avec 5 workers** :
```bash
# Garder WORKER1, WORKER2, WORKER3
# Ajouter:
export WORKER4_IP="192.168.0.214"
export WORKER4_HOSTNAME="k8s-worker-4"
export WORKER4_FQDN="${WORKER4_HOSTNAME}.${DOMAIN_NAME}"

export WORKER5_IP="192.168.0.215"
export WORKER5_HOSTNAME="k8s-worker-5"
export WORKER5_FQDN="${WORKER5_HOSTNAME}.${DOMAIN_NAME}"

export WORKER_COUNT=5
```

### 🔌 Interface réseau

```bash
export NETWORK_INTERFACE="auto"
```

**Options** :
- `auto` : Détection automatique (recommandé)
- `ens33` : Forcer l'interface ens33
- `ens18` : Forcer l'interface ens18
- `enp0s3` : Forcer l'interface enp0s3
- `eth0` : Forcer l'interface eth0

**Vérifier votre interface** :
```bash
ip a
# ou
ip route | grep default
```

### ⚖️ MetalLB

```bash
export METALLB_IP_START="192.168.0.220"
export METALLB_IP_END="192.168.0.240"
```

**Règles** :
- La plage doit être sur le même subnet que le cluster
- Ne doit PAS chevaucher avec les IPs des nœuds (.200-.213)
- Nombre d'IPs = nombre de services LoadBalancer maximum

**Exemple** :
- Plage `192.168.0.220-192.168.0.240` = 21 IPs disponibles
- Peut créer jusqu'à 21 services LoadBalancer
- Évite les collisions avec VIP (.200), Masters (.201-.203), Workers (.211-.213)

### 🔐 Keepalived

```bash
export VRRP_PASSWORD="K8s_HA_Pass"
export VRRP_ROUTER_ID="51"
export VRRP_ADVERT_INT="1"
```

**Recommandations** :
- Changez `VRRP_PASSWORD` pour plus de sécurité (max 8 caractères)
- `VRRP_ROUTER_ID` doit être unique sur le réseau local
- `VRRP_ADVERT_INT` = intervalle d'annonce en secondes

### ☸️ Kubernetes

```bash
export K8S_VERSION="1.33.0"
export POD_SUBNET="11.0.0.0/16"
export SERVICE_SUBNET="10.0.0.0/16"
export API_SERVER_PORT="6443"
```

**Notes** :
- `POD_SUBNET` : Réseau interne pour les pods (Calico)
- `SERVICE_SUBNET` : Réseau pour les services Kubernetes
- Les deux subnets doivent être différents et ne pas chevaucher

### 🐄 Rancher

```bash
export RANCHER_SUBDOMAIN="rancher"
# FQDN généré: rancher.${DOMAIN_NAME}
export RANCHER_PASSWORD="admin"
export RANCHER_TLS_SOURCE="rancher"
```

**Options TLS** :
- `rancher` : Certificat auto-signé (par défaut, pour homelab)
- `letsEncrypt` : Let's Encrypt (nécessite domaine public)
- `secret` : Utiliser vos propres certificats

**Changer le hostname** :
```bash
export RANCHER_SUBDOMAIN="cattle"
# Résultat: cattle.home.local
```

### 📊 Monitoring

```bash
export GRAFANA_PASSWORD="prom-operator"
export MONITORING_NAMESPACE="monitoring"
```

**Sécurité** :
Changez le mot de passe Grafana avant production !

```bash
export GRAFANA_PASSWORD="VotreMotDePasse123!"
```

## 🧪 Tester la configuration

### Afficher la configuration

```bash
cd scripts
source config.sh
show_config
```

### Valider la configuration

```bash
source config.sh
validate_config
```

### Générer /etc/hosts

```bash
source config.sh
generate_hosts_entries
```

**Copier dans /etc/hosts** :
```bash
source config.sh
generate_hosts_entries | sudo tee -a /etc/hosts
```

## 📋 Exemples de configuration

### Exemple 1 : Homelab simple

```bash
export DOMAIN_NAME="home.local"
export VIP="192.168.1.100"

export MASTER1_IP="192.168.1.101"
export MASTER2_IP="192.168.1.102"
export MASTER3_IP="192.168.1.103"

export WORKER1_IP="192.168.1.111"
export WORKER2_IP="192.168.1.112"
export WORKER_COUNT=2

export METALLB_IP_START="192.168.1.200"
export METALLB_IP_END="192.168.1.220"
```

### Exemple 2 : Production avec domaine public

```bash
export DOMAIN_NAME="k8s.mycompany.com"
export VIP="10.0.1.100"

export MASTER1_IP="10.0.1.101"
export MASTER2_IP="10.0.1.102"
export MASTER3_IP="10.0.1.103"

export WORKER1_IP="10.0.2.11"
export WORKER2_IP="10.0.2.12"
export WORKER3_IP="10.0.2.13"
export WORKER4_IP="10.0.2.14"
export WORKER5_IP="10.0.2.15"
export WORKER_COUNT=5

export METALLB_IP_START="10.0.3.10"
export METALLB_IP_END="10.0.3.50"

export RANCHER_SUBDOMAIN="rancher"
export RANCHER_TLS_SOURCE="letsEncrypt"
export RANCHER_PASSWORD="SecurePassword123!"

export GRAFANA_PASSWORD="AnotherSecurePass456!"
```

### Exemple 3 : Petit cluster 2 masters + 1 worker

```bash
export DOMAIN_NAME="lab.local"
export VIP="192.168.0.50"

# 2 masters seulement
export MASTER1_IP="192.168.0.51"
export MASTER1_PRIORITY="101"

export MASTER2_IP="192.168.0.52"
export MASTER2_PRIORITY="100"

# Commenter MASTER3 si non utilisé
# export MASTER3_IP="192.168.0.53"

# 1 worker seulement
export WORKER1_IP="192.168.0.61"
export WORKER_COUNT=1

export METALLB_IP_START="192.168.0.100"
export METALLB_IP_END="192.168.0.110"
```

## 🔄 Modifier après installation

**Attention** : Certaines modifications nécessitent une réinstallation.

### Peut être modifié sans réinstaller :
- ✅ Mots de passe Rancher/Grafana
- ✅ Plage MetalLB (reconfigurer MetalLB)
- ✅ Ajouter des workers

### Nécessite une réinstallation :
- ❌ IPs des masters
- ❌ IP virtuelle (VIP)
- ❌ Nom de domaine
- ❌ Subnets Kubernetes (POD_SUBNET, SERVICE_SUBNET)

## 🔍 Vérifications importantes

Avant de lancer l'installation :

1. **Vérifier que les IPs sont disponibles** :
   ```bash
   ping -c 1 192.168.0.200  # VIP
   ping -c 1 192.168.0.201  # Master 1
   # etc...
   ```

2. **Vérifier le nom de domaine** :
   ```bash
   nslookup k8s.home.local
   # ou vérifier /etc/hosts
   ```

3. **Vérifier l'interface réseau** :
   ```bash
   ip route | grep default
   ```

4. **Valider la configuration** :
   ```bash
   source scripts/config.sh
   validate_config
   ```

## 💾 Sauvegarder votre configuration

```bash
# Sauvegarder
cp scripts/config.sh scripts/config.sh.backup

# Restaurer
cp scripts/config.sh.backup scripts/config.sh
```

## 🆘 Aide

Pour toute question sur la configuration :

1. Consultez les exemples ci-dessus
2. Utilisez `show_config` pour voir la config actuelle
3. Utilisez `validate_config` pour vérifier
4. Consultez [README.md](README.md) pour plus de détails

---

**💡 Conseil** : Testez votre configuration sur une seule machine d'abord avec `show_config` avant de l'appliquer à tout le cluster !
