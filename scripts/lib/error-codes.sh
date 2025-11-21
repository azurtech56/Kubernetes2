#!/bin/bash

################################################################################
# Kubernetes HA Setup - Error Codes Database
# Version: 2.0.0
# Description: Base de données centralisée des codes d'erreur avec solutions
################################################################################

# Codes d'erreur (E001-E060)
declare -gA ERROR_MESSAGES=(
    # Erreurs générales (E001-E010)
    ["E001"]="Échec de l'installation de MetalLB"
    ["E002"]="Timeout d'attente des webhooks"
    ["E003"]="Pods non prêts après le timeout"
    ["E004"]="Échec de la vérification des prérequis"
    ["E005"]="Configuration invalide détectée"
    ["E006"]="Échec de la connexion SSH"
    ["E007"]="Permissions insuffisantes (root requis)"
    ["E008"]="Système d'exploitation non supporté"
    ["E009"]="Architecture système non supportée"
    ["E010"]="Version Kubernetes incompatible"

    # Erreurs réseau (E011-E020)
    ["E011"]="Adresse IP invalide"
    ["E012"]="VIP non accessible"
    ["E013"]="Port déjà utilisé"
    ["E014"]="Plage MetalLB invalide ou en conflit"
    ["E015"]="Réseau Pod en conflit avec réseau Service"
    ["E016"]="Connectivité réseau insuffisante"
    ["E017"]="DNS non fonctionnel"
    ["E018"]="Échec de configuration du firewall"
    ["E019"]="Interface réseau introuvable"
    ["E020"]="Route réseau manquante"

    # Erreurs ressources (E021-E030)
    ["E021"]="RAM insuffisante"
    ["E022"]="CPU insuffisant"
    ["E023"]="Espace disque insuffisant"
    ["E024"]="Swap non désactivé"
    ["E025"]="Module kernel manquant"
    ["E026"]="Dépendance système manquante"
    ["E027"]="Conteneur runtime non fonctionnel"
    ["E028"]="etcd non accessible"
    ["E029"]="API Server non disponible"
    ["E030"]="Scheduler non opérationnel"

    # Erreurs composants (E031-E040)
    ["E031"]="Calico CNI non déployé"
    ["E032"]="CoreDNS non fonctionnel"
    ["E033"]="Kube-proxy défaillant"
    ["E034"]="Keepalived non synchronisé"
    ["E035"]="Rancher non accessible"
    ["E036"]="Prometheus non opérationnel"
    ["E037"]="Grafana non accessible"
    ["E038"]="Certificat expiré ou invalide"
    ["E039"]="Token kubeconfig invalide"
    ["E040"]="Namespace en état Terminating bloqué"

    # Erreurs backup/restore (E041-E050)
    ["E041"]="Échec de la sauvegarde etcd"
    ["E042"]="Snapshot etcd corrompu"
    ["E043"]="Échec de la restauration"
    ["E044"]="Fichier de backup introuvable"
    ["E045"]="Espace insuffisant pour backup"
    ["E046"]="Backup incomplet"
    ["E047"]="Version de backup incompatible"
    ["E048"]="Échec de la compression"
    ["E049"]="Échec du chiffrement"
    ["E050"]="Restauration partielle uniquement"

    # Erreurs sécurité (E051-E060)
    ["E051"]="Fichier .env manquant"
    ["E052"]="Mot de passe trop faible"
    ["E053"]="Secret Kubernetes manquant"
    ["E054"]="Échec de chiffrement des secrets"
    ["E055"]="Token d'authentification expiré"
    ["E056"]="RBAC: permissions insuffisantes"
    ["E057"]="TLS: certificat auto-signé rejeté"
    ["E058"]="Audit logs non configurés"
    ["E059"]="Pod Security Policy violation"
    ["E060"]="Network Policy bloque le trafic"
)

