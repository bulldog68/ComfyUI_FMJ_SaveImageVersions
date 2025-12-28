# 🌀 **FMJ Save Image + Versions**

> **Custom Nodes pour ComfyUI**  
> Sauvegarde d’images avec métadonnées complètes (prompt, seed, versions logicielles) + chargement intelligent.

---

## 📦 Installation

1. Clone ce dossier dans `ComfyUI/custom_nodes/` :
   ```bash
   git clone https://github.com/votre-nom/ComfyUI_FMJ_SaveImageVersions.git
   ```
2. Redémarre ComfyUI.

> ✅ Compatible avec toutes les versions récentes de ComfyUI.

---

## 🧩 Nœud 1 : **🌀 FMJ Save Image + Versions**

### 🔹 Description
Sauvegarde les images générées **avec traçabilité totale** :
- Prompt texte
- Seed de génération
- Versions exactes de **ComfyUI**, **Python**, **PyTorch**, **CUDA**, et **tous les custom nodes**
- Données sauvegardées **dans le PNG** (métadonnées standards) **et/ou dans un fichier `.json` séparé**

### 🔸 Entrées

| Entrée | Type | Description |
|-------|------|-------------|
| `images` | `IMAGE` | Images à sauvegarder |
| `filename_prefix` | `STRING` | Préfixe du nom de fichier (ex: `"FMJ_MonProjet"`) |
| `save_versions_as_json` | `BOOLEAN` | Si `True`, crée un fichier `.json` à côté de l’image |
| `prompt` | `STRING` | Texte du prompt (à connecter depuis un nœud texte ou CLIP) |
| `generation_seed` | `INT` | Seed de génération (à brancher depuis KSampler, Random Seed, etc.) |

> 💡 **Astuce** : Le nom `generation_seed` évite l’interface parasite (`randomize`) tout en restant fonctionnel.

### 🔸 Comportement
- Fichier PNG généré : `FMJ_XXXXX_.png`
- Fichier JSON optionnel : `FMJ_XXXXX_.json`
- Les métadonnées PNG incluent :
  - `prompt`
  - `seed`
  - `ComfyUI_Version`, `Python_Version`, etc.
- Le JSON contient **toutes les données en clair**, facilement exploitables par script.

---

## 🧩 Nœud 2 : **🔍 FMJ Load Metadata**

### 🔹 Description
Charge les métadonnées depuis **un fichier `.png` ou `.json`** et affiche un **rapport complet** :
- Prompt **complet** (non tronqué)
- Seed utilisée
- Comparaison des versions logicielles (avec alertes si incompatibilité)

### 🔸 Entrées

| Entrée | Type | Description |
|-------|------|-------------|
| `file` | `STRING (dropdown)` | Liste **tous les `.png` et `.json`** du dossier `output/` |

### 🔸 Sorties

| Sortie | Type | Usage |
|--------|------|-------|
| `prompt_text` | `STRING` | Prompt brut (utile pour rebrancher dans un workflow) |
| `version_report` | `STRING` | Rapport complet (à connecter à un **nœud "Show Text"** ou affiché dans l’UI) |

### 🔸 Exemple de rapport

```
🔍 FMJ Metadata Load Report:
============================================================
📝 Full Prompt:
masterpiece, best quality, photorealistic, a red panda in snow

🔢 Seed:
   217625533534410

✅ ComfyUI version matches: v0.3.12-45-gabc123

🧩 Custom Nodes:
   ✅ ComfyUI-Impact-Pack: v5.12.3
   ⚠️  ComfyUI-Manager: v2.4 → v2.5
============================================================
```

> ✅ Idéal pour **auditer**, **reproduire**, ou **diagnostiquer** une génération ancienne.

---

## 🛠️ Cas d’usage recommandés

### 1. **Reproductibilité long terme**
- Sauvegarde avec `save_versions_as_json = True`
- Archive le `.png` + `.json`
- Des mois plus tard : utilise **FMJ Load Metadata** pour vérifier que ton environnement est compatible

### 2. **Partage sécurisé**
- Envoie le `.png` → le destinataire peut **recharger le workflow complet** (via clic droit → *Open in ComfyUI*)  
- Tu peux aussi envoyer le `.json` pour une **inspection manuelle** des versions

### 3. **Audit de production**
- Intègre le nœud dans tous tes workflows finaux
- Garde une trace **machine-readable** de chaque génération

---

## 📁 Structure des fichiers

```
ComfyUI/
└── custom_nodes/
    └── ComfyUI_FMJ_SaveImageVersions/
        ├── __init__.py
        ├── version_metadata_saver.py   → 💾 FMJ Save Image + Versions
        └── load_metadata.py            → 🔍 FMJ Load Metadata
```

---

## 🔄 Compatibilité

- ✅ **ComfyUI** (vanilla)
- ✅ **ComfyUI-Manager**
- ✅ **Impact Pack**, **Efficiency Nodes**, etc.
- ✅ Tous les systèmes (Windows, Linux, macOS)

---

## 📜 Licence
GNU V3
> 🌀 **FMJ Nodes** – Parce que chaque pixel mérite d’être tracé.  
> Créé avec ❤️ pour la communauté ComfyUI.
