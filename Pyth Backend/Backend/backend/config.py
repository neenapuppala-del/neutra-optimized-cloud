import os

# ── Manual .env Loader (Zero external dependencies) ───────────────────────────
def _load_dotenv():
    base_dir = os.path.dirname(__file__)
    possible_paths = [
        os.path.join(os.path.dirname(base_dir), ".env"), # Pyth Backend/Backend/.env
        os.path.join(base_dir, ".env"),                  # Pyth Backend/Backend/backend/.env
        os.path.abspath(".env")                          # Current working directory
    ]
    for env_path in possible_paths:
        if os.path.exists(env_path):
            print(f"[Config] Loading environment from: {env_path}")
            try:
                with open(env_path, "r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if not line or line.startswith("#"):
                            continue
                        parts = line.split("=", 1)
                        if len(parts) == 2:
                            key = parts[0].strip()
                            val = parts[1].strip()
                            # Strip surrounding quotes if present
                            if (val.startswith('"') and val.endswith('"')) or (val.startswith("'") and val.endswith("'")):
                                val = val[1:-1]
                            os.environ[key] = val
                break
            except Exception as e:
                print(f"[Config] Warning: Failed to parse {env_path}: {e}")

_load_dotenv()

# ── Paths ────────────────────────────────────────────────────────────────────
BASE_DIR      = os.path.dirname(__file__)
DATA_DIR      = os.path.join(BASE_DIR, "data")
MODELS_DIR    = os.path.join(BASE_DIR, "models")

DISHES_CSV    = os.path.join(DATA_DIR, "dishes.csv")
INGR_CSV      = os.path.join(DATA_DIR, "ingredients.csv")
VISION_MODEL  = os.path.join(MODELS_DIR, "food_model_final.tflite")
CLASS_INDICES = os.path.join(MODELS_DIR, "class_indices.json")

# ── Vision CNN ───────────────────────────────────────────────────────────────
IMAGE_SIZE = (224, 224)

# ── RAG / Embeddings ─────────────────────────────────────────────────────────
EMBED_MODEL = "all-MiniLM-L6-v2"
BM25_WEIGHT = 0.4

# ── Nutrition ────────────────────────────────────────────────────────────────
UNIT_TO_GRAMS = {
    "grams":  1.0,
    "g":      1.0,
    "ml":     1.0,
    "bowls":  250.0,
    "serves": 150.0,
    "cup":    240.0,
    "tbsp":   15.0,
    "tsp":    5.0,
}

# ── Health scoring ───────────────────────────────────────────────────────────
DAILY_REFERENCE = {
    "Calories (kcal)":   2000,
    "Carbohydrates (g)": 275,
    "Protein (g)":       65,
    "Fats (g)":          78,
    "Free Sugar (g)":    25,
    "Fibre (g)":         28,
    "Sodium (mg)":       2300,
    "Calcium (mg)":      1000,
    "Iron (mg)":         18,
    "Vitamin C (mg)":    90,
    "Folate (µg)":       400,
}