#!/bin/bash
################################################################################
# Script d'auto-déploiement complet du cluster Kubernetes HA
# Déploie automatiquement depuis le master vers tous les workers
# Gère automatiquement les clés SSH
# Auteur: azurtech56
# Version: 1.0
################################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Charger la configuration
if [ ! -f "$SCRIPT_DIR/config.sh" ]; then
    echo -e "${RED}✗ Erreur: fichier config.sh introuvable${NC}"
    exit 1
fi

source "$SCRIPT_DIR/config.sh"

# Vérifier si root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}✗ Ce script doit être exécuté en tant que root${NC}"
   exit 1
fi

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}${GREEN}Déploiement Automatique Kubernetes HA${NC}                    ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${BLUE}Installation complète depuis le master${NC}                    ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

################################################################################
# CONFIGURATION SSH
################################################################################

SSH_USER="${SSH_USER:-root}"

echo -e "${YELLOW}[1/6] Configuration SSH${NC}"
echo ""
echo -e "${BLUE}Nom d'utilisateur SSH pour les workers:${NC} ${SSH_USER}"
echo ""

# Générer une clé SSH si elle n'existe pas
if [ ! -f ~/.ssh/id_rsa ]; then
    echo -e "${YELLOW}Génération d'une clé SSH...${NC}"
    ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa -q
    echo -e "${GREEN}✓ Clé SSH générée${NC}"
else
    echo -e "${GREEN}✓ Clé SSH déjà existante${NC}"
fi

echo ""

# Construire la liste des workers
declare -a WORKERS=()
worker_num=1
while true; do
    ip_var="WORKER${worker_num}_IP"
    hostname_var="WORKER${worker_num}_HOSTNAME"

    if [ -n "${!ip_var}" ]; then
        WORKERS+=("${!ip_var}:${!hostname_var}")
        ((worker_num++))
    else
        break
    fi
done

