# version_metadata_saver.py
import os
import json
import numpy as np
from PIL import Image, PngImagePlugin
import folder_paths
import sys
import torch
import subprocess
from typing import Dict, Any, List, Optional

class FMJSaveImageVersions:
    _version_cache: Optional[Dict[str, str]] = None

    def __init__(self):
        self.output_dir = folder_paths.get_output_directory()
        self.type = "output"
        self.prefix_append = ""
        self.compress_level = 4

    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "images": ("IMAGE",),
                "filename_prefix": ("STRING", {"default": "FMJ_Versioned"}),
                "save_versions_as_json": ("BOOLEAN", {"default": False}),
                "prompt": ("STRING", {"default": ""}),
                "generation_seed": ("INT", {"default": 0, "min": 0, "max": 0xffffffffffffffff}),
                "create_comfyui_snapshot": ("BOOLEAN", {"default": False}),  # ✅ Nouveau bouton
            },
            "hidden": {"prompt_dict": "PROMPT", "extra_pnginfo": "EXTRA_PNGINFO"},
        }

    RETURN_TYPES = ()
    FUNCTION = "save_images"
    OUTPUT_NODE = True
    CATEGORY = "🌀FMJ"

    @classmethod
    def _get_versions(cls) -> Dict[str, str]:
        if cls._version_cache is not None:
            return cls._version_cache

        versions = {}
        versions["Python_Version"] = sys.version.split()[0]
        versions["PyTorch_Version"] = torch.__version__
        versions["CUDA_Version"] = torch.version.cuda if torch.cuda.is_available() else "CPU"

        current = os.path.dirname(__file__)
        comfy_path = current
        while current != os.path.dirname(current):
            if os.path.exists(os.path.join(current, "folder_paths.py")):
                comfy_path = current
                break
            current = os.path.dirname(current)

        try:
            comfy_ver = subprocess.check_output(
                ["git", "-C", comfy_path, "describe", "--tags", "--always"],
                stderr=subprocess.DEVNULL,
                cwd=comfy_path
            ).decode("utf-8").strip()
            versions["ComfyUI_Version"] = comfy_ver
        except Exception:
            versions["ComfyUI_Version"] = "Unknown"

        custom_versions = {}
        custom_nodes_dir = os.path.join(comfy_path, "custom_nodes")
        if os.path.exists(custom_nodes_dir):
            for item in os.listdir(custom_nodes_dir):
                item_path = os.path.join(custom_nodes_dir, item)
                if os.path.isdir(item_path) and os.path.exists(os.path.join(item_path, ".git")):
                    try:
                        ver = subprocess.check_output(
                            ["git", "-C", item_path, "describe", "--tags", "--always"],
                            stderr=subprocess.DEVNULL
                        ).decode("utf-8").strip()
                        custom_versions[item] = ver
                    except Exception:
                        continue

        versions["Custom_Nodes_Versions"] = json.dumps(custom_versions, separators=(',', ':'))
        cls._version_cache = versions
        return versions

    def save_images(
        self,
        images: torch.Tensor,
        filename_prefix: str = "FMJ_Versioned",
        save_versions_as_json: bool = False,
        prompt: str = "",
        generation_seed: int = 0,
        prompt_dict: Optional[Dict] = None,
        extra_pnginfo: Optional[Dict[str, Any]] = None,
        create_comfyui_snapshot: bool = False,  # ✅ Paramètre ajouté
    ) -> Dict[str, List[Dict[str, str]]]:
        seed_str = str(generation_seed)

        filename_prefix += self.prefix_append
        full_output_folder, filename, counter, subfolder, _ = folder_paths.get_save_image_path(
            filename_prefix, self.output_dir, images[0].shape[1], images[0].shape[0]
        )
        results = []

        version_metadata = self._get_versions()

        for batch_number, image in enumerate(images):
            i = 255.0 * image.cpu().numpy()
            img = Image.fromarray(np.clip(i, 0, 255).astype(np.uint8))

            filename_with_batch = filename.replace("%batch_num%", str(batch_number))
            file = f"{filename_with_batch}_{counter:05}_.png"

            # === AJOUT DU SNAPSHOT (seulement si demandé) ===
            snapshot_name = None
            if create_comfyui_snapshot:
                try:
                    comfy_root = os.path.dirname(folder_paths.get_input_directory())
                    cm_cli_path = os.path.join(comfy_root, "custom_nodes", "ComfyUI-Manager", "cm-cli.py")

                    if os.path.exists(cm_cli_path):
                        snapshots_dir = os.path.join(comfy_root, "user", "default", "ComfyUI-Manager", "snapshots")
                        if not os.path.exists(snapshots_dir):
                            snapshots_dir = os.path.join(comfy_root, "user", "__manager", "snapshots")
                        os.makedirs(snapshots_dir, exist_ok=True)

                        before = set(os.listdir(snapshots_dir))
                        result = subprocess.run(
                            [sys.executable, cm_cli_path, "save-snapshot"],
                            capture_output=True,
                            text=True,
                            cwd=comfy_root
                        )

                        if result.returncode == 0:
                            after = set(os.listdir(snapshots_dir))
                            new_files = after - before
                            if new_files:
                                auto_name = next(iter(new_files))
                                auto_path = os.path.join(snapshots_dir, auto_name)
                                custom_name = f"{os.path.splitext(file)[0]}.snapshot.json"
                                custom_path = os.path.join(snapshots_dir, custom_name)
                                os.rename(auto_path, custom_path)
                                snapshot_name = custom_name
                            else:
                                print("[FMJ] ⚠️ Aucun snapshot détecté.")
                        else:
                            print(f"[FMJ] ❌ cm-cli erreur: {result.stderr}")
                    else:
                        print(f"[FMJ] ❌ cm-cli.py introuvable.")
                except Exception as e:
                    print(f"[FMJ] ❌ Erreur snapshot: {e}")

            # === MÉTADONNÉES PNG (inchangées) ===
            metadata = PngImagePlugin.PngInfo()
            metadata.add_text("prompt", prompt)
            metadata.add_text("seed", seed_str)

            if prompt_dict is not None:
                metadata.add_text("prompt_dict", json.dumps(prompt_dict, separators=(',', ':')))
            if extra_pnginfo is not None:
                for key, value in extra_pnginfo.items():
                    try:
                        metadata.add_text(key, json.dumps(value, separators=(',', ':')))
                    except Exception:
                        metadata.add_text(key, str(value))

            for key, value in version_metadata.items():
                metadata.add_text(key, value)

            # ✅ Ajout du snapshot dans les métadonnées
            if snapshot_name:
                metadata.add_text("fmj_snapshot", snapshot_name)

            filepath = os.path.join(full_output_folder, file)
            img.save(filepath, pnginfo=metadata, compress_level=self.compress_level)

            # === SAUVEGARDE DU JSON (inchangée + snapshot) ===
            if save_versions_as_json:
                json_file = os.path.splitext(file)[0] + ".json"
                json_path = os.path.join(full_output_folder, json_file)

                full_metadata = {
                    "prompt": prompt,
                    "seed": generation_seed,
                    "prompt_dict": prompt_dict,
                    "extra_pnginfo": extra_pnginfo,
                    "versions": {
                        "ComfyUI_Version": version_metadata["ComfyUI_Version"],
                        "Python_Version": version_metadata["Python_Version"],
                        "PyTorch_Version": version_metadata["PyTorch_Version"],
                        "CUDA_Version": version_metadata["CUDA_Version"],
                        "Custom_Nodes_Versions": json.loads(version_metadata["Custom_Nodes_Versions"])
                    }
                }

                # ✅ Ajout du snapshot dans le JSON
                if snapshot_name:
                    full_metadata["fmj_snapshot"] = snapshot_name

                with open(json_path, "w", encoding="utf-8") as f:
                    json.dump(full_metadata, f, separators=(',', ':'), ensure_ascii=False)

            results.append({
                "filename": file,
                "subfolder": subfolder,
                "type": self.type
            })
            counter += 1

        return {"ui": {"images": results}}