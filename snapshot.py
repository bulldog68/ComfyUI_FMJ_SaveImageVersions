#!/usr/bin/env python3
import sys
import subprocess
from pathlib import Path
import hashlib
from security_utils import safe_run_git

def git(cmd_args, cwd):
    # wrapper kept for compatibility with older calls; expects list of args
    return safe_run_git(cmd_args, cwd)

# Trouver la racine de ComfyUI (doit contenir main.py)
script_dir = Path(__file__).resolve().parent
comfyui_root = None
for parent in [script_dir] + list(script_dir.parents):
    if (parent / "main.py").exists():
        comfyui_root = parent
        break

if comfyui_root is None:
    print("❌ main.py non trouvé. Ce script doit être dans ComfyUI/custom_nodes/...")
    sys.exit(1)

# Récupérer infos environnement
lines = []
try:
    import torch
    lines.extend([
        f"Python: {sys.version.split()[0]}",
        f"PyTorch: {torch.__version__}",
        f"CUDA: {torch.version.cuda or 'N/A'}",
        f"GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'N/A'}"
    ])
except ImportError:
    lines.extend([
        f"Python: {sys.version.split()[0]}",
        "PyTorch: non installé",
        "CUDA: N/A",
        "GPU: N/A"
    ])

lines.append("")

# ComfyUI core
core_commit = git(["rev-parse", "HEAD"], comfyui_root)
core_remote = git(["remote", "get-url", "origin"], comfyui_root) or "https://github.com/comfyanonymous/ComfyUI.git"
lines.append(f"ComfyUI {core_commit or 'unknown'} {core_remote}")
lines.append("")

# Custom nodes
custom_nodes = comfyui_root / "custom_nodes"
if custom_nodes.is_dir():
    for node_dir in sorted(custom_nodes.iterdir()):
        if node_dir.is_dir():
            commit = git(["rev-parse", "HEAD"], node_dir)
            remote = git(["remote", "get-url", "origin"], node_dir)
            if commit and remote:
                lines.append(f"{node_dir.name} {commit} {remote}")
            elif commit:
                lines.append(f"{node_dir.name} {commit}")

# Écrire dans la racine
output = comfyui_root / "comfyui_snapshot.txt"
try:
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"✅ Snapshot sauvegardé : {output}")
except OSError as e:
    print(f"❌ Impossible d'écrire le snapshot : {e}")