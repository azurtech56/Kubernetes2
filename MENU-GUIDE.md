# 📱 Guide du Menu Interactif

Le menu interactif `k8s-menu.sh` est une interface console complète pour installer et gérer votre cluster Kubernetes en haute disponibilité.

## 🚀 Lancement du menu

```bash
cd Kubernetes2/scripts
./k8s-menu.sh
```

## 📋 Structure du menu

```
╔════════════════════════════════════════════════════════════════╗
║  Kubernetes 1.33 - Haute Disponibilité (HA)                   ║
║  Menu d'installation et de gestion                            ║
╚════════════════════════════════════════════════════════════════╝

═══ MENU PRINCIPAL ═══

[1]  Installation complète (Assistant)
[2]  Installation par étapes
[3]  Installation des Add-ons
[4]  Gestion du cluster
[5]  Vérifications et diagnostics
[6]  Informations et aide

[0]  Quitter
```

## 🎯 Fonctionnalités principales

### 1️⃣ Installation complète (Assistant)

Un **assistant intelligent** qui vous guide selon le rôle du nœud :

#### Option 1: Premier Master (k8s01-1)
Exécute automatiquement dans l'ordre :
1. ✅ Configuration commune (`common-setup.sh`)
2. ✅ Configuration master (`master-setup.sh`)
3. ✅ Configuration keepalived MASTER - Priority 101 (`setup-keepalived.sh`)
4. ✅ Initialisation du cluster (`init-cluster.sh`)
5. ✅ Installation Calico CNI (`install-calico.sh`)

#### Option 2: Master secondaire (k8s01-2 ou k8s01-3)
Exécute automatiquement :
1. ✅ Configuration commune
2. ✅ Configuration master
3. ✅ Configuration keepalived BACKUP
4. 📝 Affiche les instructions pour `kubeadm join --control-plane`

#### Option 3: Worker
Exécute automatiquement :
1. ✅ Configuration commune
2. ✅ Configuration worker
3. 📝 Affiche les instructions pour `kubeadm join`

### 2️⃣ Installation par étapes

Menu pour exécuter les scripts individuellement :

```
═══ INSTALLATION PAR ÉTAPES ═══

▶ Préparation (sur tous les nœuds)
[1]  Configuration commune (common-setup.sh)
[2]  Configuration Master (master-setup.sh)
[3]  Configuration Worker (worker-setup.sh)

▶ Haute Disponibilité (HA)
[4]  Configuration keepalived (setup-keepalived.sh)

▶ Cluster
[5]  Initialisation du cluster (init-cluster.sh)
[6]  Installation Calico CNI (install-calico.sh)
```

**Avantage** : Contrôle total sur chaque étape, utile pour le debugging ou les installations personnalisées.

### 3️⃣ Installation des Add-ons

Menu dédié aux composants optionnels :

```
═══ INSTALLATION DES ADD-ONS ═══

[1]  MetalLB - Load Balancer (install-metallb.sh)
[2]  Rancher - Interface Web (install-rancher.sh)
[3]  Monitoring - Prometheus + Grafana (install-monitoring.sh)
[4]  Installer tous les add-ons
```

**Option 4** lance séquentiellement tous les add-ons pour une installation complète automatique.

### 4️⃣ Gestion du cluster

Outils de gestion quotidienne :

```
═══ GESTION DU CLUSTER ═══

▶ Informations
[1]  Afficher les nœuds
[2]  Afficher tous les pods
[3]  Afficher les services LoadBalancer
[4]  État du cluster (cluster-info)

▶ Tokens et certificats
[5]  Générer commande kubeadm join
[6]  Vérifier expiration des certificats

▶ Mots de passe
[7]  Récupérer mot de passe Grafana
[8]  Récupérer mot de passe Rancher
```

**Utile pour** :
- Vérifier rapidement l'état du cluster
- Ajouter de nouveaux nœuds (génération de tokens)
- Récupérer les mots de passe des services

