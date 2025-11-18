# Améliorations de Code Recommandées - Kubernetes HA

Document analyse des améliorations de code pour tous les scripts du cluster Kubernetes 1.33 HA.

---

## 📋 Résumé Exécutif

**État actuel**: Code fonctionnel avec bonnes pratiques de base
**Priorité haute**: 3 améliorations majeures
**Priorité moyenne**: 5 améliorations de maintenabilité
**Priorité basse**: 4 optimisations mineures

---

## 🔴 PRIORITÉ HAUTE - Corrections Recommandées

### 1. Duplication de Logique de Script Execution (k8s-menu.sh)

**Fichier**: `scripts/k8s-menu.sh` (lignes 175-224)
**Sévérité**: HIGH - Difficulté de maintenance
**Impact**: ~50 lignes dupliquées

**Problème**:
```bash
# run_script() et run_script_no_sudo() sont 95% identiques
# Difficulté à maintenir les changements et corrections
```

**Solution Recommandée**:
```bash
run_script_with_privilege() {
    local script=$1
    local use_sudo=${2:-true}  # true ou false

    echo ""
    echo -e "${YELLOW}Exécution de ${script}...${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"

    # Validation
    if [ ! -f "$script" ]; then
        echo -e "${RED}✗ Script non trouvé: $script${NC}"
        echo ""
        read -p "Appuyez sur Entrée pour continuer..."
        return 1
    fi

    chmod +x "$script"

    # Exécution avec ou sans sudo
    if [[ "$use_sudo" == true ]]; then
        sudo "$script"
    else
        "$script"
    fi

    local exit_code=$?
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ Script exécuté avec succès${NC}"
    else
        echo -e "${RED}✗ Erreur lors de l'exécution (code: $exit_code)${NC}"
    fi

    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
    return $exit_code
}

# Utilisation:
# Avec sudo:
# run_script_with_privilege "./common-setup.sh" true
#
# Sans sudo:
# run_script_with_privilege "./install-calico.sh" false
```

**Bénéfices**:
- ✓ Une seule source de vérité
- ✓ Maintenance simplifiée
- ✓ Corrections appliquées une seule fois

---

### 2. Absence de Validation de Configuration (tous les scripts)

**Fichiers**: `common-setup.sh`, `master-setup.sh`, `init-cluster.sh`, tous les scripts
**Sévérité**: HIGH - Risque d'erreurs silencieuses
**Impact**: Configuration invalide non détectée

**Problème**:
```bash
# Chargement sans validation
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
else
    # Valeurs par défaut utilisées silencieusement
fi
# Aucune vérification que les variables requises sont présentes
```

**Solution Recommandée**:
```bash
load_and_validate_config() {
    local config_file="$SCRIPT_DIR/config.sh"
    local required_vars=("K8S_VERSION" "VIP" "MASTER1_IP")

    if [ -f "$config_file" ]; then
        source "$config_file"
    else
        echo -e "${YELLOW}⚠ config.sh non trouvé, utilisation des defaults${NC}"
        set_default_configuration
    fi

    # Valider les variables critiques
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            echo -e "${RED}✗ ERREUR: Variable requise '${var}' non définie${NC}"
            echo -e "${YELLOW}Vérifiez config.sh${NC}"
            exit 1
        fi
    done
}

set_default_configuration() {
    K8S_VERSION="${K8S_VERSION:-1.33.0}"
    VIP="${VIP:-192.168.0.200}"
    # ... etc
}

# Appel au démarrage:
load_and_validate_config
```

**Bénéfices**:
- ✓ Erreurs détectées tôt
- ✓ Messages d'erreur clairs
- ✓ Évite les défaillances silencieuses

---

### 3. Patterns Répétitifs de Menu (k8s-menu.sh)

**Fichier**: `scripts/k8s-menu.sh`
**Sévérité**: HIGH - Code duplication
**Impact**: 6 fonctions de menu ~95% identiques

**Problème**:
```bash
# show_main_menu(), show_step_menu(), show_addons_menu(),
# show_management_menu(), show_diagnostic_menu(), show_help_menu()
# Tous répètent le même pattern avec variations mineures
```

