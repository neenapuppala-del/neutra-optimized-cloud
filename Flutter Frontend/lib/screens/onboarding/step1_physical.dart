import 'package:flutter/material.dart';

class Step1Physical extends StatefulWidget {
  final int initialAge;
  final double initialHeight;
  final double initialWeight;
  final String initialGender;
  final Function(int age, double height, double weight, String gender) onNext;

  const Step1Physical({
    super.key,
    required this.initialAge,
    required this.initialHeight,
    required this.initialWeight,
    required this.initialGender,
    required this.onNext,
  });

  @override
  State<Step1Physical> createState() => _Step1PhysicalState();
}

class _Step1PhysicalState extends State<Step1Physical> {
  late final TextEditingController _ageCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;
  late String _gender;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _ageCtrl = TextEditingController(text: widget.initialAge.toString());
    _heightCtrl = TextEditingController(text: widget.initialHeight.toString());
    _weightCtrl = TextEditingController(text: widget.initialWeight.toString());
    _gender = widget.initialGender;
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final age = int.tryParse(_ageCtrl.text.trim()) ?? widget.initialAge;
      final height = double.tryParse(_heightCtrl.text.trim()) ?? widget.initialHeight;
      final weight = double.tryParse(_weightCtrl.text.trim()) ?? widget.initialWeight;
      
      widget.onNext(age, height, weight, _gender);
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text("Step 1 of 4", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                const SizedBox(height: 10),
                progressBar(0.25, isDark),
                const SizedBox(height: 30),
                const Text(
                  "Tell us about yourself 👤",
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: textColor, fontFamily: 'Cormorant'),
                ),
                const SizedBox(height: 8),
                Text(
                  "Let's start with your basic measurements and details",
                  style: TextStyle(color: hintColor, fontSize: 14),
                ),
                const SizedBox(height: 30),

                _buildTextField("Age (years)", _ageCtrl, true, isDark, textColor),
                const SizedBox(height: 20),
                _buildTextField("Height (cm)", _heightCtrl, false, isDark, textColor),
                const SizedBox(height: 20),
                _buildTextField("Weight (kg)", _weightCtrl, false, isDark, textColor),
                const SizedBox(height: 20),
                
                Text("Gender", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: textColor)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _gender,
                  dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  style: TextStyle(color: textColor, fontSize: 15),
                  decoration: inputStyle("Gender", isDark),
                  items: ['Male', 'Female', 'Other'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value, 
                      child: Text(value, style: TextStyle(color: textColor)),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      setState(() => _gender = newValue);
                    }
                  },
                ),

                const SizedBox(height: 50),
                button("Continue", _submit),
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

  InputDecoration inputStyle(String hint, bool isDark) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
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
          borderSide: const BorderSide(color: Color(0xFF7CB342), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
      );

  Widget _buildTextField(String label, TextEditingController ctrl, bool isInt, bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: textColor)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          style: TextStyle(color: textColor),
          keyboardType: TextInputType.number,
          decoration: inputStyle(label, isDark),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return "Please enter a valid value";
            }
            final parsed = isInt ? int.tryParse(value) : double.tryParse(value);
            if (parsed == null || parsed <= 0) {
              return "Please enter a valid positive number";
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget button(String text, VoidCallback onTap) {
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
