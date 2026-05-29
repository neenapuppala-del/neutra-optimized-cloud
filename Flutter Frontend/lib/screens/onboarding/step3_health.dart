import 'package:flutter/material.dart';

class Step3Health extends StatefulWidget {
  final Set<String> initialConditions;
  final Function(Set<String> conditions) onNext;
  final VoidCallback onBack;

  const Step3Health({
    super.key,
    required this.initialConditions,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<Step3Health> createState() => _Step3HealthState();
}

class _Step3HealthState extends State<Step3Health> {
  late Set<String> _selectedConditions;
  
  final List<Map<String, dynamic>> conditions = [
    {"name": "PCOS", "icon": Icons.medical_services_outlined, "color": Colors.purple},
    {"name": "Diabetes", "icon": Icons.water_drop, "color": Colors.redAccent},
    {"name": "Thyroid Disorders", "icon": Icons.bubble_chart, "color": Colors.orange},
    {"name": "Obesity", "icon": Icons.scale, "color": Colors.amber},
    {"name": "Hypertension", "icon": Icons.monitor_heart, "color": Colors.pink},
    {"name": "Anemia", "icon": Icons.bloodtype, "color": Colors.red},
    {"name": "High Cholesterol", "icon": Icons.fastfood, "color": Colors.deepOrange},
    {"name": "Digestive Issues", "icon": Icons.spa, "color": Colors.teal},
    {"name": "Kidney Disease", "icon": Icons.grain, "color": Colors.brown},
    {"name": "Eating Recovery", "icon": Icons.favorite, "color": Colors.lightGreen},
  ];

  @override
  void initState() {
    super.initState();
    _selectedConditions = Set.from(widget.initialConditions);
  }

  void _toggleCondition(String condition) {
    setState(() {
      if (_selectedConditions.contains(condition)) {
        _selectedConditions.remove(condition);
      } else {
        _selectedConditions.add(condition);
      }
    });
  }

  void _submit() {
    widget.onNext(_selectedConditions);
  }

  @override
  Widget build(BuildContext context) {
    const isDark = false; // Strict Light Mode Warm Ivory
    const textColor = Color(0xFF1B3A1E);
    final hintColor = Colors.grey.shade600;
    const bgColor = Color(0xFFFAF9F5);
    const lightGreen = Color(0xFF7CB342);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back, color: textColor),
                  ),
                  const Spacer(),
                  const Text("Step 3 of 4", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 10),
              progressBar(0.75, isDark),
              const SizedBox(height: 30),
              
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Health conditions 🩺",
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: textColor, fontFamily: 'Cormorant'),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Select any health issues you have (optional)",
                  style: TextStyle(color: hintColor, fontSize: 15),
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: conditions.length,
                  itemBuilder: (context, index) {
                    final item = conditions[index];
                    final isSelected = _selectedConditions.contains(item["name"]);
                    
                    return GestureDetector(
                      onTap: () => _toggleCondition(item["name"]),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? lightGreen.withOpacity(0.08) 
                              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? lightGreen : (isDark ? Colors.white10 : Colors.grey.shade200),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected && !isDark ? [
                            BoxShadow(
                              color: lightGreen.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ] : null,
                        ),
                        child: Row(
                          children: [
                            Icon(item["icon"], color: item["color"], size: 24),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                item["name"],
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isSelected ? lightGreen : textColor,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: lightGreen, size: 22)
                            else
                              Icon(Icons.circle_outlined, color: isDark ? Colors.white24 : Colors.grey, size: 22),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              _button("Continue", _submit),
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