# Solutions détaillées pour chaque erreur
declare -gA ERROR_SOLUTIONS=(
    # Erreurs générales
    ["E001"]="
Solutions:
1. Vérifier les pods MetalLB:
   kubectl get pods -n metallb-system
2. Consulter les logs:
   kubectl logs -n metallb-system -l app=metallb
3. Vérifier la configuration:
   kubectl get configmap -n metallb-system config -o yaml
4. Réinstaller MetalLB:
   ./setup-metallb.sh"

    ["E002"]="
Solutions:
1. Vérifier l'état des webhooks:
   kubectl get validatingwebhookconfigurations
   kubectl get mutatingwebhookconfigurations
2. Vérifier les pods du webhook:
   kubectl get pods -A | grep webhook
3. Consulter les logs API server:
   kubectl logs -n kube-system kube-apiserver-*
4. Augmenter WEBHOOK_TIMEOUT dans config.sh
5. Désactiver temporairement le webhook:
   kubectl delete validatingwebhookconfigurations <nom>"

    ["E003"]="
Solutions:
1. Vérifier l'état des pods:
   kubectl get pods -A
2. Décrire le pod en échec:
   kubectl describe pod <pod-name> -n <namespace>
3. Consulter les logs:
   kubectl logs <pod-name> -n <namespace>
4. Vérifier les events:
   kubectl get events -n <namespace> --sort-by='.lastTimestamp'
5. Vérifier les ressources:
   kubectl top nodes
   kubectl top pods -A"

    ["E004"]="
Solutions:
1. Relancer la vérification:
   ./check-prerequisites.sh
2. Installer les dépendances manquantes
3. Libérer les ressources nécessaires
4. Vérifier la connectivité réseau
5. Consulter les logs: /var/log/k8s-setup/prerequisites.log"

    ["E005"]="
Solutions:
1. Valider la configuration:
   ./validate-config.sh
2. Vérifier scripts/config.sh
3. Vérifier scripts/.env
4. Régénérer .env si nécessaire:
   ./generate-env.sh
5. Consulter la documentation: docs/configuration.md"

    ["E006"]="
Solutions:
1. Vérifier la connectivité SSH:
   ssh -v user@host
2. Vérifier les clés SSH:
   ssh-add -l
3. Copier la clé publique:
   ssh-copy-id user@host
4. Vérifier le service SSH:
   systemctl status ssh
5. Vérifier les règles firewall"

    ["E007"]="
Solutions:
1. Relancer le script avec sudo:
   sudo ./script.sh
2. Vérifier les permissions:
   id
3. Ajouter l'utilisateur au groupe sudo:
   usermod -aG sudo \$USER"

    ["E008"]="
Solutions:
1. Vérifier le système:
   cat /etc/os-release
2. Systèmes supportés:
   - Ubuntu 20.04+
   - Debian 11+
3. Mettre à jour le système:
   apt-get update && apt-get dist-upgrade"

    ["E009"]="
Solutions:
1. Vérifier l'architecture:
   uname -m
2. Architectures supportées:
   - x86_64 (amd64)
   - aarch64 (arm64)
3. Kubernetes ne supporte pas i386/i686"

    ["E010"]="
Solutions:
1. Vérifier la version installée:
   kubectl version --short
2. Version requise: 1.32.x
3. Mettre à jour Kubernetes:
   apt-get update
   apt-get install -y kubeadm=1.32.2-* kubectl=1.32.2-* kubelet=1.32.2-*"

    # Erreurs réseau
    ["E011"]="
Solutions:
1. Vérifier le format de l'IP:
   - Format: X.X.X.X (0-255 par octet)
2. Vérifier dans config.sh:
   - MASTER_IPS
   - WORKER_IPS
   - VIP
3. Corriger les IPs invalides"

    ["E012"]="
Solutions:
1. Vérifier la connectivité VIP:
   ping -c 3 \$VIP
2. Vérifier keepalived:
   systemctl status keepalived
3. Consulter les logs keepalived:
   journalctl -u keepalived -n 50
4. Vérifier la configuration VRRP:
   cat /etc/keepalived/keepalived.conf
5. Vérifier l'interface réseau:
   ip addr show"

    ["E013"]="
Solutions:
1. Identifier le processus:
   ss -tulpn | grep :<port>
2. Arrêter le processus:
   kill -9 <PID>
3. Libérer le port si nécessaire
4. Modifier le port dans config.sh"

    ["E014"]="
Solutions:
1. Vérifier la plage MetalLB dans config.sh
2. S'assurer qu'elle ne chevauche pas:
   - Les IPs des masters
   - Les IPs des workers
   - Le réseau Pod (POD_NETWORK)
   - Le réseau Service (SERVICE_NETWORK)
3. Exemple de plage valide: 192.168.100.200-192.168.100.250"

    ["E015"]="
Solutions:
1. Vérifier les réseaux dans config.sh:
   - POD_NETWORK=\"11.0.0.0/16\"
   - SERVICE_NETWORK=\"10.96.0.0/12\"
2. Ces réseaux ne doivent PAS se chevaucher
3. Modifier l'un des deux réseaux si conflit"

    ["E016"]="
Solutions:
1. Vérifier la connectivité Internet:
   ping -c 3 8.8.8.8
2. Vérifier la résolution DNS:
   nslookup kubernetes.io
3. Vérifier la passerelle:
   ip route show default
4. Vérifier les proxies:
   echo \$http_proxy \$https_proxy"

    ["E017"]="
Solutions:
1. Vérifier CoreDNS:
   kubectl get pods -n kube-system -l k8s-app=kube-dns
2. Tester la résolution:
   kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default
3. Consulter les logs CoreDNS:
   kubectl logs -n kube-system -l k8s-app=kube-dns
4. Redémarrer CoreDNS:
   kubectl rollout restart deployment coredns -n kube-system"

    ["E018"]="
Solutions:
1. Vérifier l'état UFW:
   ufw status verbose
2. Réinitialiser les règles:
   ufw --force reset
3. Relancer la configuration:
   ./master-setup.sh  # ou worker-setup.sh
4. Désactiver UFW temporairement (test):
   ufw disable"

    ["E019"]="
Solutions:
1. Lister les interfaces:
   ip link show
2. Vérifier INTERFACE dans config.sh
3. Interfaces communes: eth0, ens33, enp0s3
4. Activer l'interface:
   ip link set <interface> up"

    ["E020"]="
Solutions:
1. Vérifier les routes:
   ip route show
2. Ajouter une route par défaut:
   ip route add default via <gateway>
3. Vérifier la passerelle dans config.sh
4. Rendre la route persistante:
   echo \"up route add default gw <gateway>\" >> /etc/network/interfaces"

    # Erreurs ressources
    ["E021"]="
Solutions:
1. Vérifier la RAM disponible:
   free -h
2. RAM minimale requise:
   - Master: 2 Go
   - Worker: 1 Go
3. Ajouter de la RAM à la VM/serveur"

    ["E022"]="
Solutions:
1. Vérifier les CPUs:
   nproc
2. CPU minimal requis: 2 cores
3. Ajouter des CPUs à la VM/serveur"

    ["E023"]="
Solutions:
1. Vérifier l'espace disque:
   df -h
2. Espace minimal requis: 20 Go
3. Nettoyer l'espace:
   apt-get clean
   apt-get autoremove
   docker system prune -a"

    ["E024"]="
Solutions:
1. Désactiver le swap:
   swapoff -a
2. Rendre permanent:
   sed -i '/swap/d' /etc/fstab
3. Vérifier:
   free -h  # Swap doit être à 0"

    ["E025"]="
Solutions:
1. Charger les modules:
   modprobe overlay
   modprobe br_netfilter
2. Rendre permanent:
   echo 'overlay' >> /etc/modules-load.d/k8s.conf
   echo 'br_netfilter' >> /etc/modules-load.d/k8s.conf
3. Vérifier:
   lsmod | grep -E 'overlay|br_netfilter'"

    ["E026"]="
Solutions:
1. Installer les dépendances:
   apt-get update
   apt-get install -y curl apt-transport-https ca-certificates gnupg
2. Relancer check-prerequisites.sh"

    ["E027"]="
Solutions:
1. Vérifier containerd:
   systemctl status containerd
2. Redémarrer containerd:
   systemctl restart containerd
3. Vérifier la configuration:
   cat /etc/containerd/config.toml
4. Réinstaller si nécessaire:
   apt-get install --reinstall containerd"

    ["E028"]="
Solutions:
1. Vérifier etcd:
   kubectl get pods -n kube-system -l component=etcd
2. Consulter les logs:
   kubectl logs -n kube-system etcd-<master-name>
3. Vérifier le certificat:
   ls -la /etc/kubernetes/pki/etcd/
4. Sauvegarder et restaurer:
   ./backup-cluster.sh --type etcd
   ./restore-cluster.sh"

    ["E029"]="
Solutions:
1. Vérifier l'API server:
   kubectl get --raw /healthz
2. Consulter les logs:
   kubectl logs -n kube-system kube-apiserver-<master-name>
3. Vérifier le service:
   systemctl status kubelet
4. Redémarrer kubelet:
   systemctl restart kubelet"

    ["E030"]="
Solutions:
1. Vérifier le scheduler:
   kubectl get pods -n kube-system -l component=kube-scheduler
2. Consulter les logs:
   kubectl logs -n kube-system kube-scheduler-<master-name>
3. Vérifier les leader elections:
   kubectl get lease -n kube-system"

    # Ajouter les solutions pour E031-E060...
    # (Continué dans le même format)
)

