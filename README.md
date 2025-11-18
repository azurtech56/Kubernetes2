# Kubernetes 1.33 - Haute Disponibilité (HA)

![Kubernetes](https://img.shields.io/badge/Kubernetes-1.33.0-blue)
![License](https://img.shields.io/badge/License-MIT-green)
![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%2F22.04%2F24.04-orange)
![Debian](https://img.shields.io/badge/Debian-12%2F13-red)

Scripts d'installation **100% automatisés** pour un cluster Kubernetes 1.33 en haute disponibilité avec keepalived, MetalLB, Rancher et monitoring.

---

## 🚀 Démarrage Rapide (10 minutes)

### 1️⃣ Cloner le projet
```bash
git clone https://github.com/azurtech56/Kubernetes2.git
cd Kubernetes2/scripts
chmod +x *.sh
```

### 2️⃣ Configurer (optionnel)
```bash
nano config.sh  # Modifier IPs, hostnames, mots de passe
```

### 3️⃣ Installer avec le menu interactif
```bash
./k8s-menu.sh
```

Le menu vous guide étape par étape. C'est tout ! 🎉

---

## 📋 Prérequis

| Ressource | Minimum | Recommandé |
|-----------|---------|-----------|
| **OS** | Ubuntu 20.04+ ou Debian 12+ | Ubuntu 24.04 LTS |
| **Masters** | 3 nœuds | 3 nœuds |
| **CPU par nœud** | 2 | 4+ |
| **RAM par nœud** | 4 GB | 8 GB+ |
| **Disque** | 20 GB | 50 GB+ |
| **Réseau** | Même subnet (L2) | 1 Gbps+ |

---

## 🏗️ Architecture

```
                    ┌─────────────────┐
                    │   VIP k8s       │
                    │  192.168.0.200  │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
   ┌────▼────┐          ┌────▼────┐          ┌────▼────┐
   │ Master1 │          │ Master2 │          │ Master3 │
   │.201     │          │.202     │          │.203     │
   └─────────┘          └─────────┘          └─────────┘
        │                    │                    │
        └────────────────────┼────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
   ┌────▼────┐          ┌────▼────┐          ┌────▼────┐
   │ Worker1 │          │ Worker2 │          │ Worker3 │
   │.211     │          │.212     │          │.213     │
   └─────────┘          └─────────┘          └─────────┘
```

---

## 🔧 Composants Installés

| Composant | Version | Rôle |
|-----------|---------|------|
| **Kubernetes** | 1.33.0 | Orchestration |
| **containerd** | Latest | Runtime |
| **Calico** | Latest | Réseau (CNI) |
| **keepalived** | Latest | HA / VIP |
| **MetalLB** | Latest | Load Balancer |
| **Rancher** | Latest | Interface web |
| **Prometheus** | Latest | Monitoring |
| **Grafana** | Latest | Dashboards |
| **cert-manager** | v1.17.0 | TLS |

---

<<<<<<< HEAD
## 📜 Scripts Disponibles
=======
### Logiciels requis
Les scripts installeront automatiquement:
- containerd
- kubeadm, kubelet, kubectl
- keepalived (pour les masters)
- Helm (pour les masters)

## 🚀 Installation rapide

### Méthode 1: Menu interactif (Recommandé)

```bash
# 1. Cloner le repository
git clone https://github.com/azurtech56/Kubernetes2.git
cd Kubernetes2/scripts

# 2. Rendre les scripts exécutables
chmod +x *.sh

# 3. (Optionnel) Modifier la configuration
nano config.sh

# 4. Lancer le menu interactif
./k8s-menu.sh
```

Le **menu interactif** vous guide à travers toutes les étapes d'installation avec un assistant intégré !

### Méthode 2: Installation manuelle

```bash
# 1. Cloner le repository
git clone https://github.com/azurtech56/Kubernetes2.git
cd Kubernetes2/scripts

# 2. Rendre les scripts exécutables
chmod +x *.sh

# 3. Continuer avec les étapes ci-dessous...
```

### 2. Configuration de tous les nœuds

**Sur TOUS les nœuds (masters et workers):**

```bash
sudo ./common-setup.sh
```

### 3. Configuration des masters

**Sur TOUS les masters (k8s01-1, k8s01-2, k8s01-3):**

```bash
sudo ./master-setup.sh
sudo ./setup-keepalived.sh
```

Le script `setup-keepalived.sh` vous demandera de choisir le rôle (Master 1, 2 ou 3).

### 4. Initialisation du cluster

**Sur le premier master UNIQUEMENT (k8s01-1):**

```bash
sudo ./init-cluster.sh
```

Le script vous proposera automatiquement d'installer **Calico CNI** et le **Storage Provisioner**.
Acceptez en appuyant sur **[Y]** (recommandé).

Sauvegardez les commandes `kubeadm join` affichées !

### 5. Ajout des autres masters

**Sur k8s01-2 et k8s01-3:**

Utilisez la commande `kubeadm join` avec `--control-plane` générée à l'étape 4.

```bash
sudo kubeadm join k8s:6443 --token <token> \
    --discovery-token-ca-cert-hash sha256:<hash> \
    --control-plane \
    --certificate-key <cert-key>

# Configurer kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### 6. Ajout des workers

**Sur chaque worker:**

Utilisez la commande `kubeadm join` SANS `--control-plane` générée à l'étape 4.

```bash
sudo ./worker-setup.sh

sudo kubeadm join k8s:6443 --token <token> \
    --discovery-token-ca-cert-hash sha256:<hash>
```

### 7. Installation des add-ons (optionnel)

**Sur le premier master (k8s01-1):**

```bash
# MetalLB (Load Balancer)
./install-metallb.sh

# Rancher (Interface Web)
./install-rancher.sh

# Monitoring (Prometheus + Grafana + cAdvisor)
./install-monitoring.sh
```

## 📦 Installation détaillée

### Guides de référence

Pour une installation manuelle détaillée, consultez les guides dans le dossier [docs/](docs/) :

- **[Installation Kubernetes 1.32.txt](docs/Installation%20Kubernetes%201.32.txt)** - Guide complet pas à pas
- **[Configuration HA avec keepalived.txt](docs/Configuration%20HA%20avec%20keepalived.txt)** - Guide détaillé keepalived

Ces guides sont utiles pour :
- 📖 Comprendre en détail chaque étape
- 🎓 Apprendre les commandes Kubernetes
- 🔧 Personnaliser des configurations avancées
- 🐛 Diagnostiquer des problèmes

💡 **Recommandation** : Pour une installation moderne et rapide, utilisez plutôt le [menu interactif](#menu-interactif) !

## 🔧 Composants installés

| Composant | Version | Description | Installation |
|-----------|---------|-------------|--------------|
| **Kubernetes** | 1.32 | Orchestrateur de conteneurs | Auto |
| **containerd** | Latest | Runtime de conteneurs | Auto |
| **Calico** | Latest | Plugin réseau (CNI) | Auto ✅ |
| **local-path-provisioner** | v0.0.30 | Stockage persistant (Rancher) | Auto ✅ |
| **keepalived** | Latest | Haute disponibilité (IP virtuelle) | Auto |
| **MetalLB** | Latest | Load Balancer pour bare metal | Optionnel |
| **Rancher** | Latest | Interface de gestion web | Optionnel |
| **Prometheus** | Latest | Monitoring et alerting | Optionnel |
| **Grafana** | Latest | Visualisation des métriques | Optionnel |
| **cAdvisor** | Latest | Monitoring des conteneurs | Optionnel |
| **cert-manager** | v1.17.0 | Gestion des certificats TLS | Optionnel |

## 📜 Scripts disponibles

### Scripts de base

| Script | Description | Où l'exécuter |
|--------|-------------|---------------|
| `common-setup.sh` | Configuration commune pour tous les nœuds | Tous les nœuds |
| `master-setup.sh` | Configuration spécifique aux masters | Tous les masters |
| `worker-setup.sh` | Configuration spécifique aux workers | Tous les workers |
| `setup-keepalived.sh` | Configuration de keepalived (HA) | Tous les masters |
| `init-cluster.sh` | Initialisation du cluster | Premier master uniquement |

### Scripts des add-ons

| Script | Description | Où l'exécuter | Type |
|--------|-------------|---------------|------|
| `install-calico.sh` | Installation de Calico CNI | Premier master | Auto ✅ |
| `install-storage.sh` | Installation du stockage persistant | Premier master | Auto ✅ |
| `install-metallb.sh` | Installation de MetalLB | Premier master | Optionnel |
| `install-rancher.sh` | Installation de Rancher | Premier master | Optionnel |
| `install-monitoring.sh` | Installation de Prometheus + Grafana | Premier master | Optionnel |

### Script de gestion
>>>>>>> 9ba4bd49354a5c53a3f7b546b5cb7592abe0a53f

| Script | Description |
|--------|-------------|
| **k8s-menu.sh** | ⭐ Menu interactif (recommandé) |
| common-setup.sh | Configuration commune tous les nœuds |
| master-setup.sh | Configuration des masters |
| worker-setup.sh | Configuration des workers |
| init-cluster.sh | Initialisation du cluster |
| setup-keepalived.sh | Haute disponibilité (VIP) |
| install-calico.sh | Réseau Calico |
| install-metallb.sh | Load Balancer |
| install-rancher.sh | Interface Rancher |
| install-monitoring.sh | Prometheus + Grafana |

---

## 📖 Documentation

### Guides d'Installation
- **[QUICKSTART.md](QUICKSTART.md)** - Installation express en 5 étapes
- **[MENU-GUIDE.md](MENU-GUIDE.md)** - Guide du menu interactif

### Guides de Configuration
- **[CONFIGURATION-GUIDE.md](CONFIGURATION-GUIDE.md)** - Personnaliser config.sh
- **[DEBIAN-COMPATIBILITY.md](DEBIAN-COMPATIBILITY.md)** - Support Debian 12/13

### Guides Techniques
- **[docs/Installation Kubernetes 1.33.txt](docs/Installation%20Kubernetes%201.32.txt)** - Guide complet détaillé
- **[docs/Configuration HA avec keepalived.txt](docs/Configuration%20HA%20avec%20keepalived.txt)** - HA en détail

---

## ✅ Vérifier le Cluster

```bash
<<<<<<< HEAD
# Voir les nœuds
=======
cd Kubernetes2/scripts
./k8s-menu.sh
```

### Fonctionnalités principales

- 🎯 **Assistant d'installation** - Installation guidée selon le rôle du nœud (Master 1, Master 2/3, Worker)
- 📜 **Installation par étapes** - Contrôle manuel de chaque script
- 🧩 **Gestion des add-ons** - Installation de MetalLB, Rancher, Monitoring
- 🔧 **Gestion du cluster** - Affichage des nœuds, pods, services, génération de tokens
- 🔍 **Diagnostics** - Vérification de keepalived, MetalLB, Calico, logs des pods
- 📖 **Aide intégrée** - Architecture, ordre d'installation, ports, commandes utiles

### Exemple d'utilisation

```
╔════════════════════════════════════════════════════════════════╗
║  Kubernetes 1.32 - Haute Disponibilité (HA)                   ║
║  Menu d'installation et de gestion                            ║
╚════════════════════════════════════════════════════════════════╝

═══ MENU PRINCIPAL ═══

[1]  Installation complète (Assistant)  ← Recommandé pour débuter
[2]  Installation par étapes
[3]  Installation des Add-ons
[4]  Gestion du cluster
[5]  Vérifications et diagnostics
[6]  Informations et aide

[0]  Quitter
```

📖 **Guide complet du menu** : [MENU-GUIDE.md](MENU-GUIDE.md)

## ⚙️ Configuration

### Fichier de configuration centralisé

Avant de lancer l'installation, personnalisez votre cluster en modifiant le fichier **`config.sh`** :

```bash
nano scripts/config.sh
```

#### Variables principales :

```bash
# Nom de domaine (tous les FQDN seront générés automatiquement)
export DOMAIN_NAME="home.local"

# IP Virtuelle et Masters
export VIP="192.168.0.200"
export MASTER1_IP="192.168.0.201"
export MASTER2_IP="192.168.0.202"
export MASTER3_IP="192.168.0.203"

# Workers
export WORKER1_IP="192.168.0.211"
export WORKER2_IP="192.168.0.212"
export WORKER3_IP="192.168.0.213"
export WORKER_COUNT=3

# MetalLB
export METALLB_IP_START="192.168.0.220"
export METALLB_IP_END="192.168.0.240"

# Rancher
export RANCHER_SUBDOMAIN="rancher"  # → rancher.home.local
export RANCHER_PASSWORD="admin"

# Kubernetes
export K8S_VERSION="1.32.2"
export POD_SUBNET="11.0.0.0/16"
export SERVICE_SUBNET="10.0.0.0/16"
```

📖 **Guide complet de configuration** : [CONFIGURATION-GUIDE.md](CONFIGURATION-GUIDE.md)

Tous les scripts utilisent automatiquement ces variables !

### Afficher la configuration actuelle

```bash
source scripts/config.sh
show_config
```

### Valider la configuration

```bash
source scripts/config.sh
validate_config
```

### Configuration manuelle (ancienne méthode)

### Configuration /etc/hosts

Ajoutez ces lignes sur TOUS les nœuds:

```bash
192.168.0.200 k8s.home.local k8s
192.168.0.201 k8s01-1.home.local k8s01-1
192.168.0.202 k8s01-2.home.local k8s01-2
192.168.0.203 k8s01-3.home.local k8s01-3
```

### Personnalisation

Les scripts utilisent des valeurs par défaut que vous pouvez modifier:

#### MetalLB
- Plage IP: `192.168.0.220-192.168.0.240` (21 IPs, pas de collision avec nœuds)
- Interface: Détection automatique (ou `ens33` par défaut)

#### Rancher
- Hostname: `rancher.home.local`
- Password: `admin`

#### keepalived
- IP Virtuelle: `192.168.0.200`
- Password VRRP: `K8s_HA_Pass`
- Router ID: `51`

Pour personnaliser, éditez les variables au début de chaque script.

## ✔️ Vérification

### Vérifier l'état du cluster

```bash
# Vérifier les nœuds
>>>>>>> 9ba4bd49354a5c53a3f7b546b5cb7592abe0a53f
kubectl get nodes -o wide

# Voir tous les pods
kubectl get pods -A

# État du cluster
kubectl cluster-info

# Tests avec une app de test
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --type=LoadBalancer --port=80
```

---

## 🔍 Troubleshooting

### Les nœuds restent NotReady

**Vérifier Calico** :
```bash
kubectl get pods -n kube-system | grep calico
kubectl logs -n kube-system -l k8s-app=calico-node
```

**Problème de lien symbolique Calico** (Debian) :
```bash
# Si vous voyez : "calico-node" CrashLoopBackOff ou "CNI plugin not found"

# Créer les liens symboliques
sudo ln -s /opt/cni/bin/calico /usr/lib/cni/calico
sudo ln -s /opt/cni/bin/calico-ipam /usr/lib/cni/calico-ipam

# Vérifier
ls -l /usr/lib/cni/ | grep calico

# Redémarrer Calico
kubectl rollout restart daemonset/calico-node -n kube-system
```

### L'IP virtuelle ne bascule pas
```bash
sudo systemctl status keepalived
sudo journalctl -u keepalived -n 50
```

### MetalLB n'attribue pas d'IP
```bash
kubectl get pods -n metallb-system
kubectl get ipaddresspools.metallb.io -n metallb-system
```

---

## 🔐 Sécurité

⚠️ **Avant production, changez ces mots de passe dans `config.sh` :**
```bash
export VRRP_PASSWORD="VotreMdpFort8chars"      # Keepalived
export RANCHER_PASSWORD="VotreMdpAdmin16+"    # Rancher
export GRAFANA_PASSWORD="VotreMdpGrafana16+"  # Grafana
```

---

## 📞 Support

- **Issues** : [GitHub Issues](https://github.com/azurtech56/Kubernetes2/issues)
- **Logs** : `/var/log/k8s-setup/`
- **Docs techniques** : `docs/` folder
- **Configuration** : `scripts/config.sh`

---

## 📜 Licence

MIT License - Libre d'utilisation et de modification.

---

**Note** : Ce projet est conçu pour développement, test et homelab. Pour la production, consultez un expert et adaptez selon vos besoins de sécurité.