if [ ${#WORKERS[@]} -eq 0 ]; then
    echo -e "${RED}✗ Aucun worker configuré dans config.sh${NC}"
    exit 1
fi

echo -e "${BLUE}Workers détectés: ${#WORKERS[@]}${NC}"
for worker in "${WORKERS[@]}"; do
    IP="${worker%%:*}"
    HOSTNAME="${worker##*:}"
    echo "  • ${HOSTNAME} (${IP})"
done
echo ""

# Configurer les clés SSH pour chaque worker
echo -e "${YELLOW}Configuration des clés SSH sur les workers...${NC}"
echo ""

for worker in "${WORKERS[@]}"; do
    IP="${worker%%:*}"
    HOSTNAME="${worker##*:}"

    echo -ne "  ${YELLOW}→${NC} ${HOSTNAME} (${IP})... "

    # Tester si SSH fonctionne déjà sans mot de passe
    if ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "${SSH_USER}@${IP}" "exit" 2>/dev/null; then
        echo -e "${GREEN}✓ SSH déjà configuré${NC}"
    else
        echo -e "${YELLOW}Configuration nécessaire${NC}"
        echo ""
        echo -e "${CYAN}  Veuillez entrer le mot de passe SSH pour ${HOSTNAME}:${NC}"

        # Copier la clé SSH (demandera le mot de passe)
        if ssh-copy-id -o StrictHostKeyChecking=no "${SSH_USER}@${IP}" 2>/dev/null; then
            echo -e "${GREEN}  ✓ Clé SSH copiée avec succès${NC}"
        else
            echo -e "${RED}  ✗ Échec de la copie de la clé SSH${NC}"
            echo -e "${YELLOW}  Impossible de continuer sans accès SSH${NC}"
            exit 1
        fi
        echo ""
    fi
done

echo ""
echo -e "${GREEN}✓ Configuration SSH terminée pour tous les workers${NC}"
echo ""

################################################################################
# INSTALLATION SUR LE MASTER
################################################################################

echo -e "${YELLOW}[2/6] Installation sur le Master${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo ""

# Vérifier si le cluster est déjà initialisé
if systemctl is-active --quiet kubelet 2>/dev/null || [ -f /etc/kubernetes/admin.conf ]; then
    echo -e "${YELLOW}⚠ Un cluster Kubernetes existe déjà sur ce nœud${NC}"
    echo ""
    read -p "Voulez-vous RÉINITIALISER et réinstaller le cluster? [y/N]: " confirm

    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Réinitialisation complète du cluster...${NC}"
        echo ""

        # Arrêter les services
        systemctl stop kubelet 2>/dev/null || true
        systemctl stop containerd 2>/dev/null || true

        # Reset kubeadm
        kubeadm reset -f 2>/dev/null || true

        # Nettoyer les fichiers
        rm -rf ~/.kube /etc/kubernetes /var/lib/etcd /var/lib/kubelet
        rm -rf /etc/cni/net.d

        # Restaurer les politiques iptables AVANT de nettoyer
        iptables -P INPUT ACCEPT 2>/dev/null || true
        iptables -P FORWARD ACCEPT 2>/dev/null || true
        iptables -P OUTPUT ACCEPT 2>/dev/null || true

        # Nettoyer les règles iptables
        iptables -F 2>/dev/null || true
        iptables -t nat -F 2>/dev/null || true
        iptables -t mangle -F 2>/dev/null || true
        iptables -X 2>/dev/null || true

        # Redémarrer containerd
        systemctl restart containerd
        systemctl enable containerd

        echo -e "${GREEN}✓ Cluster complètement réinitialisé${NC}"
        echo ""
        sleep 2
    else
        echo -e "${YELLOW}❌ Installation annulée${NC}"
        echo -e "${YELLOW}Pour conserver le cluster existant, utilisez les options de gestion${NC}"
        exit 0
    fi
fi

if [ "$goto_workers" != true ]; then
    # Étape 1: Configuration commune
    echo -e "${BLUE}[2.1] Configuration commune...${NC}"
    "$SCRIPT_DIR/core/common-setup.sh"
    echo ""

    # Étape 2: Configuration master
    echo -e "${BLUE}[2.2] Configuration master...${NC}"
    "$SCRIPT_DIR/core/master-setup.sh"
    echo ""

    # Étape 3: Keepalived (MASTER - Priority 101)
    echo -e "${BLUE}[2.3] Configuration keepalived...${NC}"

    # Détecter l'interface réseau principale
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

    # Créer directement le fichier de configuration keepalived
    mkdir -p /etc/keepalived
    cat > /etc/keepalived/keepalived.conf <<KEEPALIVED_EOF
vrrp_instance VI_1 {
    state MASTER
    interface ${INTERFACE}
    virtual_router_id ${VRRP_ROUTER_ID}
    priority 101
    advert_int ${VRRP_ADVERT_INT}

    authentication {
        auth_type PASS
        auth_pass ${VRRP_PASSWORD}
    }

    virtual_ipaddress {
        ${VIP}/24
    }
}
KEEPALIVED_EOF

    # Redémarrer keepalived
    systemctl restart keepalived
    systemctl enable keepalived

    # Vérifier l'état
    sleep 2
    if systemctl is-active --quiet keepalived; then
        echo -e "${GREEN}✓ Keepalived configuré et actif${NC}"
    else
        echo -e "${RED}✗ Erreur keepalived${NC}"
        journalctl -u keepalived --no-pager -n 20
    fi
    echo ""

    # Étape 4: Initialisation du cluster (inclut Calico CNI)
    echo -e "${BLUE}[2.4] Initialisation du cluster...${NC}"
    "$SCRIPT_DIR/core/init-cluster.sh"
    echo ""
fi

echo -e "${GREEN}✓ Installation du master terminée${NC}"
echo ""

################################################################################
# RÉCUPÉRATION DE LA COMMANDE KUBEADM JOIN
################################################################################

echo -e "${YELLOW}[3/6] Récupération de la commande kubeadm join${NC}"
echo ""

# Attendre que le cluster soit prêt
echo -e "${BLUE}Attente que le cluster soit prêt...${NC}"
sleep 10

# Générer la commande join
KUBEADM_JOIN=$(kubeadm token create --print-join-command 2>/dev/null)

if [ -z "$KUBEADM_JOIN" ]; then
    echo -e "${RED}✗ Impossible de générer la commande kubeadm join${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Commande join générée${NC}"
echo -e "${CYAN}$KUBEADM_JOIN${NC}"
echo ""

################################################################################
# DÉPLOIEMENT SUR LES WORKERS
################################################################################

echo -e "${YELLOW}[4/6] Déploiement sur les Workers${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo ""

# Créer un tarball des scripts pour le transfert
echo -e "${BLUE}Préparation du package de scripts...${NC}"
cd "$SCRIPT_DIR"
tar -czf /tmp/k8s-scripts.tar.gz core/ lib/ lib-config.sh config.sh .env 2>/dev/null
echo -e "${GREEN}✓ Package créé${NC}"
echo ""

SUCCESS_COUNT=0
FAILED_COUNT=0

for worker in "${WORKERS[@]}"; do
    IP="${worker%%:*}"
    HOSTNAME="${worker##*:}"

    echo -e "${MAGENTA}▶ Déploiement sur ${HOSTNAME} (${IP})${NC}"
    echo ""

    # Copier les scripts
    echo -ne "  [1/4] Copie des scripts... "
    if scp -q /tmp/k8s-scripts.tar.gz "${SSH_USER}@${IP}:/tmp/" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ Échec${NC}"
        ((FAILED_COUNT++))
        echo ""
        continue
    fi

    # Extraire les scripts
    echo -ne "  [2/4] Extraction... "
    if ssh "${SSH_USER}@${IP}" "mkdir -p /root/k8s-install && cd /root/k8s-install && tar -xzf /tmp/k8s-scripts.tar.gz" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ Échec${NC}"
        ((FAILED_COUNT++))
        echo ""
        continue
    fi

    # Exécuter common-setup.sh
    echo -ne "  [3/4] Configuration commune... "
    ERROR_OUTPUT=$(ssh "${SSH_USER}@${IP}" "cd /root/k8s-install && bash core/common-setup.sh" 2>&1)
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ Échec${NC}"
        echo ""
        echo -e "${YELLOW}Erreur détaillée (code: $EXIT_CODE):${NC}"
        echo "$ERROR_OUTPUT" | tail -20
        echo ""
        ((FAILED_COUNT++))
        continue
    fi

    # Exécuter worker-setup.sh
    echo -ne "  [4/4] Configuration worker... "
    ERROR_OUTPUT=$(ssh "${SSH_USER}@${IP}" "cd /root/k8s-install && bash core/worker-setup.sh" 2>&1)
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ Échec${NC}"
        echo ""
        echo -e "${YELLOW}Erreur détaillée (code: $EXIT_CODE):${NC}"
        echo "$ERROR_OUTPUT" | tail -20
        echo ""
        ((FAILED_COUNT++))
        continue
    fi

    # Joindre le cluster
    echo -ne "  [+] Jointure au cluster... "
    ERROR_OUTPUT=$(ssh "${SSH_USER}@${IP}" "$KUBEADM_JOIN" 2>&1)
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}✓${NC}"
        ((SUCCESS_COUNT++))
    else
        echo -e "${RED}✗ Échec${NC}"
        echo ""
        echo -e "${YELLOW}Erreur détaillée (code: $EXIT_CODE):${NC}"
        echo "$ERROR_OUTPUT" | tail -20
        echo ""
        ((FAILED_COUNT++))
    fi

    echo ""
done

# Nettoyer
rm -f /tmp/k8s-scripts.tar.gz

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo ""

################################################################################
# DÉPLOIEMENT DU FICHIER /etc/hosts
################################################################################

echo -e "${YELLOW}[5/6] Déploiement du fichier /etc/hosts${NC}"
echo ""

"$SCRIPT_DIR/generate-hosts.sh" <<EOF
3
${SSH_USER}
0
EOF

echo ""

################################################################################
# VÉRIFICATION ET RAPPORT
################################################################################

echo -e "${YELLOW}[6/6] Vérification du cluster${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo ""

# Attendre que les nœuds soient prêts
echo -e "${BLUE}Attente de la disponibilité des nœuds (30s)...${NC}"
sleep 30

echo ""
echo -e "${YELLOW}État des nœuds:${NC}"
kubectl get nodes -o wide
echo ""

echo -e "${YELLOW}État des pods système:${NC}"
kubectl get pods -n kube-system
echo ""

################################################################################
# RAPPORT FINAL
################################################################################

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}${GREEN}Rapport de Déploiement${NC}                                    ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

