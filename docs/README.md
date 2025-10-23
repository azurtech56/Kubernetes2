# 📚 Documentation Détaillée

Ce dossier contient la documentation détaillée et les guides de référence pour l'installation manuelle de Kubernetes HA.

## 📄 Fichiers disponibles

| Fichier | Description | Usage |
|---------|-------------|-------|
| **Installation Kubernetes 1.32.txt** | Guide détaillé pas à pas complet | Référence pour installation manuelle |
| **Configuration HA avec keepalived.txt** | Guide détaillé keepalived | Référence pour configuration HA |

## 🎯 Quand utiliser ces guides ?

### ✅ Utiliser ces guides si :
- Vous voulez comprendre **en détail** chaque étape
- Vous faites une installation **manuelle complète**
- Vous voulez une **référence textuelle** complète
- Vous devez **personnaliser** des étapes spécifiques
- Vous préférez la **ligne de commande pure** sans scripts

### ⚡ Utiliser plutôt les scripts si :
- Vous voulez installer **rapidement**
- Vous préférez une **interface guidée**
- Vous voulez une **installation automatisée**
- Vous êtes **débutant** avec Kubernetes

## 📖 Guides recommandés pour débuter

Pour une installation moderne et guidée, utilisez plutôt :

1. **[QUICKSTART.md](../QUICKSTART.md)** - Installation rapide en 10 minutes
2. **[MENU-GUIDE.md](../MENU-GUIDE.md)** - Utiliser le menu interactif
3. **[README.md](../README.md)** - Documentation principale

## 🔄 Relation avec les scripts

Les guides `.txt` de ce dossier décrivent les **mêmes opérations** que les scripts automatisés, mais :

| Guide TXT | Script équivalent |
|-----------|-------------------|
| Installation Kubernetes 1.32.txt | `k8s-menu.sh` (Assistant complet) |
| Section "Préparation" | `common-setup.sh` |
| Section "Masters" | `master-setup.sh` |
| Configuration HA keepalived | `setup-keepalived.sh` |
| Initialisation cluster | `init-cluster.sh` |
| Installation Calico | `install-calico.sh` |
| Installation MetalLB | `install-metallb.sh` |
| Installation Rancher | `install-rancher.sh` |
| Installation Monitoring | `install-monitoring.sh` |

## 💡 Avantage des scripts vs guides TXT

### Guides TXT (ce dossier)
- ✅ Documentation exhaustive
- ✅ Explications détaillées
- ✅ Personnalisation manuelle
- ❌ Plus long à suivre
- ❌ Risque d'erreurs de frappe
- ❌ Pas de validation automatique

### Scripts automatisés
- ✅ Installation rapide
- ✅ Validation automatique
- ✅ Configuration centralisée (config.sh)
- ✅ Interface guidée
- ✅ Détection d'erreurs
- ❌ Moins de contrôle fin

## 🎓 Apprentissage

Ces guides sont **excellents pour apprendre** :
- Comprendre ce que font les scripts
- Connaître les commandes Kubernetes
- Personnaliser des configurations avancées
- Diagnostiquer des problèmes

## 📚 Documentation complémentaire

### Guides pratiques (à la racine)
- **[README.md](../README.md)** - Documentation principale
- **[QUICKSTART.md](../QUICKSTART.md)** - Installation rapide
- **[MENU-GUIDE.md](../MENU-GUIDE.md)** - Guide du menu interactif
- **[CONFIGURATION-GUIDE.md](../CONFIGURATION-GUIDE.md)** - Personnaliser config.sh
- **[DEBIAN-COMPATIBILITY.md](../DEBIAN-COMPATIBILITY.md)** - Spécificités Debian
- **[PROJECT-STRUCTURE.md](../PROJECT-STRUCTURE.md)** - Structure du projet

### Guides de référence (ce dossier)
- **Installation Kubernetes 1.32.txt** - Guide complet manuel
- **Configuration HA avec keepalived.txt** - Guide keepalived détaillé

## 🔍 Comment choisir ?

```
Vous voulez...
│
├─ 🚀 Installer rapidement
│   └─ Utilisez: ./scripts/k8s-menu.sh
│
├─ 📖 Apprendre en détail
│   └─ Lisez: docs/Installation Kubernetes 1.32.txt
│
├─ ⚙️ Personnaliser la config
│   └─ Modifiez: scripts/config.sh
│   └─ Guide: CONFIGURATION-GUIDE.md
│
├─ 🐛 Résoudre un problème
│   └─ Menu: [5] Vérifications et diagnostics
│   └─ ou lisez les guides .txt pour comprendre
│
└─ 🎯 Installer en production
    └─ 1. Lisez les guides .txt (comprendre)
    └─ 2. Testez avec le menu (valider)
    └─ 3. Personnalisez config.sh
    └─ 4. Lancez les scripts
```

## ✨ Conclusion

Ces guides `.txt` restent **utiles** comme :
- 📖 Documentation de référence
- 🎓 Matériel d'apprentissage
- 🔍 Guide de dépannage
- 📝 Spécifications détaillées

Mais pour une installation moderne, préférez le **menu interactif** et les **scripts automatisés** !

---

💡 **Conseil** : Lisez les guides `.txt` pour comprendre, puis utilisez les scripts pour installer !
