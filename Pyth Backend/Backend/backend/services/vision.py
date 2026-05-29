import os
import base64
import requests

GENERIC_CATEGORIES = [
    "rice dish", "spiced rice", "fried rice",
    "fried snack", "crispy snack",
    "beverage", "cold drink", "milk based drink",
    "dessert", "sweet food",
    "curry", "vegetable dish", "salad",
    "fast food", "pasta dish", "noodles",
    "food"
]


class VisionService:
    def __init__(self):
        self.hf_api_enabled = True
        print("[VisionService] Using HuggingFace fallback-only mode")

    def _call_hf_api(self, model_id: str, data: bytes, is_zero_shot: bool = False) -> list:
        if not self.hf_api_enabled:
            return []

        api_url = f"https://router.huggingface.co/hf-inference/models/{model_id}"
        token = os.getenv("HF_TOKEN")

        headers = {"X-Wait-For-Model": "true"}

        if token and token.strip() and not token.startswith("your_"):
            headers["Authorization"] = f"Bearer {token}"

        try:
            if is_zero_shot:
                encoded_image = base64.b64encode(data).decode("utf-8")
                payload = {
                    "inputs": encoded_image,
                    "parameters": {"candidate_labels": GENERIC_CATEGORIES}
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

    def predict(self, image_path: str):
        print("[VisionService] Using HuggingFace food classifier")

        try:
            with open(image_path, "rb") as f:
                image_bytes = f.read()
        except Exception as e:
            print(f"[VisionService] Failed to read image: {e}")
            return None

        hf_res = self._call_hf_api("nateraw/food", image_bytes)

        if hf_res and isinstance(hf_res, list) and len(hf_res) > 0 and "score" in hf_res[0]:
            return {
                "name": hf_res[0]["label"].lower().strip(),
                "confidence": round(float(hf_res[0]["score"]) * 100, 2),
                "source": "food101"
            }

        print("[VisionService] Food classifier failed, trying CLIP general fallback")
        clip_res = self._call_hf_api("openai/clip-vit-base-patch32", image_bytes, is_zero_shot=True)

        if clip_res and isinstance(clip_res, list) and len(clip_res) > 0 and "score" in clip_res[0]:
            return {
                "name": clip_res[0]["label"].lower().strip(),
                "confidence": round(float(clip_res[0]["score"]) * 100, 2),
                "source": "general_categorization"
            }

        return {
            "name": "unknown meal",
            "confidence": 0.0,
            "source": "fallback"
        }