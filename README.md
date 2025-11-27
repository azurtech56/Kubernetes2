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
chmod +x *.sh core/*.sh addons/*.sh utils/*.sh
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

## 📂 Structure des Scripts

```
scripts/
├─ 🔴 RACINE (Menu + Config + Libs)
│  ├─ k8s-menu.sh          ⭐ Menu principal (recommandé)
│  ├─ config.sh            📝 Configuration globale
│  ├─ lib-config.sh        🔧 Config loader
│  ├─ generate-env.sh      🔐 Auto-generate secrets
│  ├─ generate-hosts.sh    🌐 /etc/hosts generation
│  ├─ lib/                 📚 Shared libraries (9 files)
│  └─ .env.example         📋 Secrets template
│
├─ 🟢 core/ (Essentials HA)
│  ├─ common-setup.sh
│  ├─ master-setup.sh
│  ├─ worker-setup.sh
│  ├─ setup-keepalived.sh
│  ├─ init-cluster.sh
│  ├─ install-calico.sh
│  ├─ validate-config.sh
│  └─ check-prerequisites.sh
│
├─ 🟠 addons/ (Optionnels)
│  ├─ install-monitoring.sh    (Prometheus + Grafana)
│  ├─ install-loki.sh          (Centralized logs)
│  ├─ install-rancher.sh       (Management UI)
│  ├─ install-metallb.sh       (Load Balancer)
│  ├─ install-storage.sh       (Storage)
│  ├─ integrate-v2.1.sh        (Integration)
│  └─ setup-auto-backup.sh     (Auto-backup)
│
└─ 🔵 utils/ (Maintenance)
   ├─ backup-cluster.sh        (Backup etcd)
   ├─ restore-cluster.sh       (Restore etcd)
   ├─ cleanup-cluster.sh       (Cleanup nodes)
   ├─ uninstall-cluster.sh     (Full uninstall)
   ├─ health-check.sh          (Health monitoring)
   └─ deploy-cluster.sh        (Deploy cluster)
```

### 📜 Scripts par Catégorie

**🟢 CORE (Installation HA - REQUIS)**
| Script | Description |
|--------|-------------|
| **k8s-menu.sh** | ⭐ Menu interactif (recommandé) |
| **core/common-setup.sh** | Configuration commune tous les nœuds |
| **core/master-setup.sh** | Configuration des masters |
| **core/worker-setup.sh** | Configuration des workers |
| **core/init-cluster.sh** | Initialisation du cluster |
| **core/setup-keepalived.sh** | Haute disponibilité (VIP) |
| **core/install-calico.sh** | Réseau Calico |

**🟠 ADDONS (Optionnels)**
| Script | Description |
|--------|-------------|
| **addons/install-metallb.sh** | Load Balancer |
| **addons/install-rancher.sh** | Interface Rancher |
| **addons/install-monitoring.sh** | Prometheus + Grafana |
| **addons/install-loki.sh** | Centralized logging |

**🔵 UTILS (Maintenance)**
| Script | Description |
|--------|-------------|
| **utils/backup-cluster.sh** | Backup etcd |
| **utils/restore-cluster.sh** | Restore etcd |
| **utils/health-check.sh** | Health monitoring |

---

## 📖 Documentation

### Guides d'Installation
- **[QUICKSTART.md](QUICKSTART.md)** - Installation express en 5 étapes
- **[MENU-GUIDE.md](MENU-GUIDE.md)** - Guide du menu interactif

### Guides de Configuration
- **[CONFIGURATION-GUIDE.md](CONFIGURATION-GUIDE.md)** - Personnaliser config.sh
- **[DEBIAN-COMPATIBILITY.md](DEBIAN-COMPATIBILITY.md)** - Support Debian 12/13

### Guides Techniques
- **[docs/Installation Kubernetes 1.32.txt](docs/Installation%20Kubernetes%201.32.txt)** - Guide complet détaillé
- **[docs/Configuration HA avec keepalived.txt](docs/Configuration%20HA%20avec%20keepalived.txt)** - HA en détail

---

## ✅ Vérifier le Cluster

```bash
# Voir les nœuds
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
