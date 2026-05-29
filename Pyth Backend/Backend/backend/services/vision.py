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

# Universal TFLite importer
# Render/Linux may use tflite_runtime.
# If unavailable, TensorFlow CPU can still provide tensorflow.lite.Interpreter.

try:
    import tensorflow.lite as tflite
    TFLITE_AVAILABLE = True
    print("[VisionService] Loaded tensorflow.lite successfully.")
except Exception as e:
    print(f"[VisionService] tensorflow.lite unavailable: {e}")
    TFLITE_AVAILABLE = False

GENERIC_CATEGORIES = [
    "rice dish",
    "spiced rice",
    "fried rice",
    "fried snack",
    "crispy snack",
    "beverage",
    "cold drink",
    "milk based drink",
    "dessert",
    "sweet food",
    "curry",
    "vegetable dish",
    "salad",
    "fast food",
    "pasta dish",
    "noodles",
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

        try:
            self.interpreter = tflite.Interpreter(model_path=VISION_MODEL)
            self.interpreter.allocate_tensors()
            self.input_details = self.interpreter.get_input_details()
            self.output_details = self.interpreter.get_output_details()
            print(f"[VisionService] Successfully loaded TFLite model from {VISION_MODEL}")
        except Exception as e:
            print(f"[VisionService] Failed to load TFLite model: {e}")
            self.interpreter = None
            return

        try:
            with open(CLASS_INDICES, "r", encoding="utf-8") as f:
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
            self.class_names = []

    def _call_hf_api(self, model_id: str, data: bytes, is_zero_shot: bool = False) -> list:
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
                encoded_image = base64.b64encode(data).decode("utf-8")
                payload = {
                    "inputs": encoded_image,
                    "parameters": {
                        "candidate_labels": GENERIC_CATEGORIES
                    }
                }
                response = requests.post(api_url, headers=headers, json=payload, timeout=25)
            else:
                headers["Content-Type"] = "image/jpeg"
                response = requests.post(api_url, headers=headers, data=data, timeout=25)

            if response.status_code == 200:
                return response.json()

            print(f"[VisionService API] HF API error ({response.status_code}): {response.text}")
            return []

        except Exception as e:
            print(f"[VisionService API] HF API connection failed: {e}")
            self.hf_api_enabled = False
            return []

    def _prepare_image(self, image_path: str):
        img = Image.open(image_path).convert("RGB").resize(IMAGE_SIZE)
        arr = np.array(img)

        input_type = self.input_details[0]["dtype"]

        if input_type == np.float32:
            arr = arr.astype(np.float32)
        elif input_type == np.uint8:
            arr = arr.astype(np.uint8)
        elif input_type == np.int8:
            arr = (arr.astype(np.float32) - 128).astype(np.int8)
        else:
            arr = arr.astype(input_type)

        arr = np.expand_dims(arr, axis=0)
        return arr

    def predict(self, image_path: str):
        if self.interpreter is None:
    print("[VisionService] Interpreter unavailable, using HuggingFace fallback directly")
    with open(image_path, "rb") as f:
        image_bytes = f.read()

    hf_res = self._call_hf_api("nateraw/food", image_bytes)

    if hf_res and isinstance(hf_res, list) and len(hf_res) > 0 and "score" in hf_res[0]:
        return {
            "name": hf_res[0]["label"].lower().strip(),
            "confidence": round(float(hf_res[0]["score"]) * 100, 2),
            "source": "food101"
        }

    return None

        if not self.class_names:
            print("[VisionService] Class names unavailable")
            return None

        try:
            arr = self._prepare_image(image_path)
        except Exception as e:
            print(f"[VisionService] Image preprocessing failed: {e}")
            return None

        try:
            self.interpreter.set_tensor(self.input_details[0]["index"], arr)
            self.interpreter.invoke()
            preds = self.interpreter.get_tensor(self.output_details[0]["index"])[0]

            best_idx = int(np.argmax(preds))

            if best_idx >= len(self.class_names):
                print(f"[VisionService] Prediction index {best_idx} outside class list")
                return None

            confidence = float(preds[best_idx]) * 100
            name = self.class_names[best_idx].lower().strip()

            print(f"[VisionService] Primary TFLite: {name} ({confidence:.2f}%)")

        except Exception as e:
            print(f"[VisionService] TFLite execution failed: {e}")
            return None

        custom_result = {
            "name": name,
            "confidence": round(confidence, 2),
            "source": "custom"
        }

        if confidence > 50:
            return custom_result

        print("[VisionService] Low confidence (<= 50%), attempting HuggingFace fallback API...")

        try:
            with open(image_path, "rb") as f:
                image_bytes = f.read()
        except Exception as e:
            print(f"[VisionService] Failed to read image bytes for API fallback: {e}")
            return custom_result

        hf_res = self._call_hf_api("nateraw/food", image_bytes)

        if hf_res and isinstance(hf_res, list) and len(hf_res) > 0 and "score" in hf_res[0]:
            print(f"[VisionService] Fallback HF API response: {hf_res[:3]}")
            food101_confidence = round(float(hf_res[0]["score"]) * 100, 2)
            food101_name = hf_res[0]["label"].lower().strip()

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

        if winner["source"] == "custom" and winner["confidence"] <= 15:
            print("[VisionService] Winner is low-confidence custom model, applying CLIP general categorization API...")
            clip_res = self._call_hf_api("openai/clip-vit-base-patch32", image_bytes, is_zero_shot=True)

            if clip_res and isinstance(clip_res, list) and len(clip_res) > 0 and "score" in clip_res[0]:
                print(f"[VisionService] CLIP API response: {clip_res[:3]}")
                return {
                    "name": clip_res[0]["label"].lower().strip(),
                    "confidence": round(float(clip_res[0]["score"]) * 100, 2),
                    "source": "general_categorization"
                }

        if winner["confidence"] <= 15:
            print("[VisionService] Confidence too low and fallback failed — returning unknown")
            return {
                "name": "unknown",
                "confidence": 0,
                "source": "none"
            }

        return winner