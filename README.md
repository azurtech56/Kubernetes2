# Kubernetes 1.32 - Haute Disponibilité (HA)

![Kubernetes](https://img.shields.io/badge/Kubernetes-1.32.2-blue)
![License](https://img.shields.io/badge/License-MIT-green)
![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%2F22.04%2F24.04-orange)
![Debian](https://img.shields.io/badge/Debian-12%2F13-red)

Scripts d'installation automatisés pour un cluster Kubernetes 1.32 en haute disponibilité avec keepalived, MetalLB, Rancher et monitoring (Prometheus + Grafana).

> 🚀 **Pressé ?** Consultez le guide [QUICKSTART.md](QUICKSTART.md) pour installer en 10 minutes !

## 📋 Table des matières

- [🏗️ Architecture](#️-architecture)
- [✅ Prérequis](#-prérequis)
- [🚀 Installation rapide](#-installation-rapide)
- [📦 Installation détaillée](#-installation-détaillée)
- [🔧 Composants installés](#-composants-installés)
- [📜 Scripts disponibles](#-scripts-disponibles)
- [📱 Menu interactif](#-menu-interactif)
- [⚙️ Configuration](#️-configuration)
- [✔️ Vérification](#️-vérification)
- [🔍 Troubleshooting](#-troubleshooting)
- [🧪 Commandes utiles](#-commandes-utiles)
- [🐧 Compatibilité Debian](#-compatibilité-debian)
- [📖 Documentation complémentaire](#-documentation-complémentaire)
- [🤝 Contribution](#-contribution)
- [📜 Licence](#-licence)
- [👤 Auteur](#-auteur)

## 🏗️ Architecture

### Exemple de configuration

> ℹ️ **Note** : Ceci est un exemple de configuration. Vous pouvez adapter le nombre de workers selon vos besoins en modifiant le fichier [scripts/config.sh](scripts/config.sh).

```
                    ┌─────────────────┐
                    │   IP Virtuelle  │
                    │  192.168.0.200  │
                    │      (k8s)      │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
   ┌────▼────┐          ┌────▼────┐          ┌────▼────┐
   │ Master1 │          │ Master2 │          │ Master3 │
   │k8s01-1  │          │k8s01-2  │          │k8s01-3  │
   │.201     │          │.202     │          │.203     │
   └─────────┘          └─────────┘          └─────────┘
        │                    │                    │
        └────────────────────┼────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
   ┌────▼────┐          ┌────▼────┐          ┌────▼────┐
   │ Worker1 │          │ Worker2 │          │ Worker3 │
   │k8s-w-1  │          │k8s-w-2  │          │k8s-w-3  │
   │.211     │          │.212     │          │.213     │
   └─────────┘          └─────────┘          └─────────┘
```

### Configuration réseau (exemple)
- **IP Virtuelle (VIP)**: `192.168.0.200` → `k8s.home.local`
- **Master 1**: `192.168.0.201` → `k8s01-1.home.local`
- **Master 2**: `192.168.0.202` → `k8s01-2.home.local`
- **Master 3**: `192.168.0.203` → `k8s01-3.home.local`
- **Worker 1**: `192.168.0.211` → `k8s-worker-1.home.local`
- **Worker 2**: `192.168.0.212` → `k8s-worker-2.home.local`
- **Worker 3**: `192.168.0.213` → `k8s-worker-3.home.local`
- **MetalLB Pool**: `192.168.0.220-192.168.0.240` (21 IPs pour services LoadBalancer)

## ✅ Prérequis

### Système d'exploitation
- **Ubuntu**: 20.04, 22.04 ou 24.04 LTS
- **Debian**: 12 (Bookworm) ou 13 (Trixie)
- Minimum 2 CPU, 4 GB RAM par nœud
- 20 GB d'espace disque libre

### Configuration réseau
- Tous les nœuds sur le même réseau L2 (même subnet)
- Résolution DNS ou fichier `/etc/hosts` configuré
- Accès Internet pour télécharger les images

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

| Script | Description |
|--------|-------------|
| **`k8s-menu.sh`** | **Menu interactif principal** - Interface console pour gérer toute l'installation |
| `config.sh` | Fichier de configuration centralisé (IPs, hostnames, etc.) |

## 📱 Menu interactif

Le **menu interactif** `k8s-menu.sh` est l'outil principal pour installer et gérer votre cluster Kubernetes.

### Lancement

```bash
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
kubectl get nodes -o wide

# Vérifier tous les pods
kubectl get pods -A

# Vérifier l'état du cluster
kubectl cluster-info

# Vérifier les certificats
kubeadm certs check-expiration
```

### Vérifier keepalived

```bash
# Vérifier l'état de keepalived
sudo systemctl status keepalived

# Voir les logs
sudo journalctl -u keepalived -f

# Vérifier l'IP virtuelle
ip addr show ens33 | grep 192.168.0.200
```

### Tester le basculement HA

```bash
# Sur le master principal (k8s01-1)
sudo systemctl stop keepalived

# L'IP virtuelle devrait basculer sur k8s01-2
# Vérifier depuis un autre nœud:
kubectl get nodes
```

### Vérifier MetalLB

```bash
# Créer un service de test
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Vérifier l'IP externe
kubectl get svc nginx
```

## 🔍 Troubleshooting

### Les nœuds restent en NotReady

```bash
# Vérifier les pods Calico
kubectl get pods -n kube-system | grep calico

# Redémarrer Calico si nécessaire
kubectl rollout restart daemonset/calico-node -n kube-system
```

### L'IP virtuelle ne bascule pas

```bash
# Vérifier que le protocole VRRP est autorisé
sudo ufw allow proto vrrp

# Vérifier les logs keepalived
sudo journalctl -u keepalived -n 50

# Vérifier la configuration
cat /etc/keepalived/keepalived.conf
```

### Impossible de joindre le cluster

```bash
# Générer une nouvelle commande join
kubeadm token create --print-join-command

# Pour un master, récupérer le certificate-key
sudo kubeadm init phase upload-certs --upload-certs
```

### MetalLB n'attribue pas d'IP

```bash
# Vérifier les pods MetalLB
kubectl get pods -n metallb-system

# Vérifier la configuration
kubectl get ipaddresspools.metallb.io -n metallb-system
kubectl get l2advertisements.metallb.io -n metallb-system
```

## 🧪 Commandes utiles

```bash
# Lister tous les services LoadBalancer
kubectl get svc -A | grep LoadBalancer

# Récupérer le mot de passe Grafana
kubectl get secret --namespace monitoring prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d

# Récupérer le mot de passe Rancher
kubectl get secret --namespace cattle-system bootstrap-secret \
  -o jsonpath="{.data.bootstrapPassword}" | base64 -d

# Vérifier l'utilisation des ressources
kubectl top nodes
kubectl top pods -A

# Drainer un nœud pour maintenance
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Remettre un nœud en service
kubectl uncordon <node-name>
```

## 🐧 Compatibilité Debian

Les scripts sont **100% compatibles** avec Debian 12 (Bookworm) et Debian 13 (Trixie).

Pour plus de détails, consultez le guide complet : **[DEBIAN-COMPATIBILITY.md](DEBIAN-COMPATIBILITY.md)**

Points clés :
- ✅ Même gestionnaire de paquets (APT)
- ✅ Même système d'init (systemd)
- ✅ Repository Kubernetes officiel pour Debian
- ✅ Détection automatique de l'interface réseau
- ⚠️ Installer `ufw` si nécessaire : `sudo apt install -y ufw`

## 📖 Documentation complémentaire

- [Documentation officielle Kubernetes](https://kubernetes.io/docs/)
- [Documentation Calico](https://docs.projectcalico.org/)
- [Documentation MetalLB](https://metallb.universe.tf/)
- [Documentation Rancher](https://rancher.com/docs/)
- [Documentation Prometheus](https://prometheus.io/docs/)
- [keepalived Documentation](https://www.keepalived.org/documentation.html)

## 🤝 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à:

1. Fork le projet
2. Créer une branche (`git checkout -b feature/amelioration`)
3. Commit vos changements (`git commit -m 'Ajout d'une fonctionnalité'`)
4. Push vers la branche (`git push origin feature/amelioration`)
5. Ouvrir une Pull Request

## 📜 Licence

Ce projet est sous licence **MIT** - voir le fichier [LICENSE](LICENSE) pour plus de détails.

### Ce que vous pouvez faire :
- ✅ Utiliser commercialement
- ✅ Modifier le code
- ✅ Distribuer
- ✅ Utiliser en privé

### Conditions :
- 📄 Inclure la licence et le copyright dans vos copies
- ⚠️ Aucune garantie fournie

## 👤 Auteur

Créé pour faciliter le déploiement de clusters Kubernetes en haute disponibilité.

**Projet Open Source** - Contributeurs bienvenus !

## ⭐ Remerciements

- La communauté Kubernetes
- Les équipes derrière Calico, MetalLB, Rancher et Prometheus
- Tous les contributeurs open source

---

**Note**: Ce projet est destiné à des environnements de développement, test ou homelab. Pour une utilisation en production, consultez un expert Kubernetes et adaptez la configuration à vos besoins spécifiques de sécurité et de performance.
