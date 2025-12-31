# 📦 ComfyUI_FMJ_SaveImageVersions

**Advanced image saving with full environment snapshot & reproducible restoration**  
*By FMJ — December 2025*

---

## 🔧 Features

✅ **Smart Saving**:
- PNG with **embedded workflow** (just like official `SaveImage`)
- **Positive/negative prompts** stored in PNG metadata
- Automatic **environment snapshot** (Python, PyTorch, CUDA, Git commits)

✅ **Reproducible Restoration**:
- Recreate **exact environment** from just a PNG + `.snapshot.txt`
- Interactive restoration script (Linux/macOS/Windows)
- Version verification + user confirmation

✅ **ComfyUI Integration**:
- **Save node** with option to disable snapshot
- **Load node** that extracts prompts, config, and provides restore command

---

## 📁 File Structure

```bash
ComfyUI/
└── custom_nodes/
    └── ComfyUI_FMJ_SaveImageVersions/
        ├── __init__.py
        ├── save_restore_nodes.py   # ComfyUI nodes
        ├── snapshot.py             # Environment snapshot generator
        ├── restore_snapshot.sh     # Linux/macOS restore script
        └── restore_snapshot.bat    # Windows restore script
```

---

## 🚀 Installation

1. **Create the folder** `ComfyUI/custom_nodes/ComfyUI_FMJ_SaveImageVersions/`

2. **Place these files** inside:
   - [`__init__.py`](#initpy)
   - [`save_restore_nodes.py`](#save_restore_nodespy)
   - [`snapshot.py`](#snapshotpy)
   - [`restore_snapshot.sh`](#restore_snapshotsh)
   - [`restore_snapshot.bat`](#restore_snapshotbat)

3. **Restart ComfyUI**

4. **Verify** nodes appear in ComfyUI:
   - **"Save Image + Snapshot (FMJ)"**
   - **"Load Image + Snapshot (FMJ)"**

---

### `__init__.py`
```python
from .save_restore_nodes import NODE_CLASS_MAPPINGS, NODE_DISPLAY_NAME_MAPPINGS
```

### `save_restore_nodes.py`
→ [Get the complete file here](#complete-save_restore_nodespy-file)

### `snapshot.py`
→ Use your existing version that generates `comfyui_snapshot.txt`  
(The version provided in conversation history works)

---

## 🖼️ Usage — Saving

1. In your workflow, replace `SaveImage` with **"Save Image + Snapshot (FMJ)"**

2. **Configure**:
   - `positive`: your positive prompt
   - `negative`: your negative prompt
   - `filename_prefix`: file prefix (e.g., `"my_project"`)
   - `save_snapshot`: ✅ checked (uncheck to disable)

3. **Execute** → in `output/`, you'll get:
   ```
   my_project_20251231_100000_00.png
   my_project_20251231_100000_00.snapshot.txt
   ```

> 💡 The PNG contains the **workflow** and **prompts** → directly loadable in ComfyUI.

---

## 📂 Usage — Loading

1. **Copy** `.png` + `.snapshot.txt` files to `input/` *(optional but useful)*

2. Use **"Load Image + Snapshot (FMJ)"**:
   - Connect `positive` / `negative` to your `CLIP Text Encode` nodes
   - Connect `config_info` to a `ShowText` node to view environment
   - Connect `restore_command` to a `ShowText` node → you'll see:

     ```text
     # 📌 Open a terminal in the ComfyUI directory, then copy-paste this line:
     # ⚠️  Quit ComfyUI before starting restoration!
     ./custom_nodes/ComfyUI_FMJ_SaveImageVersions/restore_snapshot.sh "output/my_project_20251231_100000_00.snapshot.txt"
     ```

---

## 🔁 Full Restoration

> ⚠️ **Quit ComfyUI before proceeding!**

### 🐧 Linux / macOS

1. Open terminal in **`ComfyUI/` directory**
2. Paste the displayed command (example):
   ```bash
   ./custom_nodes/ComfyUI_FMJ_SaveImageVersions/restore_snapshot.sh "output/my_project_20251231_100000_00.snapshot.txt"
   ```
3. **Follow instructions**:
   - Script activates the `venv`
   - Compares versions
   - Asks for confirmation before each action
4. **Restart ComfyUI**

### 🪟 Windows

1. Open **CMD** or **PowerShell** in **`ComfyUI/` directory**
2. Paste the command (example):
   ```cmd
   custom_nodes\ComfyUI_FMJ_SaveImageVersions\restore_snapshot.bat "output\my_project_20251231_100000_00.snapshot.txt"
   ```
3. **Follow instructions**  
   > 💡 For complete custom nodes restoration, use **WSL** with the Linux script.

---

## ⚙️ Requirements

- **Python venv** in `ComfyUI/venv`  
  → If missing, create it:
  ```bash
  cd ComfyUI
  python -m venv venv
  # Activate it, then install ComfyUI dependencies
  ```

- **Git** installed (for commit restoration)

- **Execute permissions** (Linux/macOS):
  ```bash
  chmod +x custom_nodes/ComfyUI_FMJ_SaveImageVersions/restore_snapshot.sh
  ```

---

## ❓ FAQ

### ❓ *Load node can't find `.snapshot.txt`?*
→ Ensure **PNG and snapshot filenames match exactly** (only extension differs).

### ❓ *Error "venv not found"?*
→ Create a venv in `ComfyUI/venv` **before** saving or restoring.

### ❓ *Want to disable snapshot for speed?*
→ Uncheck `save_snapshot` in the Save node.

### ❓ *Restoration fails due to version mismatch?*
→ The script **asks for confirmation**. If you're sure, answer **`o`**.

---

## 📜 License

MIT — use, modify, and share freely.

---

## 🙏 Acknowledgements

Thanks to the ComfyUI community for the inspiration!  
This project makes creation truly **reproducible**. 🎨

---

> ✨ **Pro Tip**: Archive your `output/*.png` + `*.snapshot.txt` files in a project folder — you can **return to any generation** even 5 years later!
