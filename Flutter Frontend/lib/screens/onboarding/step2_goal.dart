import 'package:flutter/material.dart';

class Step2Goal extends StatefulWidget {
  final String initialGoal;
  final double initialTargetWeight;
  final Function(String goal, double targetWeight) onNext;
  final VoidCallback onBack;

  const Step2Goal({
    super.key,
    required this.initialGoal,
    required this.initialTargetWeight,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<Step2Goal> createState() => _Step2GoalState();
}

class _Step2GoalState extends State<Step2Goal> {
  late String _selectedGoal;
  late final TextEditingController _targetWeightCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _selectedGoal = widget.initialGoal;
    _targetWeightCtrl = TextEditingController(
      text: widget.initialTargetWeight > 0 ? widget.initialTargetWeight.toString() : "",
    );
  }

  @override
  void dispose() {
    _targetWeightCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_selectedGoal == "Lose Weight" || _selectedGoal == "Gain Weight") {
      if (_formKey.currentState!.validate()) {
        final target = double.tryParse(_targetWeightCtrl.text.trim()) ?? widget.initialTargetWeight;
        widget.onNext(_selectedGoal, target);
      }
    } else {
      widget.onNext(_selectedGoal, 0.0);
    }
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
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back, color: textColor),
                    ),
                    const Spacer(),
                    const Text("Step 2 of 4", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 10),
                progressBar(0.50, isDark),
                const SizedBox(height: 20),
                
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      const Text(
                        "What's your goal? 🎯",
                        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: textColor, fontFamily: 'Cormorant'),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Choose the goal that fits your journey",
                        style: TextStyle(color: hintColor, fontSize: 15),
                      ),
                      const SizedBox(height: 24),
                      
                      _buildGoalCard("Lose Weight", "Achieve your target weight", Icons.track_changes, Colors.redAccent, isDark, textColor),
                      _buildGoalCard("Gain Weight", "Build healthy mass", Icons.fitness_center, Colors.orange, isDark, textColor),
                      _buildGoalCard("Maintain Weight", "Stay at current weight", Icons.monitor_weight_outlined, Colors.blueAccent, isDark, textColor),

                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: (_selectedGoal == "Lose Weight" || _selectedGoal == "Gain Weight")
                            ? Padding(
                                padding: const EdgeInsets.only(top: 20, bottom: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Target Weight (kg)",
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: textColor),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _targetWeightCtrl,
                                      style: TextStyle(color: textColor),
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        hintText: "Enter your target weight to reach",
                                        hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400, fontSize: 14),
                                        filled: true,
                                        fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: const BorderSide(color: Colors.red, width: 1),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return "Please enter target weight";
                                        }
                                        final target = double.tryParse(value);
                                        if (target == null || target <= 0) {
                                          return "Please enter a valid weight";
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                _button("Continue", _submit),
              ],
            ),
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

  Widget _buildGoalCard(String title, String subtitle, IconData icon, Color iconColor, bool isDark, Color textColor) {
    final isSelected = _selectedGoal == title;
    const primaryColor = Color(0xFF7CB342);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGoal = title;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isSelected 
              ? primaryColor.withOpacity(0.08) 
              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          border: Border.all(
            color: isSelected ? primaryColor : (isDark ? Colors.white10 : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected && !isDark ? [
            const BoxShadow(
              color: Color(0x0C1B3A1E),
              blurRadius: 15,
              offset: Offset(0, 4),
            )
          ] : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected 
                    ? primaryColor.withOpacity(0.12) 
                    : (isDark ? Colors.black26 : Colors.grey.shade50),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? primaryColor : iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? primaryColor : textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 24,
              width: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? primaryColor : (isDark ? Colors.white24 : Colors.grey.shade300),
                  width: isSelected ? 6 : 2,
                ),
              ),
            ),
          ],
        ),
      ),
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
              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
