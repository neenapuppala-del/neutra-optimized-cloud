"""
utils/preprocess.py
────────────────────
Image preprocessing utilities shared across services.
"""
import numpy as np
from config import IMAGE_SIZE

try:
    from tensorflow.keras.preprocessing.image import load_img, img_to_array
    TF_AVAILABLE = True
except ImportError:
    TF_AVAILABLE = False

try:
    from PIL import Image
    PIL_AVAILABLE = True
except ImportError:
    PIL_AVAILABLE = False


def load_and_preprocess(image_path: str) -> np.ndarray | None:
    """
    Load an image and return a (1, H, W, 3) float32 array in [0, 1].
    Falls back to PIL if Keras is unavailable.
    """
    if TF_AVAILABLE:
        img = load_img(image_path, target_size=IMAGE_SIZE)
        arr = img_to_array(img) / 255.0
        return np.expand_dims(arr, 0)

    if PIL_AVAILABLE:
        img = Image.open(image_path).convert("RGB").resize(IMAGE_SIZE)
        arr = np.array(img, dtype=np.float32) / 255.0
        return np.expand_dims(arr, 0)

    print("[preprocess] Neither TensorFlow nor PIL available.")
    return None