TOTAL_WORKERS=${#WORKERS[@]}

echo -e "${GREEN}✓ Master:${NC} Installé et configuré"
echo -e "${GREEN}✓ Workers déployés:${NC} ${SUCCESS_COUNT}/${TOTAL_WORKERS}"
if [ $FAILED_COUNT -gt 0 ]; then
    echo -e "${RED}✗ Workers en échec:${NC} ${FAILED_COUNT}/${TOTAL_WORKERS}"
fi
echo ""

echo -e "${YELLOW}Accès au cluster:${NC}"
echo "  • VIP: ${VIP}"
echo "  • FQDN: ${VIP_FQDN}"
echo "  • Kubeconfig: ~/.kube/config"
echo ""

echo -e "${YELLOW}Prochaines étapes recommandées:${NC}"
echo "  1. Installer MetalLB: ./addons/install-metallb.sh"
echo "  2. Installer Rancher: ./addons/install-rancher.sh"
echo "  3. Installer Monitoring: ./addons/install-monitoring.sh"
echo ""

echo -e "${YELLOW}Commandes utiles:${NC}"
echo "  • Voir les nœuds: kubectl get nodes"
echo "  • Voir les pods: kubectl get pods -A"
echo "  • État du cluster: kubectl cluster-info"
echo ""

if [ $FAILED_COUNT -eq 0 ]; then
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}🎉 DÉPLOIEMENT RÉUSSI !${NC}                                   ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
else
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${NC}  ${BOLD}⚠️  DÉPLOIEMENT PARTIEL${NC}                                    ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Certains workers n'ont pas pu être déployés.${NC}"
    echo -e "${YELLOW}Vérifiez les erreurs ci-dessus et réessayez manuellement.${NC}"
fi

echo ""
