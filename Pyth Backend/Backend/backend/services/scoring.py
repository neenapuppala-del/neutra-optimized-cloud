"""
services/scoring.py
────────────────────
Personalized meal scoring

Score = 100
        - nutrition penalties
        - BMI penalties
        - goal penalties
        - health-condition penalties

Scoring is PER MEAL.
"""

from config import DAILY_REFERENCE


# ─────────────────────────────────────────
# base nutrition rules
# (nutrient, direction, multiplier)
# high = penalize above target
# low  = penalize below target
# ─────────────────────────────────────────

PENALTY_RULES = [

    ("Calories (kcal)", "high", 1.4),
    ("Fats (g)", "high", 1.2),
    ("Free Sugar (g)", "high", 1.8),
    ("Sodium (mg)", "high", 1.5),

    ("Protein (g)", "low", 1.0),
    ("Fibre (g)", "low", 1.0),
    ("Calcium (mg)", "low", 0.8),
    ("Iron (mg)", "low", 0.8),
    ("Vitamin C (mg)", "low", 0.6),
]


# max penalty from one rule
MAX_DEDUCTION_PER_RULE = 10


# ─────────────────────────────────────────
# disease-specific rules
# nutrient,direction,limit,penalty
# ─────────────────────────────────────────

HEALTH_RULES = {

    "diabetes":[

        ("Free Sugar (g)","high",12,10),
        ("Fibre (g)","low",8,5),
    ],

    "pcos":[

        ("Free Sugar (g)","high",15,8),
        ("Protein (g)","low",15,5),
    ],

    "hypertension":[

        ("Sodium (mg)","high",700,10),
    ],

    "high blood pressure":[

        ("Sodium (mg)","high",700,10),
    ],

    "obesity":[

        ("Calories (kcal)","high",700,8),
        ("Fats (g)","high",25,5)
    ],

    "anemia":[

        ("Iron (mg)","low",6,8)
    ],

    "high cholesterol":[

        ("Fats (g)","high",20,8)
    ],

    "digestive issues":[

        ("Fibre (g)","high",15,5)
    ],

    "kidney disease":[

        ("Protein (g)","high",25,8),
        ("Sodium (mg)","high",500,8)
    ],

    "thyroid disorders":[

        ("Iron (mg)","low",5,5)
    ],

    "eating recovery":[

        ("Calories (kcal)","low",600,8),
        ("Protein (g)","low",15,5)
    ]

}


# ─────────────────────────────────────────

def _penalty(
        actual,
        reference,
        direction,
        multiplier
):

    if direction=="high":

        if actual<=reference:
            return 0

        diff=(actual-reference)/reference

    else:

        if actual>=reference:
            return 0

        diff=(reference-actual)/reference


    return min(
        diff*10*multiplier,
        MAX_DEDUCTION_PER_RULE
    )


# ─────────────────────────────────────────

class ScoringService:

    def score(
        self,
        nutrition_result,
        user_profile=None
    ):

        nutrients=nutrition_result.get(
            "nutrients",
            {}
        )


        score=100
        breakdown={}
        flags=[]


        calories=float(
            nutrients.get(
                "Calories (kcal)",
                0
            )
        )


        # ─────────────────────────
        # MEAL DAILY TARGETS
        # ─────────────────────────

        meal_reference={

            k:v/3
            for k,v in
            DAILY_REFERENCE.items()
        }


        # ─────────────────────────
        # BMI / GOAL
        # ─────────────────────────

        bmi=None
        goal="balance"
        target_weight=None
        current_weight=None


        if user_profile:

            bmi=user_profile.get("bmi")

            goal=(
                user_profile.get(
                    "goal",
                    "balance"
                )
                .lower()
            )

            target_weight=(
                user_profile.get(
                    "target_weight"
                )
            )

            current_weight=(
                user_profile.get(
                    "weight"
                )
            )


        # weight adjustment

        calorie_target=650


        if goal=="weight loss":

            calorie_target=550

        elif goal=="weight gain":

            calorie_target=800


        if bmi:

            if bmi<18.5:

                calorie_target+=100

            elif bmi>=25:

                calorie_target-=100


        # target weight gap

        if (
            target_weight
            and current_weight
        ):

            gap=(
                target_weight
                -current_weight
            )


            if goal=="weight gain":

                calorie_target+=min(
                    abs(gap)*10,
                    150
                )


            elif goal=="weight loss":

                calorie_target-=min(
                    abs(gap)*10,
                    150
                )


        # replace meal calories

        meal_reference[
            "Calories (kcal)"
        ]=calorie_target


        # ─────────────────────────
        # BASE NUTRITION
        # ─────────────────────────

        for nutrient,direction,multiplier in PENALTY_RULES:

            actual=float(
                nutrients.get(
                    nutrient,
                    0
                )
            )

            reference=float(
                meal_reference.get(
                    nutrient,
                    1
                )
            )


            p=_penalty(
                actual,
                reference,
                direction,
                multiplier
            )

            score-=p


            breakdown[
                nutrient
            ]={

                "actual":
                round(actual,2),

                "target":
                round(reference,2),

                "penalty":
                round(p,2)

            }


            if p>=5:

                flags.append(

                    f"{nutrient} imbalance"
                )


        # ─────────────────────────
        # HEALTH CONDITIONS
        # ─────────────────────────

        if user_profile:

            issues=[

                h.lower()

                for h in

                user_profile.get(
                    "health_issues",
                    []
                )
            ]


            for issue in issues:

                rules=HEALTH_RULES.get(
                    issue,
                    []
                )


                for(
                    nutrient,
                    direction,
                    limit,
                    penalty
                ) in rules:


                    value=float(

                        nutrients.get(
                            nutrient,
                            0
                        )
                    )


                    trigger=False


                    if (
                        direction=="high"
                        and
                        value>limit
                    ):

                        trigger=True


                    elif(
                        direction=="low"
                        and
                        value<limit
                    ):

                        trigger=True


                    if trigger:

                        score-=penalty

                        flags.append(

                            f"{issue.title()}: "
                            f"{nutrient}"
                        )


        score=max(
            0,
            round(score)
        )


        if score>=85:
            grade="A"

        elif score>=70:
            grade="B"

        elif score>=55:
            grade="C"

        elif score>=40:
            grade="D"

        else:
            grade="F"


        return{

            "score":score,
            "grade":grade,
            "flags":flags,
            "breakdown":breakdown
        }