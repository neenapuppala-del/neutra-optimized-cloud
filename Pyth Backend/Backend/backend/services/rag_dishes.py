"""
services/rag_dishes.py
───────────────────────
Hybrid RAG (BM25 + sentence-transformer vectors) over dishes.csv.

Why hybrid?
  • BM25 handles exact keyword matches ("aloo biryani" → "aloo biryani")
  • Vector embeddings handle semantic similarity ("potato rice" → "aloo biryani")
  Weighted combination gives us the best of both worlds.
"""
import os
import pandas as pd
import numpy as np
import importlib.util
from config import DISHES_CSV, EMBED_MODEL, BM25_WEIGHT

# Check if sentence-transformers is installed without importing the model yet
ST_AVAILABLE = importlib.util.find_spec("sentence_transformers") is not None

try:
    from rank_bm25 import BM25Okapi
    BM25_AVAILABLE = True
except ImportError:
    BM25_AVAILABLE = False


class RAGDishesService:
    def __init__(self):
        self.df: pd.DataFrame = pd.DataFrame()
        self.embeddings: np.ndarray = np.array([])
        self.bm25 = None
        self.embed_model = None
        self._load()

    # ── setup ────────────────────────────────────────────────────────────────
    def _load(self):
        try:
            self.df = pd.read_csv(DISHES_CSV)
            self.df["Dish Name"] = self.df["Dish Name"].str.strip()
            corpus = self.df["Dish Name"].tolist()

            if BM25_AVAILABLE:
                tokenised = [name.lower().split() for name in corpus]
                self.bm25 = BM25Okapi(tokenised)

            # ── Load cached embeddings if they exist ──────────────────────────
            npy_path = DISHES_CSV.replace(".csv", "_embeddings.npy")
            if os.path.exists(npy_path):
                self.embeddings = np.load(npy_path)
                print(f"[RAGDishes] Loaded pre-computed embeddings from {npy_path}")
            elif ST_AVAILABLE:
                print(f"[RAGDishes] Cached embeddings not found. Computing on startup...")
                self._init_transformer()
                self.embeddings = self.embed_model.encode(
                    corpus, convert_to_numpy=True, show_progress_bar=False
                )
                np.save(npy_path, self.embeddings)
                print(f"[RAGDishes] Pre-computed and saved embeddings to {npy_path}")

            print(f"[RAGDishes] Loaded {len(self.df)} dishes.")
        except FileNotFoundError:
            print(f"[RAGDishes] {DISHES_CSV} not found – returning empty nutrition.")

    def _init_transformer(self):
        """
        Lazy-loads the SentenceTransformer model to keep startup RAM extremely low.
        """
        if self.embed_model is None and ST_AVAILABLE:
            from sentence_transformers import SentenceTransformer
            print(f"[RAGDishes] Lazy-loading SentenceTransformer ({EMBED_MODEL})...")
            self.embed_model = SentenceTransformer(EMBED_MODEL)

    # ── normalization ─────────────────────────────────────────────────────────
    def _normalize_query(self, query: str) -> str:
        """
        Normalize CNN class name to natural dish name format.
        "chicken_biryani" → "chicken biryani"
        "Aloo_Gobi"       → "aloo gobi"
        "dal-makhani"     → "dal makhani"
        """
        import re
        q = query.replace("_", " ").replace("-", " ").lower().strip()
        q = re.sub(r'\s+', ' ', q)
        if q.endswith('s') and not q.endswith('ss') and len(q) > 4:
            q = q[:-1]
        return q

    # ── scoring ──────────────────────────────────────────────────────────────
    def _bm25_scores(self, query: str) -> tuple[np.ndarray, float]:
        n = len(self.df)
        if not self.bm25:
            return np.zeros(n), 0.0
        raw = np.array(self.bm25.get_scores(query.lower().split()))
        denom = raw.max() if raw.max() > 0 else 1
        return raw / denom, raw.max()

    def _hybrid_scores(self, query: str, bm25_scores: np.ndarray) -> np.ndarray:
        n = len(self.df)
        vector_scores = np.zeros(n)

        # Initialize model on-demand if embeddings are loaded/available
        if ST_AVAILABLE and len(self.embeddings):
            self._init_transformer()
            if self.embed_model is not None:
                q_emb = self.embed_model.encode([query], convert_to_numpy=True)
                norms = np.linalg.norm(self.embeddings, axis=1, keepdims=True)
                q_norm = np.linalg.norm(q_emb)
                vector_scores = (self.embeddings @ q_emb.T).flatten() / (norms.flatten() * q_norm + 1e-9)

        return BM25_WEIGHT * bm25_scores + (1 - BM25_WEIGHT) * vector_scores

    def _best_match(self, query: str) -> dict | None:
        if self.df.empty:
            return None

        # Normalize: "chicken_biryani" → "chicken biryani"
        query = self._normalize_query(query)
        print(f"[RAGDishes] Normalized query: '{query}'")

        # EXACT MATCH BYPASS
        exact_matches = self.df[self.df["Dish Name"].str.lower() == query]
        if not exact_matches.empty:
            print("[RAGDishes] Exact match found! Bypassing vector/BM25 search.")
            best_idx = int(exact_matches.index[0])
            scores = np.zeros(len(self.df))
            scores[best_idx] = 100.0
        else:
            bm25_normalized, max_raw_bm25 = self._bm25_scores(query)

            if self.bm25 and max_raw_bm25 >= 5.0:
                print(f"[RAGDishes] Very high BM25 confidence ({max_raw_bm25:.2f}) → using BM25 directly")
                scores = bm25_normalized
            else:
                print(f"[RAGDishes] BM25 score ({max_raw_bm25:.2f}) → using Hybrid search")
                scores = self._hybrid_scores(query, bm25_normalized)

        best_idx = int(scores.argmax())
        row = self.df.iloc[best_idx]

        nutr_dict = row.drop("Dish Name").to_dict()
        clean_nutr = {}
        for k, v in nutr_dict.items():
            if pd.isna(v):
                clean_nutr[k] = 0.0
            else:
                try:
                    clean_nutr[k] = float(v)
                except:
                    clean_nutr[k] = str(v)
        print(str(row["Dish Name"]))
        return {
            "matched_name": str(row["Dish Name"]),
            "score":        float(scores[best_idx]),
            "nutrients":    clean_nutr,
        }

    # ── public API ───────────────────────────────────────────────────────────
    def retrieve(self, dish_names: list[str]) -> dict[str, dict]:
        results = {}
        for name in dish_names:
            match = self._best_match(name)
            results[name] = match if match else {}
        return results