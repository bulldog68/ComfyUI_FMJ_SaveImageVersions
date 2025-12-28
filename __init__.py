# __init__.py
from .version_metadata_saver import FMJSaveImageVersions
from .load_metadata import FMJLoadMetadata

NODE_CLASS_MAPPINGS = {
    "FMJSaveImageVersions": FMJSaveImageVersions,
    "FMJLoadMetadata": FMJLoadMetadata,
}

NODE_DISPLAY_NAME_MAPPINGS = {
    "FMJSaveImageVersions": "💾 FMJ Save Image + Versions",
    "FMJLoadMetadata": "🔍 FMJ Load Metadata",
}
