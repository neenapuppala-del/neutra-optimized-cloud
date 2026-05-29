import 'package:flutter/material.dart';

class Step4Diet extends StatefulWidget {
  final Set<String> initialPrefs;
  final Set<String> initialAllergies;
  final Function(Set<String> prefs, Set<String> allergies) onNext;
  final VoidCallback onBack;

  const Step4Diet({
    super.key,
    required this.initialPrefs,
    required this.initialAllergies,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<Step4Diet> createState() => _Step4DietState();
}

class _Step4DietState extends State<Step4Diet> {
  late Set<String> _selectedPrefs;
  late Set<String> _selectedAllergies;

  final List<String> preferences = [
    "Vegetarian", "Vegan", "Pescatarian", 
    "Keto", "Paleo", "Mediterranean", 
    "Low Carb", "High Protein", "Gluten Free",
    "Dairy Free", "Halal", "Kosher"
  ];

  final List<String> allergies = [
    "Peanuts", "Tree Nuts", "Milk", "Eggs", 
    "Wheat", "Soy", "Fish", "Shellfish", 
    "Sesame", "Mustard"
  ];

  @override
  void initState() {
    super.initState();
    _selectedPrefs = Set.from(widget.initialPrefs);
    _selectedAllergies = Set.from(widget.initialAllergies);
  }

  void _toggleSelection(String item, Set<String> selections) {
    setState(() {
      if (selections.contains(item)) {
        selections.remove(item);
      } else {
        selections.add(item);
      }
    });
  }

  void _submit() {
    widget.onNext(_selectedPrefs, _selectedAllergies);
  }

  @override
  Widget build(BuildContext context) {
    const isDark = false; // Strict Light Mode Warm Ivory
    const textColor = Color(0xFF1B3A1E);
    final hintColor = Colors.grey.shade600;
    const bgColor = Color(0xFFFAF9F5);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack, 
                    icon: const Icon(Icons.arrow_back, color: textColor),
                  ),
                  const Spacer(),
                  const Text("Step 4 of 4", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 10),
              progressBar(1.0, isDark),
              const SizedBox(height: 30),
              
              const Text(
                "Diet & Allergies 🥦",
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: textColor, fontFamily: 'Cormorant'),
              ),
              const SizedBox(height: 6),
              Text(
                "Select all that apply to help personalize your diet suggestions",
                style: TextStyle(color: hintColor, fontSize: 15),
              ),
              const SizedBox(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Food Preferences",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(height: 16),
                      _buildChipGroup(preferences, _selectedPrefs, isDark),
                      
                      const SizedBox(height: 32),
                      
                      Text(
                        "Allergies & Intolerances",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(height: 16),
                      _buildChipGroup(allergies, _selectedAllergies, isDark),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              _button("Complete Setup", _submit),
            ],
          ),
        ),
      ),
    );
  }

  Widget progressBar(double value, bool isDark) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 8,
          backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7CB342)),
        ),
      );

  Widget _buildChipGroup(List<String> items, Set<String> selections, bool isDark) {
    const lightGreen = Color(0xFF7CB342);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items.map((item) {
        final isSelected = selections.contains(item);
        return GestureDetector(
          onTap: () => _toggleSelection(item, selections),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected 
                  ? lightGreen.withOpacity(0.08) 
                  : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected ? lightGreen : (isDark ? Colors.white10 : Colors.grey.shade300),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected && !isDark ? [
                BoxShadow(
                  color: lightGreen.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ] : null,
            ),
            child: Text(
              item,
              style: TextStyle(
                color: isSelected 
                    ? lightGreen 
                    : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _button(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 55,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFF8BC34A), Color(0xFF2E7D32)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E7D32).withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 8),
              const Icon(Icons.check, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
