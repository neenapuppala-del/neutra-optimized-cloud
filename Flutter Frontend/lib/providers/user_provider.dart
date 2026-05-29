import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  String name = "Jane Doe";
  String email = "jane@example.com";
  String height = "165";
  String weight = "65";
  String goal = "Lose Weight";
  String targetWeight = "60";

  Set<String> healthConditions = {"PCOS"};
  Set<String> dietaryPrefs = {"Vegan"};
  Set<String> allergies = {"Dairy"};

  void updateProfile({String? newName, String? newEmail, String? newHeight, String? newWeight, String? newGoal, String? newTarget}) {
    if (newName != null) name = newName;
    if (newEmail != null) email = newEmail;
    if (newHeight != null) height = newHeight;
    if (newWeight != null) weight = newWeight;
    if (newGoal != null) goal = newGoal;
    if (newTarget != null) targetWeight = newTarget;
    notifyListeners();
  }

  void updateHealth(Set<String> conditions) {
    healthConditions = Set.from(conditions);
    notifyListeners();
  }

  void updateDiet(Set<String> diets) {
    dietaryPrefs = Set.from(diets);
    notifyListeners();
  }

  void updateAllergies(Set<String> newAllergies) {
    allergies = Set.from(newAllergies);
    notifyListeners();
  }
}
