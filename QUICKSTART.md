# ⚡ Installation Express (15 minutes)

Installation rapide de Kubernetes 1.33 HA avec le menu interactif.

---

## 📋 Prérequis

- **3+ serveurs** Ubuntu 20.04+ ou Debian 12+
- **Minimum** : 2 CPU, 4 GB RAM par serveur
- **Réseau** : Même subnet, accès SSH

---

## 🚀 5 Étapes Simples

### 1️⃣ Télécharger
```bash
git clone https://github.com/azurtech56/Kubernetes2.git
cd Kubernetes2/scripts
chmod +x *.sh
```

### 2️⃣ Configurer (optionnel)
```bash
nano config.sh
# Adapter : IPs, hostnames, mots de passe
```

### 3️⃣ Copier sur les serveurs
```bash
scp -r . user@192.168.0.201:~/k8s
scp -r . user@192.168.0.202:~/k8s
scp -r . user@192.168.0.203:~/k8s
```

### 4️⃣ Installer
```bash
# Sur chaque serveur
cd ~/k8s
sudo ./k8s-menu.sh

# Sélectionner : [1] Installation complète
# Suivre le menu...
```

### 5️⃣ Vérifier
```bash
kubectl get nodes -o wide
kubectl get pods -A
```

---

## ✅ Checklist

- [ ] Tous les nœuds **Ready**
- [ ] Pods Calico **Running**
- [ ] Pods système **Running**
- [ ] VIP répond : `ping k8s.home.local`
- [ ] Rancher accessible : https://rancher.home.local

---

## 🆘 Aide Rapide

### Nœuds NotReady
```bash
kubectl get pods -n kube-system | grep calico
kubectl logs -n kube-system -l k8s-app=calico-node
```

### VIP ne fonctionne pas
```bash
sudo systemctl status keepalived
ip addr | grep 192.168.0.200
```

### MetalLB pas d'IP
```bash
kubectl get pods -n metallb-system
kubectl get ipaddresspools.metallb.io -n metallb-system
```

---

## 📚 Documentation Complète

- [README.md](README.md) - Vue d'ensemble
- [CONFIGURATION-GUIDE.md](CONFIGURATION-GUIDE.md) - Configuration détaillée
- [MENU-GUIDE.md](MENU-GUIDE.md) - Guide du menu
- [DEBIAN-COMPATIBILITY.md](DEBIAN-COMPATIBILITY.md) - Support Debian
- [docs/](docs/) - Guides techniques

---

**C'est fait !** 🎉 Votre cluster Kubernetes 1.33 HA est prêt.
