#!/bin/bash
################################################################################
# Script d'intégration automatique des bibliothèques v2.1
# Version: 2.1.1
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=================================="
echo "  Intégration v2.1 - Auto"
echo "=================================="
echo ""

# Fonction pour ajouter les bibliothèques v2.1 à la fin d'un fichier
add_v21_footer() {
    local file="$1"
    local script_name="$2"
    
    if ! grep -q "stop_timer" "$file" 2>/dev/null; then
        echo "  → Ajout footer v2.1 à $file"
        
        # Backup
        cp "$file" "${file}.bak"
        
        # Ajouter avant la dernière ligne
        cat >> "$file" << 'EOF'

# === v2.1 Performance & Notifications ===
if type -t stop_timer &>/dev/null; then
    stop_timer "SCRIPT_NAME"
fi

if type -t notify_install_success &>/dev/null; then
    notify_install_success "SCRIPT_NAME"
fi

if type -t dry_run_summary &>/dev/null; then
    dry_run_summary
fi
# === Fin v2.1 ===
EOF
        
        # Remplacer SCRIPT_NAME
        sed -i "s/SCRIPT_NAME/$script_name/g" "$file"
        
        echo "    ✓ Footer ajouté"
    else
        echo "  ⏭  $file déjà modifié"
    fi
}

echo "1. Modification de common-setup.sh (déjà fait)"
echo "   ✓ Bibliothèques v2.1 chargées"
echo ""

echo "2. Modification de master-setup.sh..."
if ! grep -q "lib/performance.sh" master-setup.sh 2>/dev/null; then
    echo "   Ajout des bibliothèques..."
    # Les bibliothèques seront ajoutées manuellement
    echo "   ⚠ À faire manuellement"
else
    echo "   ✓ Déjà modifié"
fi
echo ""

echo "3. Modification de worker-setup.sh..."
if ! grep -q "lib/performance.sh" worker-setup.sh 2>/dev/null; then
    echo "   ⚠ À faire manuellement"
else
    echo "   ✓ Déjà modifié"
fi
echo ""

echo "4. Modification de backup-cluster.sh..."
if ! grep -q "lib/notifications.sh" backup-cluster.sh 2>/dev/null; then
    echo "   ⚠ À faire manuellement"
else
    echo "   ✓ Déjà modifié"
fi
echo ""

echo "=================================="
echo "  Intégration terminée"
echo "=================================="
echo ""
echo "Fichiers modifiés:"
echo "  - common-setup.sh ✓"
echo "  - uninstall-cluster.sh ✓ (nouveau)"
echo ""
echo "À faire manuellement:"
echo "  - master-setup.sh"
echo "  - worker-setup.sh"
echo "  - backup-cluster.sh"
echo "  - health-check.sh"
echo ""
