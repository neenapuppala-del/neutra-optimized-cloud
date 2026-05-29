"""
services/rag_ingredients.py
────────────────────────────
Same hybrid retrieval as rag_dishes.py but for ingredients.csv.
Used only in Phase 2 when the user adds/replaces ingredients.
"""
import os
import pandas as pd
import numpy as np
import importlib.util
from config import INGR_CSV, EMBED_MODEL, BM25_WEIGHT

# Check if sentence-transformers is installed without importing it immediately
ST_AVAILABLE = importlib.util.find_spec("sentence_transformers") is not None

try:
    from rank_bm25 import BM25Okapi
    BM25_AVAILABLE = True
except ImportError:
    BM25_AVAILABLE = False


class RAGIngredientsService:
    def __init__(self):
        self.df: pd.DataFrame = pd.DataFrame()
        self.embeddings: np.ndarray = np.array([])
        self.bm25 = None
        self.embed_model = None
        self._load()

    def _load(self):
        try:
            self.df = pd.read_csv(INGR_CSV)
            self.df["Ingredient"] = self.df["Ingredient"].str.strip()
            corpus = self.df["Ingredient"].tolist()

            if BM25_AVAILABLE:
                self.bm25 = BM25Okapi([n.lower().split() for n in corpus])

            # ── Load cached embeddings if they exist ──────────────────────────
            npy_path = INGR_CSV.replace(".csv", "_embeddings.npy")
            if os.path.exists(npy_path):
                self.embeddings = np.load(npy_path)
                print(f"[RAGIngredients] Loaded pre-computed embeddings from {npy_path}")
            elif ST_AVAILABLE:
                print(f"[RAGIngredients] Cached embeddings not found. Computing on startup...")
                self._init_transformer()
                self.embeddings = self.embed_model.encode(
                    corpus, convert_to_numpy=True, show_progress_bar=False
                )
                np.save(npy_path, self.embeddings)
                print(f"[RAGIngredients] Pre-computed and saved embeddings to {npy_path}")

            print(f"[RAGIngredients] Loaded {len(self.df)} ingredients.")
        except FileNotFoundError:
            print(f"[RAGIngredients] {INGR_CSV} not found.")

    def _init_transformer(self):
        """
        Lazy-loads the SentenceTransformer model to keep startup RAM extremely low.
        """
        if self.embed_model is None and ST_AVAILABLE:
            from sentence_transformers import SentenceTransformer
            print(f"[RAGIngredients] Lazy-loading SentenceTransformer ({EMBED_MODEL})...")
            self.embed_model = SentenceTransformer(EMBED_MODEL)

    def _hybrid_scores(self, query: str) -> np.ndarray:
        n = len(self.df)
        bm25_scores = vector_scores = np.zeros(n)

        if self.bm25:
            raw = np.array(self.bm25.get_scores(query.lower().split()))
            bm25_scores = raw / (raw.max() or 1)

        # Initialize model on-demand if embeddings are loaded/available
        if ST_AVAILABLE and len(self.embeddings):
            self._init_transformer()
            if self.embed_model is not None:
                q_emb  = self.embed_model.encode([query], convert_to_numpy=True)
                norms  = np.linalg.norm(self.embeddings, axis=1, keepdims=True)
                q_norm = np.linalg.norm(q_emb)
                vector_scores = (self.embeddings @ q_emb.T).flatten() / (norms.flatten() * q_norm + 1e-9)

        return BM25_WEIGHT * bm25_scores + (1 - BM25_WEIGHT) * vector_scores

    def _best_match(self, query: str) -> dict | None:
        if self.df.empty:
            return None
        scores   = self._hybrid_scores(query)
        best_idx = int(scores.argmax())
        row      = self.df.iloc[best_idx]
        return {
            "matched_name": row["Ingredient"],
            "score":        float(scores[best_idx]),
            "nutrients_per_unit": row.drop("Ingredient").to_dict(),
            # keeps Unit & Quantity from CSV for normalisation
        }

    def retrieve(self, ingredient_names: list[str]) -> dict[str, dict]:
        """
        {
          "Ghee": {
              "matched_name": "Ghee",
              "score": 0.99,
              "nutrients_per_unit": {"Calories (kcal)": 112, "Unit": "tbsp", "Quantity": 1, ...}
          }
        }
        """
        return {name: (self._best_match(name) or {}) for name in ingredient_names}
