'''
import json
import os
import base64
import numpy as np
import requests
from PIL import Image

from config import (
    VISION_MODEL,
    CLASS_INDICES,
    IMAGE_SIZE
)

# ── Import TFLite lightweight runtime ─────────────────────────────────────────
try:
    import tflite_runtime.interpreter as tflite
    TFLITE_AVAILABLE = True
except ImportError:
    TFLITE_AVAILABLE = False


GENERIC_CATEGORIES = [
    # rice related
    "rice dish",
    "spiced rice",
    "fried rice",

    # snacks
    "fried snack",
    "crispy snack",

    # drinks
    "beverage",
    "cold drink",
    "milk based drink",

    # sweets
    "dessert",
    "sweet food",

    # meals
    "curry",
    "vegetable dish",
    "salad",

    # international style
    "fast food",
    "pasta dish",
    "noodles",

    # safety
    "food"
]


class VisionService:
    def __init__(self):
        self.interpreter = None
        self.class_names = []
        self.input_details = None
        self.output_details = None

        self._load()

    def _load(self):
        if not TFLITE_AVAILABLE:
            print("[VisionService] Warning: tflite_runtime not installed.")
            return

        if not os.path.exists(VISION_MODEL):
            print(f"[VisionService] Error: Missing TFLite model at {VISION_MODEL}")
            return

        if not os.path.exists(CLASS_INDICES):
            print(f"[VisionService] Error: Missing class indices at {CLASS_INDICES}")
            return

        # Load the TFLite model and allocate tensors
        try:
            self.interpreter = tflite.Interpreter(model_path=VISION_MODEL)
            self.interpreter.allocate_tensors()
            self.input_details = self.interpreter.get_input_details()
            self.output_details = self.interpreter.get_output_details()
            print(f"[VisionService] Successfully loaded TFLite model from {VISION_MODEL}")
        except Exception as e:
            print(f"[VisionService] Failed to load TFLite model: {e}")
            return

        # Load class indices
        try:
            with open(CLASS_INDICES) as f:
                raw = json.load(f)

            idx2class = {}
            for k, v in raw.items():
                if isinstance(k, str) and k.isdigit():
                    idx2class[int(k)] = v
                elif isinstance(v, int):
                    idx2class[v] = k
                else:
                    idx2class[len(idx2class)] = v

            self.class_names = [idx2class[i] for i in sorted(idx2class.keys())]
            print(f"[VisionService] Loaded {len(self.class_names)} classes.")
        except Exception as e:
            print(f"[VisionService] Failed to parse class indices: {e}")

    def _call_hf_api(self, model_id: str, data: bytes, is_zero_shot: bool = False) -> list:
        """
        Calls Hugging Face Serverless Inference API as a lightweight fallback.
        """
        api_url = f"https://api-inference.huggingface.co/models/{model_id}"
        token = os.getenv("HF_TOKEN")
        
        headers = {}
        if token:
            headers["Authorization"] = f"Bearer {token}"

        try:
            if is_zero_shot:
                # Zero-shot image classification (CLIP) expects base64 inputs
                encoded_image = base64.b64encode(data).decode("utf-8")
                payload = {
                    "inputs": encoded_image,
                    "parameters": {"candidate_labels": GENERIC_CATEGORIES}
                }
                response = requests.post(api_url, headers=headers, json=payload, timeout=8)
            else:
                # Regular image classification
                response = requests.post(api_url, headers=headers, data=data, timeout=8)

            if response.status_code == 200:
                return response.json()
            else:
                print(f"[VisionService API] HF API error ({response.status_code}): {response.text}")
                return []
        except Exception as e:
            print(f"[VisionService API] HF API connection failed: {e}")
            return []

    def predict(self, image_path: str):
        if self.interpreter is None:
            print("[VisionService] Interpreter unavailable")
            return None

        # ── Preprocess image using Pillow and NumPy ───────────────────────────
        try:
            img = Image.open(image_path).resize(IMAGE_SIZE)
            arr = np.array(img, dtype=np.float32)

            # Ensure 3-channel RGB format
            if len(arr.shape) == 2:  # Grayscale
                arr = np.stack([arr] * 3, axis=-1)
            elif arr.shape[2] == 4:  # RGBA
                arr = arr[:, :, :3]

            arr = np.expand_dims(arr, 0)
        except Exception as e:
            print(f"[VisionService] Image preprocessing failed: {e}")
            return None

        # ── Run custom quantized TFLite model prediction ──────────────────────
        try:
            self.interpreter.set_tensor(self.input_details[0]['index'], arr)
            self.interpreter.invoke()
            preds = self.interpreter.get_tensor(self.output_details[0]['index'])[0]

            best_idx = int(np.argmax(preds))
            confidence = float(preds[best_idx]) * 100
            name = self.class_names[best_idx].lower().strip()

            print(f"[VisionService] Primary TFLite: {name} ({confidence:.2f}%)")
        except Exception as e:
            print(f"[VisionService] TFLite execution failed: {e}")
            return None

        # Custom model confident enough — return directly
        if confidence > 50:
            return {
                "name": name,
                "confidence": round(confidence, 2),
                "source": "custom"
            }

        print("[VisionService] Low confidence (<= 50%), attempting HuggingFace fallback API...")

        # Save custom result for comparison later
        custom_result = {
            "name": name,
            "confidence": round(confidence, 2),
            "source": "custom"
        }

        # Read original image bytes for the HF API requests
        try:
            with open(image_path, "rb") as f:
                image_bytes = f.read()
        except Exception as e:
            print(f"[VisionService] Failed to read image bytes for API fallback: {e}")
            return custom_result

        # Step 1: Call nateraw/food classifier fallback
        hf_res = self._call_hf_api("nateraw/food", image_bytes)

        if hf_res and isinstance(hf_res, list) and len(hf_res) > 0 and "score" in hf_res[0]:
            print(f"[VisionService] Fallback HF API response: {hf_res[:3]}")
            food101_confidence = round(hf_res[0]["score"] * 100, 2)
            food101_name = hf_res[0]["label"].lower().strip()

            # Pick the better prediction
            if food101_confidence >= custom_result["confidence"]:
                winner = {
                    "name": food101_name,
                    "confidence": food101_confidence,
                    "source": "food101"
                }
            else:
                winner = custom_result
        else:
            winner = custom_result

        print(f"[VisionService] Current Winner: {winner['name']} ({winner['confidence']:.2f}%) via {winner['source']}")

        # Step 2: Generalize only if winner is custom model and confidence is very low (<= 15)
        if winner["source"] == "custom" and winner["confidence"] <= 15:
            print("[VisionService] Winner is low-confidence custom model, applying CLIP general categorization API...")
            clip_res = self._call_hf_api("openai/clip-vit-base-patch32", image_bytes, is_zero_shot=True)
            
            if clip_res and isinstance(clip_res, list) and len(clip_res) > 0 and "score" in clip_res[0]:
                print(f"[VisionService] CLIP API response: {clip_res[:3]}")
                return {
                    "name": clip_res[0]["label"].lower().strip(),
                    "confidence": round(clip_res[0]["score"] * 100, 2),
                    "source": "general_categorization"
                }

        # Fallback to unknown if confidence is extremely low and no API results were obtained
        if winner["confidence"] <= 15:
            print("[VisionService] Confidence too low and fallback failed — returning unknown")
            return {
                "name": "unknown",
                "confidence": 0,
                "source": "none"
            }

        return winner '''
