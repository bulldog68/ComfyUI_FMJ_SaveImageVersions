import os
import json
import torch
import numpy as np
from PIL import Image, PngImagePlugin
from pathlib import Path
import subprocess
import sys
import time
import folder_paths

# Détection de l'OS
IS_WINDOWS = os.name == "nt"

# ======================
# SAVE NODE
# ======================
class FMJ_SaveImageWithSnapshot:
    @classmethod
    def INPUT_TYPES(s):
        return {
            "required": {
                "images": ("IMAGE",),
                "positive": ("STRING", {"default": "", "multiline": False}),
                "negative": ("STRING", {"default": "", "multiline": False}),
                "filename_prefix": ("STRING", {"default": "fmj"}),
                "save_snapshot": ("BOOLEAN", {"default": True}),
            },
            "hidden": {"prompt": "PROMPT", "extra_pnginfo": "EXTRA_PNGINFO"},
        }

    RETURN_TYPES = ()
    FUNCTION = "save_images"
    OUTPUT_NODE = True
    CATEGORY = "🌀FMJ"

    def save_images(self, images, positive, negative, filename_prefix="fmj", save_snapshot=True, prompt=None, extra_pnginfo=None):
        output_dir = folder_paths.get_output_directory()
        os.makedirs(output_dir, exist_ok=True)
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        results = []

        comfy_root = Path.cwd()
        script_dir = Path(__file__).parent
        snapshot_script = script_dir / "snapshot.py"

        for idx, image in enumerate(images):
            i = 255.0 * image.cpu().numpy()
            img = Image.fromarray(np.clip(i, 0, 255).astype(np.uint8))
            png_name = f"{filename_prefix}_{timestamp}_{idx:02}.png"
            png_path = os.path.join(output_dir, png_name)

            metadata = PngImagePlugin.PngInfo()
            if extra_pnginfo:
                for key, value in extra_pnginfo.items():
                    metadata.add_text(key, json.dumps(value))
            metadata.add_text("positive", positive)
            metadata.add_text("negative", negative)

            img.save(png_path, pnginfo=metadata, compress_level=4)

            if save_snapshot:
                if snapshot_script.exists():
                    try:
                        subprocess.run([sys.executable, str(snapshot_script)], cwd=comfy_root, check=True)
                    except Exception as e:
                        print(f"⚠️ Erreur snapshot : {e}")

                global_snapshot = comfy_root / "comfyui_snapshot.txt"
                if global_snapshot.is_file():
                    txt_name = f"{filename_prefix}_{timestamp}_{idx:02}.snapshot.txt"
                    txt_path = Path(output_dir) / txt_name
                    try:
                        txt_path.write_bytes(global_snapshot.read_bytes())
                        print(f"✅ Snapshot copié : {txt_name}")
                    except Exception as e:
                        print(f"❌ Erreur copie : {e}")
                else:
                    print("⚠️ comfyui_snapshot.txt introuvable.")
            else:
                print("⏭️ Snapshot désactivé.")

            results.append({"filename": png_name, "subfolder": "", "type": "output"})

        return {"ui": {"images": results}}

    @classmethod
    def IS_CHANGED(s, images):
        return time.time()


# ======================
# LOAD NODE
# ======================
class FMJ_LoadImageWithSnapshot:
    @classmethod
    def INPUT_TYPES(s):
        input_dir = folder_paths.get_input_directory()
        files = [f for f in os.listdir(input_dir) if f.endswith(".png")]
        return {"required": {"image": (sorted(files), {"image_upload": True})}}

    RETURN_TYPES = ("IMAGE", "STRING", "STRING", "STRING", "STRING")
    RETURN_NAMES = ("image", "positive", "negative", "config_info", "restore_command")
    FUNCTION = "load"
    CATEGORY = "🌀FMJ"

    def load(self, image):
        image_path = folder_paths.get_annotated_filepath(image)
        img = Image.open(image_path).convert("RGB")
        img_tensor = torch.from_numpy(np.array(img).astype(np.float32) / 255.0)[None,]

        with Image.open(image_path) as im:
            meta = im.text if im.format == "PNG" else {}
        positive = meta.get("positive", "")
        negative = meta.get("negative", "")

        image_stem = Path(image).stem
        output_dir = Path(folder_paths.get_output_directory())
        snapshot_path = output_dir / f"{image_stem}.snapshot.txt"

        if not snapshot_path.is_file():
            input_dir = Path(folder_paths.get_input_directory())
            snapshot_path = input_dir / f"{image_stem}.snapshot.txt"

        if snapshot_path.is_file():
            config_info = snapshot_path.read_text(encoding="utf-8")
            snapshot_rel = f"output{os.sep}{snapshot_path.name}"
            if IS_WINDOWS:
                cmd = f"custom_nodes\\ComfyUI_FMJ_SaveImageVersions\\restore_snapshot.bat \"{snapshot_rel}\""
                restore_cmd = (
                    "# 📌 Ouvrez un terminal dans le répertoire ComfyUI, puis copiez-collez cette ligne :\n"
                    "# ⚠️  Quittez ComfyUI avant de lancer la restauration !\n"
                    f"{cmd}"
                )
            else:
                cmd = f"./custom_nodes/ComfyUI_FMJ_SaveImageVersions/restore_snapshot.sh \"{snapshot_rel}\""
                restore_cmd = (
                    "# 📌 Ouvrez un terminal dans le répertoire ComfyUI, puis copiez-collez cette ligne :\n"
                    "# ⚠️  Quittez ComfyUI avant de lancer la restauration !\n"
                    f"{cmd}"
                )
        else:
            config_info = "⚠️ Fichier .snapshot.txt non trouvé."
            restore_cmd = "# Générez une image avec 'Save Image + Snapshot (FMJ)'."

        return (img_tensor, positive, negative, config_info, restore_cmd)


# ======================
# MAPPING
# ======================
NODE_CLASS_MAPPINGS = {
    "FMJ_SaveImageWithSnapshot": FMJ_SaveImageWithSnapshot,
    "FMJ_LoadImageWithSnapshot": FMJ_LoadImageWithSnapshot,
}
NODE_DISPLAY_NAME_MAPPINGS = {
    "FMJ_SaveImageWithSnapshot": "💾 Save Image + Snapshot (FMJ)",
    "FMJ_LoadImageWithSnapshot": "🔍 Load Image + Snapshot (FMJ)",
}
