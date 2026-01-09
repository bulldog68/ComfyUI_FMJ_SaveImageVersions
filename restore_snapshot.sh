#!/bin/bash
# restore_snapshot.sh
# Installe les dépendances uniquement pour les nodes qui ont été :
#   - clonés OU
#   - mis à jour (checkout d'un nouveau commit)

set -e

SNAPSHOT_FILE="$1"
[ -z "$SNAPSHOT_FILE" ] && { echo "❌ Usage: $0 <snapshot.txt>"; exit 1; }
[[ "$SNAPSHOT_FILE" != /* ]] && SNAPSHOT_FILE="$(pwd)/$SNAPSHOT_FILE"
[ ! -f "$SNAPSHOT_FILE" ] && { echo "❌ Fichier introuvable : $SNAPSHOT_FILE"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMFYUI_ROOT="$(realpath "$SCRIPT_DIR/../..")"
CUSTOM_NODES_DIR="$COMFYUI_ROOT/custom_nodes"

VENV_DIR="$COMFYUI_ROOT/venv"
[ ! -d "$VENV_DIR" ] && { echo "❌ venv manquant : $VENV_DIR"; exit 1; }

echo "📁 ComfyUI : $COMFYUI_ROOT"
echo "📄 Snapshot : $SNAPSHOT_FILE"
echo

# === ÉTAPE 1 : Environnement ===
echo "🔹 ÉTAPE 1/4 : Vérification de l'environnement"
source "$VENV_DIR/bin/activate"

PYTHON_EXPECTED=$(grep "^Python:" "$SNAPSHOT_FILE" | cut -d' ' -f2)
PYTORCH_EXPECTED=$(grep "^PyTorch:" "$SNAPSHOT_FILE" | cut -d' ' -f2-)
CUDA_EXPECTED=$(grep "^CUDA:" "$SNAPSHOT_FILE" | cut -d' ' -f2)

PYTHON_CURRENT=$(python -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')
PYTORCH_CURRENT=$(python -c 'import torch; print(torch.__version__)' 2>/dev/null || echo "N/A")
CUDA_CURRENT=$(python -c 'import torch; print(torch.version.cuda or "N/A")' 2>/dev/null || echo "N/A")

echo "   Python : attendu=$PYTHON_EXPECTED | actuel=$PYTHON_CURRENT"
echo "   PyTorch: attendu=$PYTORCH_EXPECTED | actuel=$PYTORCH_CURRENT"
echo "   CUDA   : attendu=$CUDA_EXPECTED | actuel=$CUDA_CURRENT"

if [[ "$PYTHON_EXPECTED" != "$PYTHON_CURRENT" ]] || [[ "$PYTORCH_EXPECTED" != "$PYTORCH_CURRENT" ]] || [[ "$CUDA_EXPECTED" != "$CUDA_CURRENT" ]]; then
    echo "⚠️  L'environnement ne correspond pas."
fi

read -p "✅ Continuer vers la sélection des commits ? (O/n) : " -n 1 -r
echo
[[ $REPLY =~ ^[Nn]$ ]] && { echo "❌ Annulé."; exit 1; }

# === ÉTAPE 2 : Collecter les actions nécessaires ===
echo
echo "🔹 ÉTAPE 2/4 : Détection des commits à mettre à jour..."

actions=()
modified_nodes=()  # ← Tous les nodes modifiés (clonés OU mis à jour)

COMFYUI_COMMIT=$(grep "^ComfyUI " "$SNAPSHOT_FILE" | grep -v "ComfyUI-" | head -n1 | cut -d' ' -f2)
[ -z "$COMFYUI_COMMIT" ] && { echo "❌ SHA ComfyUI non trouvé"; exit 1; }

CURRENT=$(git -C "$COMFYUI_ROOT" rev-parse HEAD 2>/dev/null || echo "")
if [[ "$CURRENT" != "$COMFYUI_COMMIT"* ]]; then
    actions+=("comfyui-core|$COMFYUI_COMMIT|update|")
fi

while IFS= read -r line; do
    if [[ "$line" =~ ^([a-zA-Z0-9_.-]+)[[:space:]]+([a-f0-9]{40}) ]]; then
        NAME="${BASH_REMATCH[1]}"
        COMMIT="${BASH_REMATCH[2]}"

        case "$NAME" in
            __pycache__|Python|PyTorch|CUDA|GPU|ComfyUI) continue ;;
        esac

        NODE_DIR="$CUSTOM_NODES_DIR/$NAME"
        if [ ! -d "$NODE_DIR/.git" ]; then
            URL=$(echo "$line" | cut -d' ' -f3-)
            [[ "$URL" == *" "* ]] && URL=""
            actions+=("$NAME|$COMMIT|clone|$URL")
        else
            CURRENT=$(git -C "$NODE_DIR" rev-parse HEAD 2>/dev/null || echo "")
            if [[ "$CURRENT" != "$COMMIT"* ]]; then
                actions+=("$NAME|$COMMIT|update|")
            fi
        fi
    fi
done < "$SNAPSHOT_FILE"

if [ ${#actions[@]} -eq 0 ]; then
    echo "   ✅ Tous les commits sont à jour."
    SELECTED_ACTIONS=()
else
    echo "   📋 Sélectionnez les commits à appliquer :"
    for i in "${!actions[@]}"; do
        IFS='|' read -r NAME COMMIT TYPE URL <<< "${actions[i]}"
        if [ "$TYPE" = "clone" ]; then
            echo "   $((i+1)). ➕ Cloner : $NAME @ ${COMMIT:0:8}"
        else
            echo "   $((i+1)). 🔄 Mettre à jour : $NAME @ ${COMMIT:0:8}"
        fi
    done
    echo "   all. Tous les éléments ci-dessus"
    echo

    read -p "Votre choix (ex: 1 3 5 ou 'all') : " CHOICE

    SELECTED_ACTIONS=()
    if [ "$CHOICE" = "all" ]; then
        for i in "${!actions[@]}"; do
            SELECTED_ACTIONS+=("$i")
        done
    else
        for num in $CHOICE; do
            idx=$((num - 1))
            if [ "$idx" -ge 0 ] && [ "$idx" -lt ${#actions[@]} ]; then
                SELECTED_ACTIONS+=("$idx")
            fi
        done
    fi
fi

# === ÉTAPE 3 : Appliquer les commits sélectionnés ===
echo
echo "🔹 ÉTAPE 3/4 : Application des commits sélectionnés..."

if [ ${#SELECTED_ACTIONS[@]} -eq 0 ]; then
    echo "   ✅ Aucune action sélectionnée."
else
    for idx in "${SELECTED_ACTIONS[@]}"; do
        IFS='|' read -r NAME COMMIT TYPE URL <<< "${actions[idx]}"
        if [ "$TYPE" = "clone" ]; then
            NODE_DIR="$CUSTOM_NODES_DIR/$NAME"
            mkdir -p "$CUSTOM_NODES_DIR"
            if [ -n "$URL" ]; then
                echo "   Clonage : $NAME"
                git clone "$URL" "$NODE_DIR" >/dev/null 2>&1
                modified_nodes+=("$NAME")  # ← ajouté
            else
                echo "   ⚠️ $NAME : URL manquante, ignoré"
                continue
            fi
        else
            if [ "$NAME" = "comfyui-core" ]; then
                echo "   Mise à jour : ComfyUI"
                cd "$COMFYUI_ROOT"
                git fetch >/dev/null 2>&1
                git checkout "$COMMIT" >/dev/null 2>&1
                # Pas de dépendances pour ComfyUI → pas ajouté à modified_nodes
            else
                echo "   Mise à jour : $NAME"
                NODE_DIR="$CUSTOM_NODES_DIR/$NAME"
                cd "$NODE_DIR"
                git fetch >/dev/null 2>&1
                git checkout "$COMMIT" >/dev/null 2>&1
                modified_nodes+=("$NAME")  # ← ajouté aussi pour les mises à jour
            fi
        fi
    done
    echo "   ✅ Commits appliqués."
fi

read -p "✅ Continuer vers la gestion des dépendances ? (O/n) : " -n 1 -r
echo
[[ $REPLY =~ ^[Nn]$ ]] && { echo "❌ Annulé."; exit 1; }

# === ÉTAPE 4 : Dépendances pour TOUS les nodes modifiés ===
echo
echo "🔹 ÉTAPE 4/4 : Installation des dépendances (nodes modifiés)..."

if [ ${#modified_nodes[@]} -eq 0 ]; then
    echo "   ℹ️  Aucun node modifié → aucune dépendance à installer."
else
    for NAME in "${modified_nodes[@]}"; do
        NODE_DIR="$CUSTOM_NODES_DIR/$NAME"
        [ ! -d "$NODE_DIR" ] && continue

        INSTALL_PY="$NODE_DIR/install.py"
        REQ_TXT="$NODE_DIR/requirements.txt"

        if [ -f "$INSTALL_PY" ]; then
            echo "      - $NAME : exécution de install.py"
            (
                cd "$NODE_DIR"
                python install.py
            ) || echo "        ⚠️ Échec de install.py (continuation)"
        elif [ -f "$REQ_TXT" ]; then
            echo "      - $NAME : installation via requirements.txt"
            if grep -q "^cgal" "$REQ_TXT" 2>/dev/null; then
                echo "        ⚠️ cgal ignoré (bug connu)"
            else
                pip install -r "$REQ_TXT" >/dev/null 2>&1 || echo "        ⚠️ Échec partiel (ignoré)"
            fi
        else
            echo "      - $NAME : aucun fichier d'installation trouvé"
        fi
    done
fi

# Info ComfyUI
if [ -f "$COMFYUI_ROOT/requirements.txt" ]; then
    echo "   ℹ️  ComfyUI : requirements.txt présent (pas d'installation auto)"
fi

echo
echo "✨ Restauration terminée !"
echo "🚀 Redémarrez ComfyUI pour appliquer les changements."