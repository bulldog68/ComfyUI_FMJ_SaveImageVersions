# load_metadata.py
import os
import json
import sys
import torch
import subprocess
from typing import Dict, Any, Tuple, Optional
from PIL import Image, PngImagePlugin

import folder_paths

def _get_current_versions(comfy_root: str) -> Dict[str, Any]:
    versions = {}
    versions["Python_Version"] = sys.version.split()[0]
    versions["PyTorch_Version"] = torch.__version__
    versions["CUDA_Version"] = torch.version.cuda if torch.cuda.is_available() else "CPU"

    try:
        comfy_ver = subprocess.check_output(
            ["git", "-C", comfy_root, "describe", "--tags", "--always"],
            stderr=subprocess.DEVNULL,
            cwd=comfy_root
        ).decode("utf-8").strip()
        versions["ComfyUI_Version"] = comfy_ver
    except Exception:
        versions["ComfyUI_Version"] = "Unknown"

    custom_versions = {}
    custom_nodes_dir = os.path.join(comfy_root, "custom_nodes")
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
    versions["Custom_Nodes_Versions"] = custom_versions
    return versions

def _detect_comfy_root() -> str:
    current = os.path.dirname(__file__)
    while current != os.path.dirname(current):
        if os.path.exists(os.path.join(current, "folder_paths.py")):
            return current
        current = os.path.dirname(current)
    return os.path.dirname(os.path.abspath(sys.argv[0]))

def _safe_json_loads(s: str) -> Optional[Dict]:
    if not s:
        return None
    try:
        return json.loads(s)
    except Exception:
        return None

class FMJLoadMetadata:  # ✅ CORRIGÉ : deux-points ajoutés
    @classmethod
    def INPUT_TYPES(cls):
        output_dir = folder_paths.get_output_directory()
        files = []
        if os.path.exists(output_dir):
            files = [
                f for f in os.listdir(output_dir)
                if f.endswith(".json") or f.endswith(".png")
            ]
        if not files:
            files = ["No .json or .png files found"]
        return {
            "required": {
                "file": (sorted(files),),
            }
        }

    RETURN_TYPES = ("STRING", "STRING")
    RETURN_NAMES = ("prompt_text", "version_report")
    FUNCTION = "load_metadata"
    CATEGORY = "🌀FMJ"
    OUTPUT_NODE = False

    def load_metadata(self, file: str) -> Tuple[str, str]:
        output_dir = folder_paths.get_output_directory()
        file_path = os.path.join(output_dir, file)

        if not os.path.isfile(file_path):
            error_msg = f"[ERROR] File not found: {file_path}"
            print(error_msg)
            return ("", error_msg)

        data = {}
        prompt_text = ""
        seed_display = "unknown"

        try:
            if file.endswith(".json"):
                with open(file_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                prompt_raw = data.get("prompt")
                prompt_text = str(prompt_raw) if prompt_raw is not None else ""
                seed_value = data.get("seed", "unknown")
                if isinstance(seed_value, (int, float)):
                    seed_display = str(int(seed_value))
                else:
                    seed_display = str(seed_value)

            elif file.endswith(".png"):
                img = Image.open(file_path)
                pnginfo = img.info
                prompt_text = pnginfo.get("prompt", "")
                seed_display = pnginfo.get("seed", "unknown")

                versions_data = {}
                for key in ["ComfyUI_Version", "Python_Version", "PyTorch_Version", "CUDA_Version", "Custom_Nodes_Versions"]:
                    val = pnginfo.get(key)
                    if val is not None:
                        if key == "Custom_Nodes_Versions":
                            versions_data[key] = _safe_json_loads(val) or {}
                        else:
                            versions_data[key] = val
                data["versions"] = versions_data

            else:
                return ("", "[ERROR] Unsupported file type. Use .json or .png")

        except Exception as e:
            error_msg = f"[ERROR] Failed to read file: {e}"
            print(error_msg)
            return ("", error_msg)

        saved_versions = data.get("versions", {})
        saved_custom = saved_versions.get("Custom_Nodes_Versions", {})

        comfy_root = _detect_comfy_root()
        current_versions = _get_current_versions(comfy_root)
        current_custom = current_versions["Custom_Nodes_Versions"]

        report_lines = ["🔍 FMJ Metadata Load Report:", "=" * 60]

        report_lines.append("📝 Full Prompt:")
        report_lines.append(prompt_text if prompt_text else "(no prompt)")

        report_lines.append("\n🔢 Seed:")
        report_lines.append(f"   {seed_display}")

        saved_comfy = saved_versions.get("ComfyUI_Version", "Unknown")
        current_comfy = current_versions["ComfyUI_Version"]
        if saved_comfy != current_comfy:
            report_lines.append(f"\n⚠️  ComfyUI version changed: {saved_comfy} → {current_comfy}")
        else:
            report_lines.append(f"\n✅ ComfyUI version matches: {current_comfy}")

        all_nodes = set(saved_custom.keys()) | set(current_custom.keys())
        if all_nodes:
            report_lines.append("\n🧩 Custom Nodes:")
            for node in sorted(all_nodes):
                saved_ver = saved_custom.get(node, "NOT INSTALLED")
                current_ver = current_custom.get(node, "NOT INSTALLED")
                if saved_ver != current_ver:
                    report_lines.append(f"   ⚠️  {node}: {saved_ver} → {current_ver}")
                else:
                    report_lines.append(f"   ✅ {node}: {current_ver}")

        report_lines.append("\n" + "=" * 60)
        report = "\n".join(report_lines)
        print(report)
        return (prompt_text, report)