```markdown
# ComfyUI_FMJ_SaveImageVersions

Sauvegarde d’images avec métadonnées complètes (prompt, workflow, versions logicielles, commit)

Ce dépôt fournit des nœuds ComfyUI pour :
- Sauvegarder des images en PNG avec métadonnées (positive / negative prompt, autres champs JSON),
- Générer et copier un snapshot décrivant l’environnement (commits, versions, GPU, etc.),
- Charger une image et restaurer des informations depuis ses métadonnées.

Important : ce projet exécute localement un petit script `snapshot.py` pour capturer l’état du dépôt ComfyUI et des nœuds personnalisés. Ne l’exécutez que sur des environnements de confiance.

---

## Sommaire rapide

- Installation (Manager ou manuelle)
- Utilisation (nœuds ComfyUI)
- Tests (pytest)
- Sécurité & recommandations
- Contribution & releases
- Licence

---

## Installation

Deux méthodes possibles : via ComfyUI Manager (si disponible dans votre version) ou manuelle.

### 1) Via ComfyUI Manager (UI)
1. Ouvrez ComfyUI et allez dans l'onglet Manager / Plugins.
2. Choisissez « Install from Git repository » ou « Install from URL ».
3. Entrez l'URL du dépôt :
   ```
   https://github.com/bulldog68/ComfyUI_FMJ_SaveImageVersions
   ```
4. Si le Manager vous propose une branche ou un sous-dossier, indiquez la branche souhaitée (par défaut `main`) et laissez le sous-dossier vide si les nœuds sont à la racine du repo.
5. Installez et redémarrez ComfyUI si nécessaire.

> Remarque : les implémentations du "Manager" peuvent varier selon la version de ComfyUI. Si l'option d'installation directe n'est pas disponible, utilisez la méthode manuelle ci‑dessous.

### 2) Installation manuelle (fiable)
Depuis la racine de votre installation ComfyUI :
```bash
cd /chemin/vers/ComfyUI/custom_nodes
git clone https://github.com/bulldog68/ComfyUI_FMJ_SaveImageVersions
```
Puis redémarrez ComfyUI.

---

## Dépendances

- Python 3.8+
- Pillow
- numpy
- (optionnel) torch si vous utilisez des fonctions dépendantes de PyTorch

Installer rapidement les dépendances usuelles :
```bash
pip install pillow numpy
# pour les tests
pip install pytest
```

---

## Utilisation

Après installation, les nœuds disponibles sont (exemples de noms) :
- `FMJ_SaveImagesWithSnapshot` — sauver des images avec métadonnées et option snapshot
- `FMJ_LoadImageWithSnapshot` — charger une image et lire ses métadonnées

Flux basique (Save node) :
1. Configurez le répertoire de sortie via ComfyUI (folder_paths).
2. Dans le nœud `FMJ_SaveImagesWithSnapshot`, fournissez :
   - `images` (tensors depuis le graph),
   - `filename_prefix` (sera sanitizé),
   - `positive` / `negative` (prompts),
   - `extra_pnginfo` (dictionnaire facultatif),
   - `save_snapshot` (bool).
3. Le nœud écrit un PNG et, si activé, exécute `snapshot.py` et copie `comfyui_snapshot.txt` dans le dossier de sortie.

Load node : lit les métadonnées PNG si présentes et retourne `image, positive, negative, config_info, restore_command`.

---

## Tests

Un petit jeu de tests pytest est fourni pour les utilitaires de sécurité.

Exécuter les tests depuis la racine du dépôt ComfyUI (ou en précisant PYTHONPATH) :

Option A — lancer depuis le dossier du package :
```bash
cd custom_nodes/ComfyUI_FMJ_SaveImageVersions
PYTHONPATH=. pytest -q tests/test_security_utils.py
```

Option B — lancer depuis la racine du repo ComfyUI (ajuster le chemin) :
```bash
PYTHONPATH=custom_nodes/ComfyUI_FMJ_SaveImageVersions pytest -q custom_nodes/ComfyUI_FMJ_SaveImageVersions/tests/test_security_utils.py
```

Les tests vérifient :
- la robustesse de la vérification de chemins (`is_within_directory`)
- le comportement de `safe_run_git` dans un dossier sans dépôt
- le calcul SHA256 d’un fichier

> Si vous exécutez les tests sur Windows, le test de symlink est ignoré par défaut (nécessite des permissions élevées).

---

## Sécurité — points importants

J’ai appliqué plusieurs corrections visant la sécurité. En résumé :

- Remplacement des appels git utilisant `shell=True` par des appels sûrs via `subprocess.run([...])` (module `security_utils.safe_run_git`).
- Vérification robuste des chemins de sortie : utilisation de `os.path.realpath` + `os.path.commonpath` (fonction `is_within_directory`) pour empêcher path traversal et attaques via symlink.
- Journalisation de l’empreinte SHA256 du script `snapshot.py` avant exécution (audit).
- Gestion d’exceptions plus spécifique (éviter `except:` bare).
- Limites sur la taille des métadonnées PNG ajoutées (pour éviter l’abus ou les attaques par payload volumineux).
- Validation attendue côté restore : si des valeurs du snapshot sont utilisées pour exécuter des commandes (ex. commits, scripts), validez strictement le format (p.ex. SHA hexadécimal via regex) avant utilisation.

Recommandations d’exploitation :
- Exécutez `snapshot.py` et la copie du snapshot uniquement dans des environnements de confiance.
- Restreignez les permissions du dossier `custom_nodes` et du dossier de sortie (ne laissez pas d’écritures publiques sur ces dossiers).
- Évitez d’inclure des secrets dans les métadonnées ou dans `comfyui_snapshot.txt`.
- Pour durcir davantage, considérez de stocker une empreinte attendue (sha256) pour `snapshot.py` et refuser l’exécution si elle diffère.

---

## Debug / Résolution de problèmes courants

- ComfyUI affiche `IMPORT FAILED` pour le dossier du nœud :
  - Ouvrez ComfyUI depuis un terminal pour voir la traceback complète : `python main.py` ou `./run.sh`.
  - Vérifiez la présence de `security_utils.py` et l’absence d’erreurs de syntaxe :
    ```bash
    python -m py_compile custom_nodes/ComfyUI_FMJ_SaveImageVersions/*.py
    ```
  - Assurez-vous que les imports relatifs sont robustes (le code fourni contient des fallbacks).

- Tests pytest ne trouvent pas `security_utils` :
  - Exécutez les tests depuis le dossier du package ou ajoutez le package au PYTHONPATH. Voir la section Tests ci‑dessus.

---

## Fichiers importants

- `save_restore_nodes.py` — nœuds ComfyUI principaux (save & load)
- `snapshot.py` — génération du fichier `comfyui_snapshot.txt`
- `security_utils.py` — utilitaires : safe_run_git, is_within_directory, sha256_of_file
- `tests/test_security_utils.py` — tests unitaires
- `pyproject.toml` — metadata (section `[tool.comfy]` utilisée par certains managers)

---

## Licence

Voir le fichier `LICENSE` dans le dépôt pour les détails de la licence.

Dites‑moi quelle action suivante vous souhaitez.
```