### 5️⃣ Vérifications et diagnostics

Outils de diagnostic et dépannage :

```
═══ VÉRIFICATIONS ET DIAGNOSTICS ═══

[1]  Vérifier l'état des pods système
[2]  Vérifier keepalived et IP virtuelle
[3]  Vérifier MetalLB
[4]  Vérifier Calico
[5]  Logs des pods (sélection interactive)
[6]  Test de déploiement nginx
[7]  Rapport complet du cluster
```

**Fonctionnalités** :
- **Option 2** : Vérifie que l'IP virtuelle est active
- **Option 5** : Permet de voir les logs d'un pod spécifique
- **Option 6** : Crée un déploiement nginx de test avec LoadBalancer
- **Option 7** : Génère un rapport complet (nœuds, pods, services, état)

### 6️⃣ Informations et aide

Documentation intégrée :

```
═══ INFORMATIONS ET AIDE ═══

[1]  Architecture du cluster
[2]  Ordre d'installation recommandé
[3]  Ports utilisés
[4]  Commandes utiles
[5]  À propos
```

**Parfait pour** :
- Visualiser l'architecture ASCII du cluster
- Se rappeler l'ordre d'installation
- Connaître les ports à ouvrir dans le firewall
- Voir les commandes kubectl utiles

## 🎨 Interface utilisateur

### Couleurs

Le menu utilise des couleurs pour une meilleure lisibilité :

- 🟢 **Vert** : Options du menu, messages de succès
- 🟡 **Jaune** : Questions, informations importantes
- 🔵 **Bleu** : Titres de sections
- 🔴 **Rouge** : Erreurs, option quitter
- 🟣 **Magenta** : Sous-titres de catégories
- 🔷 **Cyan** : Séparateurs, en-têtes

### Navigation

- Tapez le **numéro** de l'option souhaitée
- Appuyez sur **Entrée**
- Tapez **0** pour revenir au menu précédent
- Les confirmations utilisent **y/N** (Oui/Non)

## 📖 Exemples d'utilisation

### Scénario 1 : Installation complète d'un premier master

```bash
./k8s-menu.sh
# → Choisir [1] Installation complète (Assistant)
# → Choisir [1] Premier Master (k8s01-1)
# → Confirmer [y]
# → Attendre la fin de l'installation
# → Récupérer les commandes kubeadm join affichées
```

**Temps estimé** : 15-20 minutes

### Scénario 2 : Ajouter un worker

```bash
./k8s-menu.sh
# → Choisir [1] Installation complète (Assistant)
# → Choisir [3] Worker
# → Confirmer [y]
# → Copier la commande kubeadm join fournie par le premier master
```

**Temps estimé** : 5-10 minutes

### Scénario 3 : Installer uniquement MetalLB

```bash
./k8s-menu.sh
# → Choisir [3] Installation des Add-ons
# → Choisir [1] MetalLB
# → Entrer la plage IP (ou valider la valeur par défaut)
# → Entrer l'interface réseau (ou valider la détection auto)
# → Confirmer [y]
```

**Temps estimé** : 2-3 minutes

### Scénario 4 : Vérifier le cluster après installation

```bash
./k8s-menu.sh
# → Choisir [5] Vérifications et diagnostics
# → Choisir [7] Rapport complet du cluster
# → Vérifier que tous les nœuds sont "Ready"
# → Vérifier que tous les pods système sont "Running"
```

### Scénario 5 : Récupérer le mot de passe Grafana

```bash
./k8s-menu.sh
# → Choisir [4] Gestion du cluster
# → Choisir [7] Récupérer mot de passe Grafana
# → Le mot de passe s'affiche
```

### Scénario 6 : Générer une nouvelle commande join

```bash
./k8s-menu.sh
# → Choisir [4] Gestion du cluster
# → Choisir [5] Générer commande kubeadm join
# → La commande complète s'affiche
```

## 🔧 Personnalisation