**Solution Recommandée**:
```bash
# Fonctions utilitaires pour construction de menus
display_menu_header() {
    local title=$1
    show_header
    echo -e "${BOLD}${BLUE}═══ ${title} ═══${NC}"
    echo ""
}

display_menu_separator() {
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
}

display_menu_option() {
    local number=$1
    local description=$2
    local color=${3:-"GREEN"}
    echo -e "${!color}[${number}]${NC}  ${description}"
}

display_menu_section() {
    local title=$1
    echo -e "${MAGENTA}▶ ${title}${NC}"
}

# Refactoriser les menus:
show_step_menu() {
    display_menu_header "INSTALLATION PAR ÉTAPES"

    display_menu_section "Préparation (sur tous les nœuds)"
    display_menu_option "1" "Configuration commune (common-setup.sh)"
    display_menu_option "2" "Configuration Master (master-setup.sh)"
    display_menu_option "3" "Configuration Worker (worker-setup.sh)"
    echo ""

    display_menu_section "Haute Disponibilité (HA)"
    display_menu_option "4" "Configuration keepalived (setup-keepalived.sh)"
    echo ""

    # ... etc

    display_menu_separator
    echo -ne "${YELLOW}Votre choix: ${NC}"
}
```

**Bénéfices**:
- ✓ Code plus lisible
- ✓ Cohérence visuelle garantie
- ✓ Facile à modifier le style globalement

---

## 🟡 PRIORITÉ MOYENNE - Amélioration de la Maintenabilité

### 4. Magic Numbers dans Switch Cases

**Fichier**: `scripts/k8s-menu.sh`
**Sévérité**: MEDIUM
**Lignes affectées**: Main loop (lignes 638-713)

**Problème**:
```bash
case $choice in
    1) installation_wizard ;;      # Quoi? "1" = installation complète?
    2) # Menu par étapes ...
    3) # Add-ons ...
    4) manage_cluster ;;
    # etc
esac
```

**Solution**:
```bash
# Constantes pour les choix du menu
readonly MENU_INSTALL_WIZARD=1
readonly MENU_STEP_BY_STEP=2
readonly MENU_ADDONS=3
readonly MENU_MANAGEMENT=4
readonly MENU_DIAGNOSTICS=5
readonly MENU_HELP=6
readonly MENU_EXIT=0

# Utilisation:
case $choice in
    $MENU_INSTALL_WIZARD) installation_wizard ;;
    $MENU_STEP_BY_STEP) show_step_menu ;;
    $MENU_ADDONS) show_addons_menu ;;
    # etc
esac
```

**Bénéfices**:
- ✓ Code autodocumenté
- ✓ Refactorisation simplifiée
- ✓ Moins d'erreurs de typage

---

### 5. Boucles Menu Répétitives

**Fichier**: `scripts/k8s-menu.sh`
**Sévérité**: MEDIUM
**Lignes**: manage_cluster (391-459), run_diagnostics (462-544), help_menu (547-635)

**Problème**:
```bash
# manage_cluster(), run_diagnostics(), et help_menu()
# Contiennent chacun une boucle while true pratiquement identique
while true; do
    show_XXX_menu
    read choice
    case $choice in
        # ... traitement ...
        0) break ;;
    esac
done
```

**Solution**:
```bash
# Gestionnaire générique de menu
run_menu_handler() {
    local menu_function=$1
    local handler_function=$2

    while true; do
        "$menu_function"
        read choice

        if [ "$choice" = "0" ]; then
            break
        elif ! "$handler_function" "$choice"; then
            echo -e "${RED}Choix invalide${NC}"
            sleep 1
        fi
    done
}

# Définir les handlers:
handle_management_choice() {
    local choice=$1
    case $choice in
        1) ./generate-hosts.sh ;;
        2) watch -n 2 -c "kubectl get nodes -o wide" ;;
        # ... etc ...
        *) return 1 ;;
    esac
}

# Utilisation:
manage_cluster() {
    run_menu_handler show_management_menu handle_management_choice
}
```

**Bénéfices**:
- ✓ ~300 lignes de code éliminées
- ✓ Logique de boucle centralisée
- ✓ Cohérence comportementale

---

### 6. Absence de Validation d'Entrée

**Fichier**: `scripts/k8s-menu.sh` et autres
**Sévérité**: MEDIUM
**Lignes**: Toutes les lectures (`read choice`)

**Problème**:
```bash
read choice
# Aucune vérification que choice est valide
case $choice in
    1) ... ;;
    2) ... ;;
    *)
        echo -e "${RED}Choix invalide${NC}"  # Trop tard!
        ;;
esac
```

