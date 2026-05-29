import os
import json
import urllib.request
import urllib.error
from typing import List, Dict, Any

class SuggestionsService:
    def __init__(self):
        # Read API key from env or look in local environments if loaded
        self.api_key = os.environ.get("GEMINI_API_KEY")
        if self.api_key and (self.api_key.strip() == "" or self.api_key.startswith("your_")):
            self.api_key = None
        if not self.api_key:
            print("[SuggestionsService] GEMINI_API_KEY not found in environment or is a placeholder, running offline expert rules.")

    def generate(self, final_nutrients: Dict[str, Any], user_profile: Dict[str, Any] | None) -> List[Dict[str, Any]]:
        user_profile = user_profile or {}
        weight = user_profile.get("weight")
        height = user_profile.get("height")
        target_weight = user_profile.get("target_weight")
        goals = user_profile.get("goals") or []
        health_issues = user_profile.get("health_issues") or []
        dietary_preferences = user_profile.get("dietary_preferences") or []

        # Convert strings to lower for robust matching
        goals = [g.lower() for g in goals if isinstance(g, str)]
        health_issues = [h.lower() for h in health_issues if isinstance(h, str)]
        dietary_preferences = [d.lower() for d in dietary_preferences if isinstance(d, str)]

        # Calculate BMI
        bmi = None
        bmi_category = "Normal weight"
        if weight and height:
            try:
                weight_f = float(weight)
                height_f = float(height)
                if height_f > 0:
                    bmi = weight_f / ((height_f / 100) ** 2)
                    if bmi < 18.5:
                        bmi_category = "Underweight"
                    elif bmi < 25.0:
                        bmi_category = "Normal weight"
                    elif bmi < 30.0:
                        bmi_category = "Overweight"
                    else:
                        bmi_category = "Obese"
            except Exception:
                pass

        # Try Gemini LLM if key is present
        if self.api_key:
            suggestions = self._generate_via_gemini(final_nutrients, user_profile, bmi, bmi_category)
            if suggestions:
                return suggestions

        # Fallback to offline high-fidelity expert system
        return self._generate_via_fallback(final_nutrients, user_profile, bmi, bmi_category, weight, height, target_weight, goals, health_issues, dietary_preferences)

    def _generate_via_gemini(self, final_nutrients: Dict[str, Any], user_profile: Dict[str, Any], bmi: float | None, bmi_category: str) -> List[Dict[str, Any]] | None:
        try:
            nutrients = final_nutrients.get("nutrients", {})
            prompt = f"""
You are an expert AI Nutritionist. Based on the user profile and the scanned meal's nutrients, generate 3 highly personalized, actionable suggestions/recommendations.

User Profile:
- Age: {user_profile.get("age", "Unknown")}
- Gender: {user_profile.get("gender", "Unknown")}
- Current Weight: {user_profile.get("weight", "Unknown")} kg
- Target Weight: {user_profile.get("target_weight", "Unknown")} kg
- Height: {user_profile.get("height", "Unknown")} cm
- Calculated BMI: {f"{bmi:.1f}" if bmi else "Unknown"} ({bmi_category})
- Goals: {", ".join(user_profile.get("goals", [])) if user_profile.get("goals") else "None"}
- Health Issues: {", ".join(user_profile.get("health_issues", [])) if user_profile.get("health_issues") else "None"}
- Dietary Preferences: {", ".join(user_profile.get("dietary_preferences", [])) if user_profile.get("dietary_preferences") else "None"}

Scanned Meal Nutrients:
{json.dumps(nutrients, indent=2)}

You MUST generate exactly 3 suggestion cards. Each card must be represented by a JSON object with the following fields:
- "type": "positive" (for good aspects/achievements), "warning" (for concerns/hazards), or "info" (for general advice/context).
- "title": A short, impactful title (4-7 words).
- "description": A highly personalized, detailed explanation (1-2 sentences) directly linking the meal's nutrient profile to their BMI, target weight, health issues, goals, or dietary preferences.

Output format:
Return ONLY a valid JSON array of objects. Do not include markdown code block syntax (like ```json). Just the raw JSON.
Example output:
[
  {{"type": "warning", "title": "High Sodium and Hypertension Alert", "description": "This meal contains 800mg of sodium, which is very high for your hypertension issue. Try reducing salt intake or adding fresh vegetables."}},
  ...
]
"""
            url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={self.api_key}"
            req_data = {
                "contents": [
                    {
                        "parts": [
                            {"text": prompt}
                        ]
                    }
                ],
                "generationConfig": {
                    "responseMimeType": "application/json"
                }
            }
            req_json = json.dumps(req_data).encode("utf-8")
            req = urllib.request.Request(
                url,
                data=req_json,
                headers={"Content-Type": "application/json"},
                method="POST"
            )
            
            with urllib.request.urlopen(req, timeout=10) as response:
                res_body = response.read().decode("utf-8")
                res_data = json.loads(res_body)
                text_response = res_data["candidates"][0]["content"]["parts"][0]["text"].strip()
                
                # Simple parsing and cleaning
                if text_response.startswith("```"):
                    lines = text_response.splitlines()
                    if lines[0].startswith("```"):
                        lines = lines[1:]
                    if lines[-1].startswith("```"):
                        lines = lines[:-1]
                    text_response = "\n".join(lines).strip()
                
                suggestions = json.loads(text_response)
                if isinstance(suggestions, list) and len(suggestions) > 0:
                    valid_suggestions = []
                    for s in suggestions:
                        if isinstance(s, dict) and "type" in s and "title" in s and "description" in s:
                            stype = s["type"].lower()
                            if stype not in ["positive", "warning", "info"]:
                                stype = "info"
                            valid_suggestions.append({
                                "type": stype,
                                "title": s["title"],
                                "description": s["description"]
                            })
                    if valid_suggestions:
                        return valid_suggestions
        except Exception as e:
            print(f"[SuggestionsService] Gemini API call failed: {e}")
        return None

    def _generate_via_fallback(self, final_nutrients: Dict[str, Any], user_profile: Dict[str, Any], 
                               bmi: float | None, bmi_category: str, 
                               weight: Any, height: Any, target_weight: Any, 
                               goals: List[str], health_issues: List[str], dietary_preferences: List[str]) -> List[Dict[str, Any]]:
        
        nutrients = final_nutrients.get("nutrients", {})
        calories = float(nutrients.get("Calories (kcal)", 0))
        sugar = float(nutrients.get("Free Sugar (g)", 0))
        sodium = float(nutrients.get("Sodium (mg)", 0))
        protein = float(nutrients.get("Protein (g)", 0))
        carbs = float(nutrients.get("Carbohydrates (g)", 0))
        fiber = float(nutrients.get("Fibre (g)", 0))
        fats = float(nutrients.get("Fats (g)", 0))

        suggestions = []

        # ── Card 1: Goal & BMI Alignment ─────────────────────────────────────
        weight_loss_goal = "weight loss" in goals or "lose weight" in goals or (weight and target_weight and float(target_weight) < float(weight))
        muscle_gain_goal = "muscle gain" in goals or "gain muscle" in goals or "bulk" in goals

        if weight_loss_goal:
            if calories > 650:
                suggestions.append({
                    "type": "warning",
                    "title": "High Calorie vs Weight Loss Goal",
                    "description": f"This meal contains {calories:.0f} kcal, which is high for your weight loss target (Aiming for {target_weight or 'lower'} kg from {weight or 'current'} kg). Consider a smaller portion."
                })
            elif calories < 400:
                suggestions.append({
                    "type": "positive",
                    "title": "Excellent Calorie Deficit Choice",
                    "description": f"At only {calories:.0f} kcal, this light meal aligns perfectly with your Weight Loss goal and {bmi_category} BMI ({bmi:.1f} if bmi else '')."
                })
            else:
                suggestions.append({
                    "type": "info",
                    "title": "Calorie Conscious Alignment",
                    "description": f"This meal provides {calories:.0f} kcal. It fits moderately into your weight loss plan; watch other meals to maintain a calorie deficit."
                })
        elif muscle_gain_goal:
            if protein >= 20:
                suggestions.append({
                    "type": "positive",
                    "title": "High Protein Muscle Builder",
                    "description": f"Awesome! This meal delivers {protein:.1f}g of protein, which supports muscle protein synthesis and your Muscle Gain goals."
                })
            else:
                suggestions.append({
                    "type": "warning",
                    "title": "Boost Protein for Muscle Support",
                    "description": f"To optimize muscle synthesis, aim for 20-30g of protein. This meal only has {protein:.1f}g. Consider adding tofu, egg whites, or lean meats."
                })
        else:
            # General BMI fallback
            if bmi and bmi >= 25.0:
                if calories > 600:
                    suggestions.append({
                        "type": "warning",
                        "title": "Calorie Density Notice",
                        "description": f"Since your BMI is {bmi:.1f} ({bmi_category}), a meal of {calories:.0f} kcal might exceed your maintenance targets. Try adding high-volume low-cal veggies."
                    })
                else:
                    suggestions.append({
                        "type": "positive",
                        "title": "Great Portion Control",
                        "description": f"This calorie-conscious meal ({calories:.0f} kcal) helps you manage weight beautifully with your BMI at {bmi:.1f}."
                    })
            else:
                suggestions.append({
                    "type": "info",
                    "title": "Caloric Density Analysis",
                    "description": f"This meal delivers {calories:.0f} kcal, serving as a balanced energy source for a healthy {bmi_category} profile."
                })

        # ── Card 2: Health Issues & Nutrient Warnings ──────────────────────────
        has_diabetes = "diabetes" in health_issues or "diabetic" in health_issues
        has_hypertension = "hypertension" in health_issues or "high blood pressure" in health_issues or "bp" in health_issues

        if has_diabetes:
            if sugar > 10:
                suggestions.append({
                    "type": "warning",
                    "title": "Diabetic Sugar Alert",
                    "description": f"Caution: This meal contains {sugar:.1f}g of sugar. To prevent rapid insulin and blood sugar spikes, balance this with dietary fiber."
                })
            else:
                suggestions.append({
                    "type": "positive",
                    "title": "Steady Blood Glucose Choice",
                    "description": f"Great choice! With only {sugar:.1f}g of sugar, this meal helps maintain stable glucose control for your diabetes management."
                })
        elif has_hypertension:
            if sodium > 600:
                suggestions.append({
                    "type": "warning",
                    "title": "Hypertension Sodium Alert",
                    "description": f"This meal has {sodium:.0f}mg of sodium, which is very high for hypertension. Flavor with lemon, garlic, or fresh spices instead of salt."
                })
            else:
                suggestions.append({
                    "type": "positive",
                    "title": "Vascular Health Friendly",
                    "description": f"Perfect! The low sodium level ({sodium:.0f}mg) keeps blood pressure stable and supports overall heart health."
                })
        else:
            # Fallback general warnings
            if sugar > 15:
                suggestions.append({
                    "type": "warning",
                    "title": "High Free Sugars",
                    "description": f"This meal has {sugar:.1f}g of free sugar. Reducing sugar intake protects liver health and lowers metabolic disorder risks."
                })
            elif sodium > 800:
                suggestions.append({
                    "type": "warning",
                    "title": "High Sodium Content",
                    "description": f"With {sodium:.0f}mg of sodium, this meal is sodium-heavy. Keep hydration high to flush excess salt and protect your blood vessels."
                })
            else:
                suggestions.append({
                    "type": "info",
                    "title": "Clean Nutrient Profile",
                    "description": "Your meal is low in refined sugars and excessive sodium, promoting great cardiovascular and metabolic baseline health."
                })

        # ── Card 3: Dietary Preferences & Digestion/Satiety ────────────────────
        is_vegan = "vegan" in dietary_preferences
        is_vegetarian = "vegetarian" in dietary_preferences or "veg" in dietary_preferences
        is_keto = "keto" in dietary_preferences or "ketogenic" in dietary_preferences or "low carb" in dietary_preferences

        if is_keto:
            if carbs > 35:
                suggestions.append({
                    "type": "warning",
                    "title": "Keto Carb Threshold Exceeded",
                    "description": f"This meal has {carbs:.1f}g of carbs. To remain in ketosis, swap high-carb ingredients for healthy fats and green fibers."
                })
            else:
                suggestions.append({
                    "type": "positive",
                    "title": "Perfect Keto-Friendly Plate",
                    "description": f"Outstanding! With only {carbs:.1f}g of carbs, this meal keeps you in ketosis while providing great energy."
                })
        elif is_vegan or is_vegetarian:
            if fiber >= 5.0:
                suggestions.append({
                    "type": "positive",
                    "title": "Fiber-Rich Plant-Based Fuel",
                    "description": f"Superb! Your plant-based meal contains {fiber:.1f}g of fiber. This feeds healthy gut bacteria and boosts digestion."
                })
            else:
                suggestions.append({
                    "type": "info",
                    "title": "Optimize Plant Protein & Fiber",
                    "description": f"This meal provides {fiber:.1f}g of fiber. Pair it with complex grains (quinoa, brown rice) and seeds to enhance amino acid profiles."
                })
        else:
            # General Digestion/Satiety fallback
            if fiber < 2.0:
                suggestions.append({
                    "type": "warning",
                    "title": "Low Fiber: Enhance Gut Satiety",
                    "description": f"This meal has only {fiber:.1f}g of fiber. Consider adding broccoli, spinach, or chia seeds next time to support digestion."
                })
            else:
                suggestions.append({
                    "type": "positive",
                    "title": "Highly Satiating Fiber Profile",
                    "description": f"With {fiber:.1f}g of fiber, this meal digests slowly, keeping you full and curbing cravings between meals."
                })

        # Ensure we always return exactly 3 suggestions
        while len(suggestions) < 3:
            suggestions.append({
                "type": "info",
                "title": "Balanced Nutrition Tip",
                "description": "Ensure you pair your meals with plenty of fresh water throughout the day for optimal metabolic function."
            })
        return suggestions[:3]