import json
import os
import base64
import numpy as np
import requests
from PIL import Image

from config import (
    VISION_MODEL,
    CLASS_INDICES,
    IMAGE_SIZE
)

# ── Universal Multi-Environment TFLite Importer ───────────────────────────────
try:
    # 1. Production (Linux/Render): Use the ultra-lightweight runtime
    import tflite_runtime.interpreter as tflite
    TFLITE_AVAILABLE = True
    print("[VisionService] Loaded production tflite_runtime successfully.")
except ImportError:
    try:
        # 2. Local Dev (Windows with full TensorFlow installed)
        import tensorflow.lite as tflite
        TFLITE_AVAILABLE = True
        print("[VisionService] Loaded local dev tensorflow.lite successfully.")
    except ImportError:
        try:
            # 3. Local Dev (Windows with lightweight LiteRT installed)
            import ai_edge_litert.interpreter as tflite
            TFLITE_AVAILABLE = True
            print("[VisionService] Loaded local dev ai_edge_litert successfully.")
        except ImportError:
            TFLITE_AVAILABLE = False
            print("[VisionService] WARNING: No TFLite runtime found.")


GENERIC_CATEGORIES = [
    # rice related
    "rice dish",
    "spiced rice",
    "fried rice",

    # snacks
    "fried snack",
    "crispy snack",

    # drinks
    "beverage",
    "cold drink",
    "milk based drink",

    # sweets
    "dessert",
    "sweet food",

    # meals
    "curry",
    "vegetable dish",
    "salad",

    # international style
    "fast food",
    "pasta dish",
    "noodles",

    # safety
    "food"
]