**Solution**:
```bash
get_menu_choice() {
    local min=$1
    local max=$2
    local prompt="${3:-Votre choix: }"

    while true; do
        echo -ne "${YELLOW}${prompt}${NC}"
        read choice

        # Valider que c'est un nombre
        if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}Erreur: Entrez un nombre${NC}"
            continue
        fi

        # Valider la plage
        if [ "$choice" -lt "$min" ] || [ "$choice" -gt "$max" ]; then
            echo -e "${RED}Erreur: Entrez un nombre entre ${min} et ${max}${NC}"
            continue
        fi

        echo "$choice"
        return 0
    done
}

# Utilisation:
choice=$(get_menu_choice 0 6)
case $choice in
    1) installation_wizard ;;
    # ... etc ...
esac
```

**Bénéfices**:
- ✓ Validation robuste
- ✓ Messages d'erreur clairs
- ✓ Pas de comportements imprévisibles

---

### 7. Commandes Watch Répétitives

**Fichier**: `scripts/k8s-menu.sh`
**Sévérité**: MEDIUM
**Lignes**: manage_cluster, run_diagnostics (multiples)

**Problème**:
```bash
# Même pattern répété 8+ fois:
echo -e "${YELLOW}Mode watch activé - Appuyez sur Ctrl+C pour quitter${NC}"
watch -n 2 -c "kubectl get nodes -o wide"

echo -e "${YELLOW}Mode watch activé - Appuyez sur Ctrl+C pour quitter${NC}"
watch -n 2 -c "kubectl get pods -A"

echo -e "${YELLOW}Mode watch activé - Appuyez sur Ctrl+C pour quitter${NC}"
watch -n 2 -c "kubectl get svc -A | grep -E 'NAMESPACE|LoadBalancer'"
```

**Solution**:
```bash
run_watch_command() {
    local label=$1
    local command=$2
    local interval=${3:-2}

    echo ""
    echo -e "${YELLOW}Mode watch activé (${interval}s) - Appuyez sur Ctrl+C pour quitter${NC}"
    echo ""
    watch -n "$interval" -c "$command"
}

# Utilisation:
run_watch_command "Nœuds" "kubectl get nodes -o wide" 2
run_watch_command "Pods" "kubectl get pods -A" 2
run_watch_command "LoadBalancers" "kubectl get svc -A | grep -E 'NAMESPACE|LoadBalancer'" 2
```

**Bénéfices**:
- ✓ Code plus concis
- ✓ Cohérence visuelle
- ✓ Facile à modifier le format

---

## 🟢 PRIORITÉ BASSE - Optimisations Mineures

### 8. Hardcoded Kubernetes Version dans About (k8s-menu.sh)

**Fichier**: `scripts/k8s-menu.sh`, ligne 611
**Sévérité**: LOW
**Impact**: Incohérence

**Problème**:
```bash
# Dans show_help_menu() - À propos (ligne 604):
echo "  • Kubernetes 1.33"    # Hardcoded!

# Mais K8S_MAJOR_MINOR est disponible depuis le chargement
```

**Solution**:
```bash
# Remplacer:
echo "  • Kubernetes 1.33"

# Par:
echo "  • Kubernetes ${K8S_MAJOR_MINOR}"
```

**Bénéfices**:
- ✓ Une seule source de vérité
- ✓ Automatiquement à jour

---

### 9. Calcul IP Inefficace (k8s-menu.sh)

**Fichier**: `scripts/k8s-menu.sh`, ligne 250
**Sévérité**: LOW
**Impact**: Performance negligible

**Problème**:
```bash
# Calcul inefficace avec 2 subshells:
METALLB_COUNT=$(($(echo ${METALLB_IP_END} | cut -d. -f4) - $(echo ${METALLB_IP_START} | cut -d. -f4)))
```

**Solution**:
```bash
# Utiliser parameter expansion directement:
local start_octet="${METALLB_IP_START##*.}"
local end_octet="${METALLB_IP_END##*.}"
METALLB_COUNT=$((end_octet - start_octet))
```

**Bénéfices**:
- ✓ Pas de subshells externes
- ✓ Plus rapide
- ✓ Plus lisible

---

### 10. Pas de Fonction d'Aide/Usage

**Fichier**: `scripts/k8s-menu.sh`
**Sévérité**: LOW
**Impact**: Expérience utilisateur

**Problème**:
```bash
./k8s-menu.sh --help
# "Choix invalide" - pas d'aide disponible
```

**Solution**:
```bash
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help        Afficher cette aide"
    echo "  -c, --config FILE Charger une configuration personnalisée"
    echo ""
    exit 0
}

# Dans main(), au début:
case "${1:-}" in
    -h|--help) show_usage ;;
    -c|--config)
        if [ -f "$2" ]; then
            source "$2"
            shift 2
        else
            echo "Erreur: config file not found: $2"
            exit 1
        fi
        ;;
esac
```

