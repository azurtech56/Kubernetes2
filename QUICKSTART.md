# ⚡ Démarrage Rapide

Guide ultra-rapide pour installer Kubernetes 1.32 HA en 10 minutes !

## 📦 Prérequis

- 3 serveurs Ubuntu 20.04+ ou Debian 12+ (masters)
- Minimum 2 CPU, 4 GB RAM par serveur
- Connexion SSH sur tous les serveurs

## 🚀 Installation Express

### Étape 1: Télécharger (1 min)

Sur votre machine locale :

```bash
git clone https://github.com/azurtech56/Kubernetes2.git
cd Kubernetes2
```

### Étape 2: Copier sur les serveurs (2 min)

```bash
# Copier sur chaque serveur
scp -r scripts/ user@192.168.0.201:~
scp -r scripts/ user@192.168.0.202:~
scp -r scripts/ user@192.168.0.203:~
```

### Étape 3: Configuration (1 min)

**Sur le premier master (192.168.0.201)** :

```bash
cd scripts
nano config.sh  # Modifier si nécessaire (IPs, hostnames)
```

### Étape 4: Installation automatique (6 min)

#### Sur 192.168.0.201 (k8s01-1) - Premier Master

```bash
cd scripts
chmod +x *.sh
./k8s-menu.sh

# Dans le menu:
# [1] Installation complète (Assistant)
# [1] Premier Master (k8s01-1)
# [y] Confirmer

# ⏱️ Attendre 5-6 minutes
# ✅ Sauvegarder les commandes "kubeadm join" affichées !
```

#### Sur 192.168.0.202 (k8s01-2) - Second Master

```bash
cd scripts
chmod +x *.sh
./k8s-menu.sh

# Dans le menu:
# [1] Installation complète (Assistant)
# [2] Master secondaire
# [y] Confirmer

# Ensuite, copier la commande "kubeadm join --control-plane" fournie par k8s01-1
```

#### Sur 192.168.0.203 (k8s01-3) - Troisième Master

Même chose que k8s01-2.

### Étape 5: Vérification (30 sec)

**Sur k8s01-1** :

```bash
kubectl get nodes
# Tous les nœuds doivent être "Ready"

kubectl get pods -A
# Tous les pods doivent être "Running"
```

## 🎉 C'est fait !

Votre cluster Kubernetes HA est opérationnel !

## ➕ Ajouter les add-ons (optionnel)

**Sur k8s01-1** :

```bash
./k8s-menu.sh

# [3] Installation des Add-ons
# [4] Installer tous les add-ons
```

Installe automatiquement :
- ✅ MetalLB (Load Balancer)
- ✅ Rancher (Interface Web)
- ✅ Prometheus + Grafana (Monitoring)

## 📊 Accéder aux interfaces

### Grafana

```bash
# Récupérer l'IP du service
kubectl get svc -n monitoring prometheus-grafana

# Récupérer le mot de passe
kubectl get secret --namespace monitoring prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d

# Se connecter à http://<IP-EXTERNE>:80
# User: admin
# Password: <mot-de-passe-récupéré>
```

### Rancher

```bash
# Récupérer l'IP du service
kubectl get svc -n cattle-system rancher-lb-https

# Se connecter à https://<IP-EXTERNE>
# User: admin
# Password: (voir config.sh ou bootstrap-secret)
```

## 🔧 Commandes utiles

```bash
# Voir tous les nœuds
kubectl get nodes -o wide

# Voir tous les pods
kubectl get pods -A

# Voir les services LoadBalancer
kubectl get svc -A | grep LoadBalancer

# Ajouter un nouveau nœud (générer la commande)
kubeadm token create --print-join-command

# Vérifier keepalived
systemctl status keepalived
ip addr | grep 192.168.0.200
```

## ❓ Problèmes ?

### Les nœuds ne sont pas "Ready"

```bash
# Vérifier Calico
kubectl get pods -n kube-system | grep calico

# Redémarrer si nécessaire
kubectl rollout restart daemonset/calico-node -n kube-system
```

### L'IP virtuelle ne fonctionne pas

```bash
# Vérifier keepalived sur chaque master
systemctl status keepalived

# Vérifier quelle machine a l'IP
ip addr show | grep 192.168.0.200

# Voir les logs
journalctl -u keepalived -f
```

### Un pod ne démarre pas

```bash
# Voir les logs
kubectl get pods -A
kubectl logs -n <namespace> <pod-name>
kubectl describe pod -n <namespace> <pod-name>
```

## 📚 Documentation complète

- **[README.md](README.md)** - Documentation principale
- **[MENU-GUIDE.md](MENU-GUIDE.md)** - Guide du menu interactif
- **[DEBIAN-COMPATIBILITY.md](DEBIAN-COMPATIBILITY.md)** - Spécificités Debian
- **[Installation Kubernetes 1.32.txt](Installation%20Kubernetes%201.32.txt)** - Guide détaillé pas à pas

## 🎯 Prochaines étapes

1. ✅ Tester un déploiement :
   ```bash
   kubectl create deployment nginx --image=nginx
   kubectl expose deployment nginx --port=80 --type=LoadBalancer
   kubectl get svc nginx
   ```

2. ✅ Explorer Rancher pour gérer le cluster via interface web

3. ✅ Configurer des dashboards Grafana pour monitorer le cluster

4. ✅ Déployer vos applications !

## 💡 Astuces

### Gagner du temps

- Utilisez **tmux** ou **screen** pour lancer les installations en parallèle
- Préparez un fichier Ansible pour copier les scripts sur tous les serveurs
- Créez des snapshots/images après l'installation

### Sécurité

```bash
# Changer les mots de passe par défaut dans config.sh AVANT l'installation
export RANCHER_PASSWORD="VotreMotDePasseFort123!"
export VRRP_PASSWORD="K8sSecur3"
```

### Performance

```bash
# Augmenter les limites pour les pods
kubectl edit configmap -n kube-system kubelet-config

# Optimiser etcd
# Voir la documentation officielle Kubernetes
```

---

**Besoin d'aide ?** Ouvrez une issue sur GitHub !

**Vous aimez le projet ?** ⭐ Laissez une étoile sur GitHub !
