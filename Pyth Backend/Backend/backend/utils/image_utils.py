"""
utils/image_utils.py
─────────────────────
Helper utilities for image handling.
"""
import base64
from pathlib import Path


def file_to_base64(path: str) -> str:
    """Convert a local image file to a base64 string."""
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


def allowed_image(filename: str) -> bool:
    """Check whether an uploaded file has an acceptable image extension."""
    return Path(filename).suffix.lower() in {".jpg", ".jpeg", ".png", ".webp", ".bmp"}


def get_mime(filename: str) -> str:
    ext = Path(filename).suffix.lower()
    return {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png":  "image/png",
        ".webp": "image/webp",
        ".bmp":  "image/bmp",
    }.get(ext, "image/jpeg")
