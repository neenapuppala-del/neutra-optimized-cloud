import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import 'step1_physical.dart';
import 'step2_goal.dart';
import 'step3_health.dart';
import 'step4_diet.dart';
import '../../services/user_service.dart';
import '../home/main_home.dart';

class OnboardingScreen extends StatefulWidget {
  final String userId;
  final String name;

  const OnboardingScreen({
    super.key,
    required this.userId,
    required this.name,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int step = 0;
  bool _isLoading = false;

  // Step 1 State: Physical
  int _age = 25;
  double _height = 170.0;
  double _weight = 70.0;
  String _gender = "Male";

  // Step 2 State: Goal
  String _selectedGoal = "Lose Weight";
  double _targetWeight = 65.0;

  // Step 3 State: Health
  Set<String> _selectedConditions = {};

  // Step 4 State: Diet
  Set<String> _selectedPrefs = {};
  Set<String> _selectedAllergies = {};

  void next() {
    if (step < 3) {
      setState(() => step++);
    } else {
      _completeOnboarding();
    }
  }

  void back() {
    if (step > 0) {
      setState(() => step--);
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() => _isLoading = true);

    try {
      // Health issues combined for DB schema
      List<String> healthIssues = [];
      healthIssues.addAll(_selectedConditions);
      healthIssues.addAll(_selectedAllergies);

      final profileData = {
        'userId': widget.userId,
        'name': widget.name.isNotEmpty ? widget.name : "Healthy User",
        'age': _age,
        'height': _height,
        'weight': _weight,
        'gender': _gender,
        'goals': [_selectedGoal],
        'target_weight': _targetWeight,
        'health_issues': healthIssues,
        'dietary_preferences': _selectedPrefs.toList(),
      };

      final success = await UserService.saveProfile(profileData);

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          // Reset theme dynamically to light theme for the new user upon completing onboarding
          Provider.of<ThemeProvider>(context, listen: false).toggleTheme(false, syncToBackend: true);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainHome()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save profile. Please try again.')),
          );
        }
      }
    } catch (e) {
      print("Error completing onboarding: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF1B3A1E);
    const bgColor = Color(0xFFFAF9F5); // Strict Light Mode Warm Ivory

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF7CB342)),
              const SizedBox(height: 16),
              Text(
                "Personalizing your AI health companion...",
                style: TextStyle(fontWeight: FontWeight.w500, color: textColor),
              ),
            ],
          ),
        ),
      );
    }

    final pages = [
      Step1Physical(
        initialAge: _age,
        initialHeight: _height,
        initialWeight: _weight,
        initialGender: _gender,
        onNext: (age, height, weight, gender) {
          _age = age;
          _height = height;
          _weight = weight;
          _gender = gender;
          next();
        },
      ),
      Step2Goal(
        initialGoal: _selectedGoal,
        initialTargetWeight: _targetWeight,
        onNext: (goal, targetWeight) {
          _selectedGoal = goal;
          _targetWeight = targetWeight;
          next();
        },
        onBack: back,
      ),
      Step3Health(
        initialConditions: _selectedConditions,
        onNext: (conditions) {
          _selectedConditions = conditions;
          next();
        },
        onBack: back,
      ),
      Step4Diet(
        initialPrefs: _selectedPrefs,
        initialAllergies: _selectedAllergies,
        onNext: (prefs, allergies) {
          _selectedPrefs = prefs;
          _selectedAllergies = allergies;
          next();
        },
        onBack: back,
      ),
    ];

    return Scaffold(
      backgroundColor: bgColor,
      body: pages[step],
    );
  }
}
