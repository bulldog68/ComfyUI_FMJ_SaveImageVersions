#!/bin/bash
# restore_snapshot.sh
# Usage: ./restore_snapshot.sh "chemin/vers/fichier.snapshot.txt"

set -e

# === Gestion du fichier snapshot ===
SNAPSHOT_FILE="$1"
if [ -z "$SNAPSHOT_FILE" ]; then
    echo "❌ Usage: $0 \"<chemin/vers/fichier.snapshot.txt>\""
    exit 1
fi

# Convertir en chemin absolu si relatif
if [[ "$SNAPSHOT_FILE" != /* ]]; then
    SNAPSHOT_FILE="$(pwd)/$SNAPSHOT_FILE"
fi

if [ ! -f "$SNAPSHOT_FILE" ]; then
    echo "❌ Fichier introuvable : $SNAPSHOT_FILE"
    exit 1
fi

# === Détection racine ComfyUI (2 niveaux au lieu de 3) ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMFYUI_ROOT="$SCRIPT_DIR/../.."
COMFYUI_ROOT="$(realpath "$COMFYUI_ROOT")"

echo "📁 Racine ComfyUI : $COMFYUI_ROOT"
echo "📄 Snapshot : $SNAPSHOT_FILE"
echo

# === Activation du venv ===
VENV_DIR="$COMFYUI_ROOT/venv"
if [ ! -d "$VENV_DIR" ]; then
    echo "❌ Dossier venv introuvable : $VENV_DIR"
    echo "💡 Créez-le avec : python -m venv venv"
    exit 1
fi

echo "➡️ Activation du venv..."
source "$VENV_DIR/bin/activate"
echo "✅ Venv activé."
echo

# === Lecture des versions attendues ===
echo "🔍 Lecture du snapshot..."
PYTHON_EXPECTED=$(grep "^Python:" "$SNAPSHOT_FILE" | cut -d' ' -f2)
PYTORCH_EXPECTED=$(grep "^PyTorch:" "$SNAPSHOT_FILE" | cut -d' ' -f2-)
CUDA_EXPECTED=$(grep "^CUDA:" "$SNAPSHOT_FILE" | cut -d' ' -f2)

echo "📦 Versions attendues :"
echo "   Python : $PYTHON_EXPECTED"
echo "   PyTorch: $PYTORCH_EXPECTED"
echo "   CUDA   : $CUDA_EXPECTED"
echo

# === Détection versions actuelles (dans le venv) ===
echo "🔍 Détection de l'environnement actuel..."
PYTHON_CURRENT=$(python -c "import sys; print('.'.join(map(str, sys.version_info[:3])))")
if python -c "import torch" >/dev/null 2>&1; then
    PYTORCH_CURRENT=$(python -c "import torch; print(torch.__version__)")
    CUDA_CURRENT=$(python -c "import torch; print(torch.version.cuda or 'N/A')")
else
    PYTORCH_CURRENT="non installé"
    CUDA_CURRENT="N/A"
fi

echo "⚙️ Versions actuelles :"
echo "   Python : $PYTHON_CURRENT"
echo "   PyTorch: $PYTORCH_CURRENT"
echo "   CUDA   : $CUDA_CURRENT"
echo

# === Confirmation ===
MATCH=1
[ "$PYTHON_EXPECTED" != "$PYTHON_CURRENT" ] && MATCH=0
[ "$PYTORCH_EXPECTED" != "$PYTORCH_CURRENT" ] && MATCH=0
[ "$CUDA_EXPECTED" != "$CUDA_CURRENT" ] && MATCH=0

if [ "$MATCH" -eq 0 ]; then
    echo "⚠️ ATTENTION : L'environnement NE CORRESPOND PAS."
    read -p "Continuer quand même ? (o/N) : " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Oo]$ ]]; then
        echo "❌ Annulé."
        exit 1
    fi
else
    echo "✅ Environnement compatible."
    read -p "Continuer la restauration ? (O/n) : " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "❌ Annulé."
        exit 1
    fi
fi

# === Restauration ComfyUI core ===
COMFYUI_LINE=$(grep "^ComfyUI " "$SNAPSHOT_FILE" | grep -v "ComfyUI-" | head -n1)
if [ -z "$COMFYUI_LINE" ]; then
    echo "❌ Ligne 'ComfyUI' non trouvée dans le snapshot."
    exit 1
fi

COMFYUI_COMMIT=$(echo "$COMFYUI_LINE" | cut -d' ' -f2)
echo
echo "🔄 Restauration de ComfyUI @ ${COMFYUI_COMMIT:0:8}..."
cd "$COMFYUI_ROOT"
git fetch
git checkout "$COMFYUI_COMMIT"
echo "✅ ComfyUI restauré."
echo

# === Restauration custom nodes ===
echo "🔄 Restauration des custom nodes..."
CUSTOM_NODES_DIR="$COMFYUI_ROOT/custom_nodes"
mkdir -p "$CUSTOM_NODES_DIR"

while IFS= read -r line; do
    # Vérifier si la ligne contient un nom + commit (40 caractères hexa)
    if [[ "$line" =~ ^[a-zA-Z0-9_.-]+\ +[a-f0-9]{40} ]]; then
        NAME=$(echo "$line" | cut -d' ' -f1)
        COMMIT=$(echo "$line" | cut -d' ' -f2)
        REMAINDER=$(echo "$line" | cut -d' ' -f3-)
        # Déterminer si le reste est une URL (et non une info système)
        if [[ -n "$REMAINDER" && "$REMAINDER" != *"GPU:"* && "$REMAINDER" != *"Python:"* && "$REMAINDER" != *"PyTorch:"* ]]; then
            URL="$REMAINDER"
        else
            URL=""
        fi

        echo "   - $NAME @ ${COMMIT:0:8}"
        NODE_DIR="$CUSTOM_NODES_DIR/$NAME"

        if [ ! -d "$NODE_DIR" ]; then
            if [ -n "$URL" ]; then
                git clone "$URL" "$NODE_DIR"
            else
                echo "     ⚠️ URL manquante, ignoré."
                continue
            fi
        else
            cd "$NODE_DIR"
            git fetch
            cd "$COMFYUI_ROOT"
        fi

        cd "$NODE_DIR"
        git checkout "$COMMIT"
        cd "$COMFYUI_ROOT"
    fi
done < "$SNAPSHOT_FILE"

# === Installation dépendances ===
echo
echo "📥 Installation des dépendances dans le venv..."
pip install -r requirements.txt

for req in "$CUSTOM_NODES_DIR"/*/requirements.txt; do
    if [ -f "$req" ]; then
        echo "   - Installation : $req"
        pip install -r "$req"
    fi
done

echo
echo "✅ Restauration terminée !"
echo "🚀 Redémarrez ComfyUI pour appliquer les changements."