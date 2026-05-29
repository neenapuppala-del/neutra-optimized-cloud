from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import List, Optional, Dict
import shutil, os, uuid
from pymongo import MongoClient

from services.vision import VisionService
from services.rag_dishes import RAGDishesService
from services.rag_ingredients import RAGIngredientsService
from services.nutrition import NutritionService
from services.scoring import ScoringService
from services.suggestions import SuggestionsService

app = FastAPI(title="DietAI24 API", version="3.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

# ── MongoDB connection ──────────────────────────────────────────────────────
MONGO_URI = os.getenv("MONGO_URI", "mongodb://127.0.0.1:27017/")
try:
    mongo_client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)
    db = mongo_client["neutraAI"]
    dishes_collection = db["dishes"]
    print("[Main] Connected to MongoDB")
except Exception as e:
    print(f"[Main] Failed to connect to MongoDB: {e}")
    dishes_collection = None

# ── Service singletons ──────────────────────────────────────────────────────
vision_svc     = VisionService()
rag_dishes_svc = RAGDishesService()
rag_ingr_svc   = RAGIngredientsService()
nutrition_svc  = NutritionService()
scoring_svc    = ScoringService()
suggestions_svc = SuggestionsService()

# ── Pydantic schemas ────────────────────────────────────────────────────────
class PortionEntry(BaseModel):
    dish_name: str
    amount:    float
    unit:      str

class Modification(BaseModel):
    action:        str
    dish_name:     str
    new_item:      Optional[str] = ""
    original_item: Optional[str] = ""
    amount:        float = 0.0
    unit:          str   = "grams"

class Phase2Request(BaseModel):
    session_id:      str
    detected_dishes: List[str]
    portions:        List[PortionEntry]
    modifications:   Optional[List[Modification]] = []
    user_profile:    Optional[Dict] = {}


# ── Endpoints ───────────────────────────────────────────────────────────────
@app.post("/api/phase1/detect")
async def detect_food(files: list[UploadFile] = File(..., description="Upload one or more food images")):
    detected = []
    seen = set()
    num_files = 0
    saved_filenames = []

    for file in files:
        ext   = os.path.splitext(file.filename)[1] or ".jpg"
        fname = f"{uuid.uuid4()}{ext}"
        fpath = os.path.join(UPLOAD_DIR, fname)

        content = await file.read()
        with open(fpath, "wb") as f:
            f.write(content)

        saved_filenames.append(fname)
        num_files += 1

        # Predict the full image directly since there's no YOLO segmentation
        pred = vision_svc.predict(fpath)
        if pred is None:
            pred = {
                "name": "unknown meal",
                "confidence": 0.0,
                "source": "fallback"
            }

        name = pred["name"].lower().strip()

        # Duplicate removal across uploaded images
        if name in seen:
            print(f"[Main] Duplicate skipped: {name}")
            continue

        seen.add(name)

        detected.append({
            "name": name,
            "confidence": pred["confidence"],
            "source": pred.get("source", "custom"),
            "region_id": num_files,
            "bbox": [0, 0, 0, 0]
        })

    # Fallback if somehow no files were processed or no food was detected
    if len(detected) == 0:
        detected = [{
            "name": "unknown meal",
            "confidence": 0.0,
            "source": "fallback",
            "region_id": 0,
            "bbox": [0, 0, 0, 0]
        }]

    # RAG
    dish_names = [d["name"] for d in detected]
    nutrients = rag_dishes_svc.retrieve(dish_names)

    session_id = saved_filenames[0].split(".")[0] if saved_filenames else f"session_{uuid.uuid4()}"
    image_url = f"/uploads/{saved_filenames[0]}" if saved_filenames else ""

    return {
        "session_id": session_id,
        "detected_dishes": detected,
        "nutrients_per_100g": nutrients,
        "image_url": image_url,
        "num_segments": num_files
    }
@app.post("/api/phase2/nutrition")
async def calculate_nutrition(req: Phase2Request):
    """
    Phase 2: Portions + modifications → nutrients + health score
    """
    ingredient_nutrients = {}
    if req.modifications:
        ingr_names = set()
        for m in req.modifications:
            if m.new_item:      ingr_names.add(m.new_item)
            if m.original_item: ingr_names.add(m.original_item)
        ingredient_nutrients = rag_ingr_svc.retrieve(list(ingr_names))

    final_nutrients = nutrition_svc.calculate(
        detected_dishes      = req.detected_dishes,
        portions             = [p.dict() for p in req.portions],
        modifications        = [m.dict() for m in req.modifications] if req.modifications else [],
        dish_nutrients       = rag_dishes_svc.retrieve(req.detected_dishes),
        ingredient_nutrients = ingredient_nutrients,
    )

    health_score = scoring_svc.score(final_nutrients, req.user_profile)
    suggestions = suggestions_svc.generate(final_nutrients, req.user_profile)

    if dishes_collection is not None:
        try:
            dish_doc = {
                "dishNames": req.detected_dishes,
                "finalNutrients": final_nutrients,
                "healthScore": health_score.get("score", 0),
                "suggestions": suggestions
            }
            dishes_collection.insert_one(dish_doc)
            print("[Main] Saved dish to MongoDB")
        except Exception as e:
            print(f"[Main] Failed to save to MongoDB: {e}")

    return {
        "session_id":      req.session_id,
        "final_nutrients": final_nutrients,
        "health_score":    health_score,
        "suggestions":     suggestions,
    }


@app.get("/health")
def health():
    return {"status": "ok"}