### Modifier la configuration avant l'installation

```bash
# 1. Éditer le fichier de configuration
nano scripts/config.sh

# 2. Modifier les variables (IPs, hostnames, etc.)
export VIP="192.168.1.200"
export MASTER1_IP="192.168.1.201"
# ... etc

# 3. Lancer le menu
./k8s-menu.sh
```

Le menu utilisera automatiquement votre configuration personnalisée !

### Vérifier la configuration actuelle

Depuis le menu :
```
[6] Informations et aide
[1] Architecture du cluster
```

Ou en ligne de commande :
```bash
source scripts/config.sh
show_config
```

## 🐛 Dépannage

### Le menu ne se lance pas

```bash
# Vérifier que vous êtes dans le bon répertoire
pwd
# Doit afficher: .../kubernetes-ha-setup/scripts

# Rendre le script exécutable
chmod +x k8s-menu.sh

# Vérifier la présence des autres scripts
ls -l *.sh
```

### "Scripts non trouvés dans le répertoire courant"

Le menu doit être lancé **depuis le répertoire scripts/** :

```bash
cd Kubernetes2/scripts
./k8s-menu.sh
```

### Les couleurs ne s'affichent pas

Votre terminal ne supporte peut-être pas les couleurs. Le menu fonctionnera quand même, mais sans couleurs.

Pour activer les couleurs :
```bash
export TERM=xterm-256color
./k8s-menu.sh
```

### Un script échoue

1. Notez le code d'erreur affiché
2. Consultez les logs du script
3. Utilisez le menu **[5] Vérifications et diagnostics** pour plus d'infos
4. Relancez le script individuellement avec **[2] Installation par étapes**

## ✨ Fonctionnalités avancées

### Exécution non-interactive (à venir)

Pour automatiser complètement :

```bash
# Variables d'environnement pour l'assistant
export NODE_ROLE="master1"
export AUTO_CONFIRM="yes"
./k8s-menu.sh
```

### Logs détaillés

Tous les scripts génèrent des logs détaillés :

```bash
# Voir les logs d'un script
less kubeadm-init.log  # Généré par init-cluster.sh
less join-commands.txt # Commandes de join
```

### Sauvegarde de la configuration

```bash
# Sauvegarder votre config personnalisée
cp scripts/config.sh scripts/config.sh.backup

# Restaurer
cp scripts/config.sh.backup scripts/config.sh
```

## 📚 Commandes équivalentes

| Action dans le menu | Commande manuelle équivalente |
|---------------------|-------------------------------|
| Afficher les nœuds | `kubectl get nodes -o wide` |
| Afficher tous les pods | `kubectl get pods -A` |
| Services LoadBalancer | `kubectl get svc -A \| grep LoadBalancer` |
| État du cluster | `kubectl cluster-info` |
| Générer join command | `kubeadm token create --print-join-command` |
| Mot de passe Grafana | `kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" \| base64 -d` |
| Vérifier certificats | `kubeadm certs check-expiration` |

## 🎓 Bonnes pratiques

1. **Toujours commencer par l'assistant** pour les installations initiales
2. **Vérifier la configuration** avant de lancer l'installation (`show_config`)
3. **Sauvegarder les commandes join** générées par `init-cluster.sh`
4. **Utiliser le rapport complet** après chaque installation pour valider
5. **Tester avec nginx** pour vérifier MetalLB avant de déployer des applications

## 🔗 Voir aussi

- [README.md](README.md) - Documentation principale
- [config.sh](scripts/config.sh) - Fichier de configuration
- [DEBIAN-COMPATIBILITY.md](DEBIAN-COMPATIBILITY.md) - Guide Debian
- [docs/Installation Kubernetes 1.32.txt](docs/Installation%20Kubernetes%201.32.txt) - Guide détaillé

---

**Astuce** : Gardez une session SSH ouverte pendant l'installation pour pouvoir réagir en cas de problème !