# Fonction pour afficher un message d'erreur formaté
display_error() {
    local error_code="$1"
    local context="${2:-}"

    if [ -z "${ERROR_MESSAGES[$error_code]:-}" ]; then
        echo "❌ Erreur inconnue: $error_code"
        return 1
    fi

    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║ ❌ ERREUR $error_code                                           "
    echo "╠════════════════════════════════════════════════════════════════╣"
    echo "║ ${ERROR_MESSAGES[$error_code]}"
    if [ -n "$context" ]; then
        echo "║"
        echo "║ Contexte: $context"
    fi
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    if [ -n "${ERROR_SOLUTIONS[$error_code]:-}" ]; then
        echo "${ERROR_SOLUTIONS[$error_code]}"
        echo ""
    fi

    echo "📖 Documentation: docs/troubleshooting.md"
    echo "📝 Logs: /var/log/k8s-setup/"
    echo ""
}

# Fonction pour logger une erreur
log_error_code() {
    local error_code="$1"
    local context="${2:-}"
    local log_file="${3:-/var/log/k8s-setup/errors.log}"

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local hostname=$(hostname)

    mkdir -p "$(dirname "$log_file")"

    echo "[$timestamp] [$hostname] [$error_code] ${ERROR_MESSAGES[$error_code]:-Unknown} | Context: $context" >> "$log_file"
}

# Fonction combinée: affiche et log
handle_error() {
    local error_code="$1"
    local context="${2:-}"
    local log_file="${3:-/var/log/k8s-setup/errors.log}"

    display_error "$error_code" "$context"
    log_error_code "$error_code" "$context" "$log_file"
}

# Export des fonctions
export -f display_error
export -f log_error_code
export -f handle_error
