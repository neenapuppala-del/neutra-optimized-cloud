import json
import os
import numpy as np
from PIL import Image
import tensorflow.lite as tflite

from config import (
    VISION_MODEL,
    CLASS_INDICES,
    IMAGE_SIZE
)


class VisionService:
    def __init__(self):
        self.interpreter = None
        self.class_names = []
        self.input_details = None
        self.output_details = None
        self._load()

    def _load(self):
        try:
            self.interpreter = tflite.Interpreter(
                model_path=VISION_MODEL
            )

            self.interpreter.allocate_tensors()

            self.input_details = self.interpreter.get_input_details()
            self.output_details = self.interpreter.get_output_details()

            print("[VisionService] Model loaded successfully")

        except Exception as e:
            print(f"[VisionService] Model load failed: {e}")
            self.interpreter = None
            return

        try:
            with open(CLASS_INDICES, "r") as f:
                raw = json.load(f)

            idx2class = {}

            for k, v in raw.items():
                if isinstance(k, str) and k.isdigit():
                    idx2class[int(k)] = v
                elif isinstance(v, int):
                    idx2class[v] = k

            self.class_names = [
                idx2class[i]
                for i in sorted(idx2class.keys())
            ]

            print(f"[VisionService] Loaded {len(self.class_names)} classes")

        except Exception as e:
            print(f"[VisionService] Failed class loading: {e}")

    def predict(self, image_path):

        if self.interpreter is None:
            print("[VisionService] Interpreter unavailable")
            return None

        try:
            img = Image.open(image_path)
            img = img.convert("RGB")
            img = img.resize(IMAGE_SIZE)

            arr = np.array(img)

            dtype = self.input_details[0]["dtype"]

            if dtype == np.float32:
                arr = arr.astype(np.float32)
            elif dtype == np.uint8:
                arr = arr.astype(np.uint8)

            arr = np.expand_dims(arr, axis=0)

            self.interpreter.set_tensor(
                self.input_details[0]["index"],
                arr
            )

            self.interpreter.invoke()

            preds = self.interpreter.get_tensor(
                self.output_details[0]["index"]
            )[0]

            idx = int(np.argmax(preds))

            return {
                "name": self.class_names[idx].lower(),
                "confidence": round(float(preds[idx]) * 100, 2),
                "source": "custom"
            }

        except Exception as e:
            print(f"[VisionService] Prediction failed: {e}")
            return None