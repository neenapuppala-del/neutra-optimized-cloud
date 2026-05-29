import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/user_service.dart';
import '../home/main_home.dart';

class OnboardingScreen extends StatefulWidget {
  final String userId;
  final String name;
  const OnboardingScreen({super.key, required this.userId, required this.name});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();

  String _gender = 'Other';
  final List<String> _selectedGoals = [];
  final List<String> _selectedHealthIssues = [];

  bool _isLoading = false;

  final List<String> _availableGoals = ['Weight Loss', 'Muscle Gain', 'Maintenance', 'Healthy Eating'];
  final List<String> _availableHealthIssues = ['Diabetes', 'Hypertension', 'High Cholesterol', 'PCOS', 'None'];

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.name;
  }

  void _saveProfile() async {
    if (_nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final isDarkTheme = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    final profileData = {
      'userId': widget.userId,
      'name': _nameCtrl.text.trim(),
      'age': int.tryParse(_ageCtrl.text) ?? 0,
      'weight': double.tryParse(_weightCtrl.text) ?? 0.0,
      'height': double.tryParse(_heightCtrl.text) ?? 0.0,
      'gender': _gender,
      'goals': _selectedGoals,
      'health_issues': _selectedHealthIssues.where((e) => e != 'None').toList(),
      'theme': isDarkTheme ? 'dark' : 'light',
    };

    final success = await UserService.saveProfile(profileData);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
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
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final bgColor = isDark ? const Color(0xFF000000) : Colors.white;
    const lightGreen = Color(0xFF81C784);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Personalize Your AI', style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Tell us about yourself",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                "This helps NutraAI provide customized scoring and insights.",
                style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
              const SizedBox(height: 30),

              _buildTextField("Full Name", _nameCtrl, TextInputType.name, isDark),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTextField("Age", _ageCtrl, TextInputType.number, isDark)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                      style: TextStyle(color: textColor),
                      items: ['Male', 'Female', 'Other'].map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value));
                      }).toList(),
                      onChanged: (newValue) => setState(() => _gender = newValue!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTextField("Weight (kg)", _weightCtrl, const TextInputType.numberWithOptions(decimal: true), isDark)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField("Height (cm)", _heightCtrl, const TextInputType.numberWithOptions(decimal: true), isDark)),
                ],
              ),
              
              const SizedBox(height: 30),
              Text("Primary Goals", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableGoals.map((goal) => _buildChoiceChip(goal, _selectedGoals, lightGreen)).toList(),
              ),

              const SizedBox(height: 30),
              Text("Health Conditions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 6),
              Text("Select any that apply so the AI can adjust daily limits.", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableHealthIssues.map((issue) => _buildChoiceChip(issue, _selectedHealthIssues, Colors.redAccent)).toList(),
              ),

              const SizedBox(height: 50),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: lightGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Complete Setup", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller, TextInputType type, bool isDark) {
    return TextField(
      controller: controller,
      keyboardType: type,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildChoiceChip(String label, List<String> selectedList, Color activeColor) {
    final isSelected = selectedList.contains(label);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (label == 'None' && selected) {
            selectedList.clear();
            selectedList.add('None');
          } else {
            if (label != 'None') selectedList.remove('None');
            if (selected) {
              selectedList.add(label);
            } else {
              selectedList.remove(label);
            }
          }
        });
      },
      selectedColor: activeColor.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? activeColor : (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade700),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.grey.shade200,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
