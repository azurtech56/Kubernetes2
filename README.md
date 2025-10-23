# Kubernetes 1.32 - Haute Disponibilité (HA)

![Kubernetes](https://img.shields.io/badge/Kubernetes-1.32-blue)
![License](https://img.shields.io/badge/License-Open--Source-green)
![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%2F22.04%2F24.04-orange)
![Debian](https://img.shields.io/badge/Debian-12%2F13-red)

Scripts d'installation automatisés pour un cluster Kubernetes 1.32 en haute disponibilité avec keepalived, MetalLB, Rancher et monitoring (Prometheus + Grafana).

## 📋 Table des matières

- [Architecture](#architecture)
- [Prérequis](#prérequis)
- [Installation rapide](#installation-rapide)
- [Installation détaillée](#installation-détaillée)
- [Composants installés](#composants-installés)
- [Scripts disponibles](#scripts-disponibles)
- [Configuration](#configuration)
- [Vérification](#vérification)
- [Troubleshooting](#troubleshooting)
- [Contribution](#contribution)
- [License](#license)

## 🏗️ Architecture

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
                ┌────────────┴────────────┐
                │                         │
           ┌────▼────┐               ┌────▼────┐
           │ Worker1 │               │ Worker2 │
           └─────────┘               └─────────┘
```

### Configuration réseau
- **IP Virtuelle (VIP)**: `192.168.0.200` → `k8s.home.local`
- **Master 1**: `192.168.0.201` → `k8s01-1.home.local`
- **Master 2**: `192.168.0.202` → `k8s01-2.home.local`
- **Master 3**: `192.168.0.203` → `k8s01-3.home.local`
- **MetalLB Pool**: `192.168.0.210-192.168.0.230`

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

### 1. Cloner le repository

```bash
git clone https://github.com/votre-user/kubernetes-ha-setup.git
cd kubernetes-ha-setup/scripts
chmod +x *.sh
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

Sauvegardez les commandes `kubeadm join` affichées !

### 5. Installation de Calico

**Sur le premier master (k8s01-1):**

```bash
./install-calico.sh
```

### 6. Ajout des autres masters

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

### 7. Ajout des workers

**Sur chaque worker:**

Utilisez la commande `kubeadm join` SANS `--control-plane` générée à l'étape 4.

```bash
sudo ./worker-setup.sh

sudo kubeadm join k8s:6443 --token <token> \
    --discovery-token-ca-cert-hash sha256:<hash>
```

### 8. Installation des add-ons (optionnel)

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

Pour une installation pas à pas détaillée, consultez le fichier [Installation Kubernetes 1.32.txt](Installation%20Kubernetes%201.32.txt).

## 🔧 Composants installés

| Composant | Version | Description |
|-----------|---------|-------------|
| **Kubernetes** | 1.32 | Orchestrateur de conteneurs |
| **containerd** | Latest | Runtime de conteneurs |
| **Calico** | Latest | Plugin réseau (CNI) |
| **keepalived** | Latest | Haute disponibilité (IP virtuelle) |
| **MetalLB** | Latest | Load Balancer pour bare metal |
| **Rancher** | Latest | Interface de gestion web |
| **Prometheus** | Latest | Monitoring et alerting |
| **Grafana** | Latest | Visualisation des métriques |
| **cAdvisor** | Latest | Monitoring des conteneurs |
| **cert-manager** | v1.17.0 | Gestion des certificats TLS |

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

| Script | Description | Où l'exécuter |
|--------|-------------|---------------|
| `install-calico.sh` | Installation de Calico CNI | Premier master |
| `install-metallb.sh` | Installation de MetalLB | Premier master |
| `install-rancher.sh` | Installation de Rancher | Premier master |
| `install-monitoring.sh` | Installation de Prometheus + Grafana | Premier master |

## ⚙️ Configuration

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
- Plage IP: `192.168.0.210-192.168.0.230`
- Interface: `ens33`

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

## 📝 License

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 👤 Auteur

Créé pour faciliter le déploiement de clusters Kubernetes en haute disponibilité.

## ⭐ Remerciements

- La communauté Kubernetes
- Les équipes derrière Calico, MetalLB, Rancher et Prometheus
- Tous les contributeurs open source

---

**Note**: Ce projet est destiné à des environnements de développement, test ou homelab. Pour une utilisation en production, consultez un expert Kubernetes et adaptez la configuration à vos besoins spécifiques de sécurité et de performance.
