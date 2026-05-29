"""
services/nutrition.py
──────────────────────
Calculates absolute nutrients for the full meal.

Modification actions:
  "add"     → add ingredient nutrients on top of dish base
  "replace" → subtract original ingredient, add new ingredient
  "remove"  → subtract ingredient nutrients from dish base
"""
from config import UNIT_TO_GRAMS, DAILY_REFERENCE

NUTRIENT_COLS = list(DAILY_REFERENCE.keys())


# ── helpers ──────────────────────────────────────────────────────────────────
def _to_grams(amount: float, unit: str) -> float:
    u = unit.lower().strip()
    if u in ["g", "gram", "grams"]:
        return amount
    elif u in ["kg", "kilogram", "kilograms"]:
        return amount * 1000
    elif u in ["oz", "ounce", "ounces"]:
        return amount * 28.3495
    elif u in ["lb", "lbs", "pound", "pounds"]:
        return amount * 453.592
    elif u in ["ml", "milliliter", "milliliters", "cc"]:
        return amount  # roughly 1g per ml for water-based
    elif u in ["l", "liter", "liters"]:
        return amount * 1000
    elif u in ["cup", "cups"]:
        return amount * 240 # average cup size
    elif u in ["tbsp", "tablespoon", "tablespoons"]:
        return amount * 15
    elif u in ["tsp", "teaspoon", "teaspoons"]:
        return amount * 5
    elif u in ["piece", "pieces", "slice", "slices"]:
        return amount * 50 # rough estimate
    return amount * UNIT_TO_GRAMS.get(u, 1.0)


def _scale_nutrients(nutrients_per_100g: dict, grams: float) -> dict:
    result = {}
    for col in NUTRIENT_COLS:
        try:
            result[col] = round(float(nutrients_per_100g.get(col, 0)) * grams / 100, 2)
        except (TypeError, ValueError):
            result[col] = 0.0
    return result


def _add(a: dict, b: dict) -> dict:
    return {col: round(a.get(col, 0) + b.get(col, 0), 2) for col in NUTRIENT_COLS}


def _subtract(a: dict, b: dict) -> dict:
    """Subtract b from a, floor at 0."""
    return {col: round(max(0, a.get(col, 0) - b.get(col, 0)), 2) for col in NUTRIENT_COLS}


def _ingr_per_100g(raw: dict) -> dict:
    """
    ingredients.csv has its own Quantity + Unit columns.
    Convert to nutrients-per-100g so we can scale to user's portion.
    """
    qty        = float(raw.get("Quantity", 1) or 1)
    unit       = str(raw.get("Unit", "g"))
    base_grams = _to_grams(qty, unit)
    per_100g   = {}
    for col in NUTRIENT_COLS:
        try:
            per_100g[col] = float(raw.get(col, 0)) / base_grams * 100
        except (TypeError, ZeroDivisionError):
            per_100g[col] = 0.0
    return per_100g


# ── service ──────────────────────────────────────────────────────────────────
class NutritionService:
    def calculate(
        self,
        detected_dishes:      list[str],
        portions:             list[dict],
        modifications:        list[dict],   # may be empty []
        dish_nutrients:       dict,          # from RAGDishes
        ingredient_nutrients: dict,          # from RAGIngredients (empty if no mods)
    ) -> dict:
        """
        Each portion dict : {dish_name, amount, unit}
        Each modification : {action, dish_name, new_item, original_item?, amount, unit}
          action = "add" | "replace" | "remove"
        """
        totals     = {col: 0.0 for col in NUTRIENT_COLS}
        per_dish   = {}   # dish → its nutrient contribution (for replace/remove reference)

        portion_map = {p["dish_name"]: p for p in portions}

        # ── 1. Base nutrients from detected dishes ────────────────────────────
        for dish in detected_dishes:
            portion = portion_map.get(dish)
            if not portion:
                continue

            grams      = _to_grams(portion["amount"], portion["unit"])
            rag_hit    = dish_nutrients.get(dish, {})
            n_100g     = rag_hit.get("nutrients", {}) if rag_hit else {}
            dish_total = _scale_nutrients(n_100g, grams)

            per_dish[dish] = dish_total
            totals = _add(totals, dish_total)

        # ── 2. Modifications (only if user actually added some) ───────────────
        for mod in modifications:
            action    = mod.get("action", "").lower()     # add | replace | remove
            dish_name = mod.get("dish_name", "")          # which dish this mod belongs to
            new_item  = mod.get("new_item", "")
            orig_item = mod.get("original_item", "")
            amount    = float(mod.get("amount", 0))
            unit      = mod.get("unit", "grams")

            user_grams = _to_grams(amount, unit)

            # ── ADD ───────────────────────────────────────────────────────────
            if action == "add":
                ingr_hit = ingredient_nutrients.get(new_item, {})
                if not ingr_hit:
                    continue
                raw      = ingr_hit.get("nutrients_per_unit", {})
                per_100g = _ingr_per_100g(raw)
                contrib  = _scale_nutrients(per_100g, user_grams)
                totals   = _add(totals, contrib)
                if dish_name:
                    if dish_name not in per_dish:
                        per_dish[dish_name] = {col: 0.0 for col in NUTRIENT_COLS}
                    per_dish[dish_name] = _add(per_dish.get(dish_name, {}), contrib)

            # ── REPLACE ───────────────────────────────────────────────────────
            elif action == "replace":
                # Step A: subtract the original ingredient
                if orig_item:
                    orig_hit = ingredient_nutrients.get(orig_item, {})
                    if orig_hit:
                        orig_raw     = orig_hit.get("nutrients_per_unit", {})
                        orig_per_100g = _ingr_per_100g(orig_raw)
                        orig_contrib  = _scale_nutrients(orig_per_100g, user_grams)
                        totals = _subtract(totals, orig_contrib)
                        if dish_name:
                            if dish_name not in per_dish:
                                per_dish[dish_name] = {col: 0.0 for col in NUTRIENT_COLS}
                            per_dish[dish_name] = _subtract(per_dish.get(dish_name, {}), orig_contrib)

                # Step B: add the new ingredient
                new_hit = ingredient_nutrients.get(new_item, {})
                if new_hit:
                    new_raw     = new_hit.get("nutrients_per_unit", {})
                    new_per_100g = _ingr_per_100g(new_raw)
                    new_contrib  = _scale_nutrients(new_per_100g, user_grams)
                    totals = _add(totals, new_contrib)
                    if dish_name:
                        if dish_name not in per_dish:
                            per_dish[dish_name] = {col: 0.0 for col in NUTRIENT_COLS}
                        per_dish[dish_name] = _add(per_dish.get(dish_name, {}), new_contrib)

            # ── REMOVE ───────────────────────────────────────────────────────
            elif action == "remove":
                # The item to remove is stored in new_item field
                # (frontend sends the ingredient name they want to remove)
                target = new_item or orig_item
                rem_hit = ingredient_nutrients.get(target, {})
                if not rem_hit:
                    continue
                rem_raw     = rem_hit.get("nutrients_per_unit", {})
                rem_per_100g = _ingr_per_100g(rem_raw)
                rem_contrib  = _scale_nutrients(rem_per_100g, user_grams)
                totals = _subtract(totals, rem_contrib)
                if dish_name:
                    if dish_name not in per_dish:
                        per_dish[dish_name] = {col: 0.0 for col in NUTRIENT_COLS}
                    per_dish[dish_name] = _subtract(per_dish.get(dish_name, {}), rem_contrib)

        return {
            "nutrients":  totals,
            "per_dish":   per_dish,
            "unit":       "absolute (for this meal)",
        }