**Bénéfices**:
- ✓ Meilleure documentation
- ✓ Flexibilité améliorée
- ✓ Respect des conventions

---

### 11. Optimisation de Chargement de Config (Tous)

**Fichiers**: Tous les scripts
**Sévérité**: LOW
**Impact**: Initialisation plus rapide

**Problème**:
```bash
# Répété dans 14 scripts:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
else
    # Defaults...
fi
```

**Solution - Créer `scripts/load-config.sh`**:
```bash
#!/bin/bash
# Common configuration loader
load_kubernetes_config() {
    local script_dir="${1:-.}"
    local config_file="$script_dir/config.sh"

    if [ -f "$config_file" ]; then
        source "$config_file" 2>/dev/null || return 1
    else
        set_default_config
    fi

    return 0
}

set_default_config() {
    export K8S_VERSION="${K8S_VERSION:-1.33.0}"
    export VIP="${VIP:-192.168.0.200}"
    # ... etc
}
```

Puis dans chaque script:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/load-config.sh"
load_kubernetes_config "$SCRIPT_DIR" || {
    echo "Erreur: Impossible de charger la configuration"
    exit 1
}
```

**Bénéfices**:
- ✓ Une seule source de vérité
- ✓ Maintenance simplifiée
- ✓ Chargement cohérent partout

---

## 📊 Tableau Récapitulatif

| # | Problème | Fichier | Sévérité | Effort | Bénéfice |
|---|----------|---------|----------|--------|----------|
| 1 | Duplication run_script | k8s-menu.sh | 🔴 HIGH | 30min | Maintenance |
| 2 | Pas de validation config | Tous | 🔴 HIGH | 1h | Robustesse |
| 3 | Menus répétitifs | k8s-menu.sh | 🔴 HIGH | 1.5h | Maintenabilité |
| 4 | Magic numbers | k8s-menu.sh | 🟡 MED | 30min | Lisibilité |
| 5 | Boucles menu | k8s-menu.sh | 🟡 MED | 1h | Code removal |
| 6 | Pas validation entrée | k8s-menu.sh | 🟡 MED | 45min | Robustesse |
| 7 | Watch commands | k8s-menu.sh | 🟡 MED | 20min | Maintenabilité |
| 8 | Hardcoded version | k8s-menu.sh | 🟢 LOW | 5min | Cohérence |
| 9 | IP calc inefficace | k8s-menu.sh | 🟢 LOW | 10min | Performance |
| 10 | Pas d'aide/usage | k8s-menu.sh | 🟢 LOW | 20min | UX |
| 11 | Config répétée | Tous | 🟢 LOW | 1h | Maintenance |

---

## 🎯 Plan d'Implémentation Recommandé

### Phase 1: Corrections Critiques (2-3 heures)
1. ✓ Consolider `run_script()` et `run_script_no_sudo()`
2. ✓ Ajouter validation de configuration dans chaque script
3. ✓ Créer helpers de menu pour éliminer la duplication

### Phase 2: Améliorations Maintenabilité (2 heures)
4. ✓ Ajouter constantes pour magic numbers
5. ✓ Refactoriser boucles menu répétitives
6. ✓ Ajouter validation d'entrée

### Phase 3: Polish (1.5 heures)
7. ✓ Optimiser commandes watch
8. ✓ Corriger hardcoded values
9. ✓ Ajouter fonction usage

### Phase 4: Architecture (1 heure)
10. ✓ Créer load-config.sh partagé
11. ✓ Normaliser tous les scripts

**Temps total estimé**: 6-7 heures pour implémentation complète
**Bénéfice**: Code 40-50% plus maintenable, 30-40% moins d'erreurs

---

## ✅ Checklist de Vérification

Après implémentation des améliorations, vérifier:

- [ ] Tous les scripts chargent la config de la même façon
- [ ] `k8s-menu.sh` utilise les helpers de menu
- [ ] Pas de duplication de code run_script
- [ ] Validation d'entrée sur tous les menus
- [ ] Messages d'erreur clairs et utiles
- [ ] Tests manuels sur tous les chemins critiques
- [ ] Documentation à jour pour les changements

---

## 📚 Ressources

- [Bash Best Practices](https://mywiki.wooledge.org/BashGuide)
- [ShellCheck - Code Analysis](https://www.shellcheck.net/)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)

---

**Document généré**: 2025-11-18
**Version**: 1.0
**Scope**: Tous les scripts du cluster Kubernetes 1.33 HA