class VisionService:
    def __init__(self):
        self.interpreter = None
        self.class_names = []
        self.input_details = None
        self.output_details = None
        self.hf_api_enabled = True

        self._load()

    def _load(self):
        if not TFLITE_AVAILABLE:
            print("[VisionService] Warning: No TFLite interpreter libraries are installed.")
            return

        if not os.path.exists(VISION_MODEL):
            print(f"[VisionService] Error: Missing TFLite model at {VISION_MODEL}")
            return

        if not os.path.exists(CLASS_INDICES):
            print(f"[VisionService] Error: Missing class indices at {CLASS_INDICES}")
            return

        # Load the TFLite model and allocate tensors
        try:
            self.interpreter = tflite.Interpreter(model_path=VISION_MODEL)
            self.interpreter.allocate_tensors()
            self.input_details = self.interpreter.get_input_details()
            self.output_details = self.interpreter.get_output_details()
            print(f"[VisionService] Successfully loaded TFLite model from {VISION_MODEL}")
        except Exception as e:
            print(f"[VisionService] Failed to load TFLite model: {e}")
            return

        # Load class indices
        try:
            with open(CLASS_INDICES) as f:
                raw = json.load(f)

            idx2class = {}
            for k, v in raw.items():
                if isinstance(k, str) and k.isdigit():
                    idx2class[int(k)] = v
                elif isinstance(v, int):
                    idx2class[v] = k
                else:
                    idx2class[len(idx2class)] = v

            self.class_names = [idx2class[i] for i in sorted(idx2class.keys())]
            print(f"[VisionService] Loaded {len(self.class_names)} classes.")
        except Exception as e:
            print(f"[VisionService] Failed to parse class indices: {e}")

    def _call_hf_api(self, model_id: str, data: bytes, is_zero_shot: bool = False) -> list:
        """
        Calls Hugging Face Serverless Inference API as a lightweight fallback.
        """
        if not self.hf_api_enabled:
            return []

        api_url = f"https://router.huggingface.co/hf-inference/models/{model_id}"
        token = os.getenv("HF_TOKEN")
        
        headers = {
            "X-Wait-For-Model": "true"
        }
        if token and token.strip() and not token.startswith("your_"):
            headers["Authorization"] = f"Bearer {token}"

        try:
            if is_zero_shot:
                # Zero-shot image classification (CLIP) expects base64 inputs
                encoded_image = base64.b64encode(data).decode("utf-8")
                payload = {
                    "inputs": encoded_image,
                    "parameters": {"candidate_labels": GENERIC_CATEGORIES}
                }
                response = requests.post(api_url, headers=headers, json=payload, timeout=25)
            else:
                # Regular image classification - HuggingFace router requires a Content-Type for binary payloads
                headers["Content-Type"] = "image/jpeg"
                response = requests.post(api_url, headers=headers, data=data, timeout=25)

            if response.status_code == 200:
                return response.json()
            else:
                print(f"[VisionService API] HF API error ({response.status_code}): {response.text}")
                return []
        except Exception as e:
            print(f"[VisionService API] HF API connection failed: {e}. Disabling fallback API circuit breaker.")
            self.hf_api_enabled = False
            return []

    def predict(self, image_path: str):
        if self.interpreter is None:
            print("[VisionService] Interpreter unavailable")
            return None

        # ── Preprocess image using Pillow and NumPy ───────────────────────────
        try:
            img = Image.open(image_path).resize(IMAGE_SIZE)
            arr = np.array(img, dtype=np.float32)

            # Ensure 3-channel RGB format
            if len(arr.shape) == 2:  # Grayscale
                arr = np.stack([arr] * 3, axis=-1)
            elif arr.shape[2] == 4:  # RGBA
                arr = arr[:, :, :3]

            arr = np.expand_dims(arr, 0)
            
            # ── Dynamic Input Dtype Handling (Quantized vs Float) ───────────────────
            input_type = self.input_details[0]['dtype']
            if input_type == np.uint8:
                arr = arr.astype(np.uint8)
            elif input_type == np.int8:
                # If int8 quantized, scale inputs to [-128, 127]
                arr = (arr - 128).astype(np.int8)
            else:
                arr = arr.astype(np.float32)

        except Exception as e:
            print(f"[VisionService] Image preprocessing failed: {e}")
            return None

        # ── Run custom quantized TFLite model prediction ──────────────────────
        try:
            self.interpreter.set_tensor(self.input_details[0]['index'], arr)
            self.interpreter.invoke()
            preds = self.interpreter.get_tensor(self.output_details[0]['index'])[0]

            best_idx = int(np.argmax(preds))
            confidence = float(preds[best_idx]) * 100
            name = self.class_names[best_idx].lower().strip()

            print(f"[VisionService] Primary TFLite: {name} ({confidence:.2f}%)")
        except Exception as e:
            print(f"[VisionService] TFLite execution failed: {e}")
            return None

        # Custom model confident enough — return directly
        if confidence > 50:
            return {
                "name": name,
                "confidence": round(confidence, 2),
                "source": "custom"
            }

        print("[VisionService] Low confidence (<= 50%), attempting HuggingFace fallback API...")

        # Save custom result for comparison later
        custom_result = {
            "name": name,
            "confidence": round(confidence, 2),
            "source": "custom"
        }

        # Read original image bytes for the HF API requests
        try:
            with open(image_path, "rb") as f:
                image_bytes = f.read()
        except Exception as e:
            print(f"[VisionService] Failed to read image bytes for API fallback: {e}")
            return custom_result

        # Step 1: Call nateraw/food classifier fallback
        hf_res = self._call_hf_api("nateraw/food", image_bytes)

        if hf_res and isinstance(hf_res, list) and len(hf_res) > 0 and "score" in hf_res[0]:
            print(f"[VisionService] Fallback HF API response: {hf_res[:3]}")
            food101_confidence = round(hf_res[0]["score"] * 100, 2)
            food101_name = hf_res[0]["label"].lower().strip()

            # Pick the better prediction
            if food101_confidence >= custom_result["confidence"]:
                winner = {
                    "name": food101_name,
                    "confidence": food101_confidence,
                    "source": "food101"
                }
            else:
                winner = custom_result
        else:
            winner = custom_result

        print(f"[VisionService] Current Winner: {winner['name']} ({winner['confidence']:.2f}%) via {winner['source']}")

        # Step 2: Generalize only if winner is custom model and confidence is very low (<= 15)
        if winner["source"] == "custom" and winner["confidence"] <= 15:
            print("[VisionService] Winner is low-confidence custom model, applying CLIP general categorization API...")
            clip_res = self._call_hf_api("openai/clip-vit-base-patch32", image_bytes, is_zero_shot=True)
            
            if clip_res and isinstance(clip_res, list) and len(clip_res) > 0 and "score" in clip_res[0]:
                print(f"[VisionService] CLIP API response: {clip_res[:3]}")
                return {
                    "name": clip_res[0]["label"].lower().strip(),
                    "confidence": round(clip_res[0]["score"] * 100, 2),
                    "source": "general_categorization"
                }

        # Fallback to unknown if confidence is extremely low and no API results were obtained
        if winner["confidence"] <= 15:
            print("[VisionService] Confidence too low and fallback failed — returning unknown")
            return {
                "name": "unknown",
                "confidence": 0,
                "source": "none"
            }

        return winner