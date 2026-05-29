import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/theme_provider.dart';
import '../../services/user_service.dart';
import '../../services/notification_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/landing_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onHistoryDeleted;
  const SettingsScreen({super.key, this.onHistoryDeleted});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Mock Data
  String _name = "";
  String _email = "";
  String _height = "";
  String _weight = "";
  String? _goal;
  String _targetWeight = "";
  bool _isEditingProfile = false;
  bool _isEditingPreferences = false;

  List<dynamic> _customNotifications = [];
  String? _currentUserId;

  final Set<String> _healthConditions = {};
  final Set<String> _dietaryPrefs = {};
  final Set<String> _allergies = {};

  bool _waterReminder = false;
  String _waterTime = "08:00 AM";
  String _waterRepetition = "None";
  bool _mealReminder = false;
  String _mealTime = "01:00 PM";
  String _mealRepetition = "None";
  bool _workoutReminder = false;
  String _workoutTime = "06:00 PM";
  String _workoutRepetition = "None";
  String? _profilePicPath;

  ImageProvider? _getProfileImageProvider() {
    if (_profilePicPath == null || _profilePicPath!.isEmpty) return null;
    if (_profilePicPath!.startsWith('http://') || 
        _profilePicPath!.startsWith('https://') || 
        _profilePicPath!.startsWith('blob:')) {
      return NetworkImage(_profilePicPath!);
    }
    if (_profilePicPath!.startsWith('data:image') || _profilePicPath!.length > 500) {
      try {
        final base64Str = _profilePicPath!.contains(',') 
            ? _profilePicPath!.split(',').last 
            : _profilePicPath!;
        return MemoryImage(base64Decode(base64Str));
      } catch (e) {
        debugPrint("Error decoding base64 profile pic: $e");
        return null;
      }
    }
    if (kIsWeb) {
      return null;
    }
    return FileImage(File(_profilePicPath!));
  }

  Future<void> _pickProfilePicture() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 200,
        maxHeight: 200,
        imageQuality: 75,
      );
      if (image != null && _currentUserId != null) {
        final bytes = await image.readAsBytes();
        final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_pic_$_currentUserId', image.path);
        
        setState(() {
          _profilePicPath = base64Str;
        });
      }
    } catch (e) {
      debugPrint("Error picking profile image: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId != null) {
      _currentUserId = userId;
      final localPic = prefs.getString('profile_pic_$userId');
      final profile = await UserService.getProfile(userId);
      if (profile != null && mounted) {
        setState(() {
          _profilePicPath = (profile['user_profile'] != null && profile['user_profile'].toString().isNotEmpty)
              ? profile['user_profile']
              : localPic;
          _name = profile['name'] ?? "";
          _email = profile['email'] ?? "";
          _height = profile['height'] != null && profile['height'] != 0 ? profile['height'].toString() : "";
          _weight = profile['weight'] != null && profile['weight'] != 0 ? profile['weight'].toString() : "";
          _targetWeight = profile['target_weight'] != null && profile['target_weight'] != 0 ? profile['target_weight'].toString() : "";
          if (profile['goals'] != null && (profile['goals'] as List).isNotEmpty) {
            _goal = profile['goals'][0];
          }
          // Full lists matching onboarding
          const allHealthConditions = [
            "PCOS", "Diabetes", "Thyroid Disorders", "Obesity",
            "Hypertension", "Anemia", "High Cholesterol",
            "Digestive Issues", "Kidney Disease", "Eating Recovery"
          ];
          const allAllergies = [
            "Peanuts", "Tree Nuts", "Milk", "Eggs",
            "Wheat", "Soy", "Fish", "Shellfish", "Sesame", "Mustard"
          ];
          if (profile['health_issues'] != null) {
            _healthConditions.clear();
            _allergies.clear();
            for (String issue in profile['health_issues']) {
              if (allHealthConditions.contains(issue)) {
                _healthConditions.add(issue);
              } else if (allAllergies.contains(issue)) {
                _allergies.add(issue);
              }
            }
          }
          if (profile['dietary_preferences'] != null) {
            _dietaryPrefs.clear();
            for (String pref in profile['dietary_preferences']) {
               _dietaryPrefs.add(pref);
            }
          }
          _customNotifications = profile['custom_notifications'] ?? [];
        });
        NotificationScheduler.scheduleAll(_customNotifications);
      }
    }
  }

  String _formatTime12Hour(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    var hour12 = hour % 12;
    if (hour12 == 0) hour12 = 12;
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hour12:$minuteStr $period';
  }

  void _deleteHistory() {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          title: const Text("Delete Meal History 🗑️"),
          content: const Text(
              "Are you sure you want to permanently delete all logged meals and reset your health analytics? This action cannot be undone."),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (_currentUserId != null) {
                  final success = await UserService.deleteHistory(_currentUserId!);
                  if (success) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Meal history and analytics successfully reset!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                    if (widget.onHistoryDeleted != null) {
                      widget.onHistoryDeleted!();
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Failed to clear history. Please try again."),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text("Delete", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out? All local session data will be cleared."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Capture navigator before async gap
              final nav = Navigator.of(context);
              // Clear all scheduled notifications natively
              await NotificationScheduler.scheduleAll([]);
              
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('jwt_token');
              await prefs.remove('userId');
              await prefs.remove('activeTab');
              nav.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LandingScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Utilize provider for theme
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Container(
      color: isDarkMode ? const Color(0xFF111111) : const Color(0xFFFAF9F5),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120), // pb-24 equivalent
          children: [
            Text(
              "⚙️ Settings",
              style: TextStyle(
                fontSize: 34, 
                fontWeight: FontWeight.w900,
                color: isDarkMode ? Colors.white : const Color(0xFF1B3A1E),
                fontFamily: 'Cormorant',
              ),
            ),
            const SizedBox(height: 20),

            _buildProfileSection(isDarkMode),
            const SizedBox(height: 20),

            _buildPreferencesSection(isDarkMode),
            const SizedBox(height: 20),

            _buildNotificationsSection(isDarkMode),
            const SizedBox(height: 20),

            _buildAppearanceSection(themeProvider, isDarkMode),
            const SizedBox(height: 30),

            ElevatedButton.icon(
              onPressed: _deleteHistory,
              icon: const Icon(Icons.delete_forever_rounded, color: Colors.white),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              label: const Text("Clear Meal History & Analytics", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red.shade700,
                elevation: 0,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text("Log Out", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child, required bool isDark}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0x0C1B3A1E)),
        boxShadow: isDark ? null : [
          const BoxShadow(
            color: Color(0x0C1B3A1E),
            blurRadius: 20,
            offset: Offset(0, 8),
          )
        ],
      ),
      child: child,
    );
  }

  Widget _buildProfileSection(bool isDark) {
    return _buildCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Profile", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cormorant')),
              IconButton(
                icon: Icon(_isEditingProfile ? Icons.check : Icons.edit, color: const Color(0xFF4CAF50)),
                onPressed: () async {
                  if (_isEditingProfile) {
                     final prefs = await SharedPreferences.getInstance();
                     final userId = prefs.getString('userId');
                     if (userId != null) {
                        List<String> combinedHealthIssues = [];
                        combinedHealthIssues.addAll(_healthConditions);
                        combinedHealthIssues.addAll(_allergies);
                        
                        final success = await UserService.saveProfile({
                          'userId': userId,
                          'name': _name,
                          'height': double.tryParse(_height) ?? 0.0,
                          'weight': double.tryParse(_weight) ?? 0.0,
                          'target_weight': double.tryParse(_targetWeight) ?? 0.0,
                          'goals': _goal != null ? [_goal!] : [],
                          'health_issues': combinedHealthIssues,
                          'dietary_preferences': _dietaryPrefs.toList(),
                          'user_profile': _profilePicPath,
                          'notifications': {
                            'water': { 'isOn': _waterReminder, 'time': _waterTime, 'repeat': _waterRepetition },
                            'meal': { 'isOn': _mealReminder, 'time': _mealTime, 'repeat': _mealRepetition },
                            'workout': { 'isOn': _workoutReminder, 'time': _workoutTime, 'repeat': _workoutRepetition }
                          }
                        });

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success ? "Profile updated successfully! ✅" : "Failed to save profile ❌"),
                              backgroundColor: success ? Colors.green : Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                     }
                  }
                  setState(() { _isEditingProfile = !_isEditingProfile; });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: GestureDetector(
              onTap: () {
                if (_isEditingProfile) {
                  _pickProfilePicture();
                }
              },
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFF7CB342).withOpacity(0.12),
                    backgroundImage: _getProfileImageProvider(),
                    child: _getProfileImageProvider() == null
                        ? const Icon(Icons.person, size: 40, color: Color(0xFF7CB342))
                        : null,
                  ),
                  if (_isEditingProfile)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7CB342),
                          shape: BoxShape.circle,
                          border: Border.all(color: isDark ? const Color(0xFF2C2C2C) : Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildTextField("Full Name", _name, (v) => _name = v, isDark),
          _buildTextField("Email", _email, (v) => _email = v, isDark),
          Row(
            children: [
              Expanded(child: _buildTextField("Height (cm)", _height, (v) => _height = v, isDark)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField("Weight (kg)", _weight, (v) => _weight = v, isDark)),
            ],
          ),
          
          if (_isEditingProfile) ...[
            const SizedBox(height: 10),
            const Text("Goal", style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              key: ValueKey(_goal),
              value: _goal,
              decoration: _inputDecoration(isDark),
              items: ["Lose Weight", "Gain Weight", "Maintain Weight"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _goal = v!),
              dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            ),
            const SizedBox(height: 10),
          ] else ...[
            _buildTextField("Goal", _goal ?? "", (v) {}, isDark, enabled: false),
          ],

          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: (_goal == "Lose Weight" || _goal == "Gain Weight")
                ? _buildTextField("Target Weight (kg)", _targetWeight, (v) => _targetWeight = v, isDark)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(bool isDark) {
    return InputDecoration(
      filled: true,
      fillColor: isDark ? const Color(0xFF111111) : Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildTextField(String label, String value, Function(String) onChanged, bool isDark, {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
          const SizedBox(height: 6),
          TextFormField(
            key: ValueKey(value),
            initialValue: value,
            enabled: _isEditingProfile && enabled,
            onChanged: onChanged,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: _inputDecoration(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesSection(bool isDark) {
    return _buildCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Preferences", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cormorant')),
              IconButton(
                icon: Icon(_isEditingPreferences ? Icons.check : Icons.edit, color: const Color(0xFF4CAF50)),
                onPressed: () async {
                  if (_isEditingPreferences) {
                    final prefs = await SharedPreferences.getInstance();
                    final userId = prefs.getString('userId');
                    if (userId != null) {
                      List<String> combinedHealthIssues = [];
                      combinedHealthIssues.addAll(_healthConditions);
                      combinedHealthIssues.addAll(_allergies);
                      
                      await UserService.saveProfile({
                        'userId': userId,
                        'name': _name,
                        'height': double.tryParse(_height) ?? 0.0,
                        'weight': double.tryParse(_weight) ?? 0.0,
                        'target_weight': double.tryParse(_targetWeight) ?? 0.0,
                        'goals': _goal != null ? [_goal!] : [],
                        'health_issues': combinedHealthIssues,
                        'dietary_preferences': _dietaryPrefs.toList(),
                        'notifications': {
                          'water': { 'isOn': _waterReminder, 'time': _waterTime, 'repeat': _waterRepetition },
                          'meal': { 'isOn': _mealReminder, 'time': _mealTime, 'repeat': _mealRepetition },
                          'workout': { 'isOn': _workoutReminder, 'time': _workoutTime, 'repeat': _workoutRepetition }
                        }
                      });
                    }
                  }
                  setState(() { _isEditingPreferences = !_isEditingPreferences; });
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          _buildChipList(
            "Health Conditions",
            _healthConditions,
            Colors.purpleAccent,
            [
              "PCOS", "Diabetes", "Thyroid Disorders", "Obesity",
              "Hypertension", "Anemia", "High Cholesterol",
              "Digestive Issues", "Kidney Disease", "Eating Recovery"
            ],
            isDark,
          ),
          const SizedBox(height: 20),
          _buildChipList(
            "Dietary Preferences",
            _dietaryPrefs,
            const Color(0xFF7CB342),
            [
              "Vegetarian", "Vegan", "Pescatarian",
              "Keto", "Paleo", "Mediterranean",
              "Low Carb", "High Protein", "Gluten Free",
              "Dairy Free", "Halal", "Kosher"
            ],
            isDark,
          ),
          const SizedBox(height: 20),
          _buildChipList(
            "Allergies & Intolerances",
            _allergies,
            Colors.redAccent,
            [
              "Peanuts", "Tree Nuts", "Milk", "Eggs",
              "Wheat", "Soy", "Fish", "Shellfish", "Sesame", "Mustard"
            ],
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildChipList(String title, Set<String> selected, Color themeColor, List<String> options, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1B3A1E), fontSize: 15)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: options.map((opt) {
            final isSelected = selected.contains(opt);
            return GestureDetector(
              onTap: _isEditingPreferences
                  ? () {
                      setState(() {
                        if (opt == "None") {
                          selected.clear();
                          selected.add(opt);
                        } else {
                          selected.remove("None");
                          if (isSelected) {
                            selected.remove(opt);
                          } else {
                            selected.add(opt);
                          }
                        }
                      });
                    }
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? themeColor.withOpacity(0.08) : (isDark ? const Color(0xFF111111) : const Color(0xFFF0EFEA)),
                  border: Border.all(color: isSelected ? themeColor : (isDark ? Colors.white10 : Colors.grey.shade300)),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: isSelected && !isDark ? [
                    BoxShadow(
                      color: themeColor.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ] : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[Icon(Icons.check_circle_rounded, size: 14, color: themeColor), const SizedBox(width: 6)],
                    Text(opt, style: TextStyle(color: isSelected ? themeColor : (isDark ? Colors.white70 : const Color(0xFF5A6E5C)), fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                  ],
                ),
              ),
            );
          }).toList(),
        )
      ],
    );
  }

  Widget _buildNotificationsSection(bool isDark) {
    return _buildCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Notifications 🔔", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cormorant')),
              IconButton(
                icon: const Icon(Icons.add_alarm, color: Color(0xFF4CAF50)),
                onPressed: () => _showAddNotificationDialog(context),
                tooltip: "Add Custom Reminder",
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_customNotifications.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  "No reminders configured. Add one above! ⏰",
                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            ..._customNotifications.map((notif) {
              return _buildReminderRow(
                Map<String, dynamic>.from(notif),
                isDark,
              );
            }),
        ],
      ),
    );
  }

  void _showAddNotificationDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    String pickedTime = "08:00 AM";
    String selectedRepeat = "None";

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("New Reminder ⏰", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: "E.g. Drink Water, Walk",
                      labelText: "Reminder Name",
                      filled: true,
                      fillColor: isDark ? const Color(0xFF111111) : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Time:", style: TextStyle(fontWeight: FontWeight.w500)),
                      TextButton.icon(
                        icon: const Icon(Icons.access_time, color: Color(0xFF4CAF50)),
                        label: Text(pickedTime, style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          TimeOfDay? time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                          if (time != null) {
                            setDialogState(() {
                              pickedTime = _formatTime12Hour(time.hour, time.minute);
                            });
                          }
                        },
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Repeat:", style: TextStyle(fontWeight: FontWeight.w500)),
                      DropdownButton<String>(
                        value: selectedRepeat,
                        underline: const SizedBox(),
                        dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                        items: ["None", "30 min", "1 hour", "2 hours"].map((val) {
                          return DropdownMenuItem<String>(
                            value: val,
                            child: Text(val, style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedRepeat = val;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    if (title.isNotEmpty && _currentUserId != null) {
                      Navigator.pop(ctx);
                      final success = await UserService.addCustomNotification(
                        _currentUserId!, 
                        title, 
                        pickedTime,
                        repeat: selectedRepeat,
                      );
                      if (success) {
                        _loadProfile();
                      }
                    }
                  },
                  child: const Text("Add", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildReminderRow(Map<String, dynamic> notif, bool isDark) {
    final String id = notif['_id'] ?? '';
    final String title = notif['title'] ?? 'Reminder';
    final bool isOn = notif['isOn'] ?? false;
    final String time = notif['time'] ?? '08:00 AM';
    final String repeat = notif['repeat'] ?? 'None';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              children: [
                Switch(
                  value: isOn,
                  activeTrackColor: const Color(0xFF4CAF50).withOpacity(0.5),
                  activeColor: const Color(0xFF4CAF50),
                  onChanged: (val) async {
                    if (_currentUserId != null) {
                      if (val == true) {
                        TimeOfDay? timeOfDay = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (timeOfDay != null) {
                          final formattedTime = _formatTime12Hour(timeOfDay.hour, timeOfDay.minute);
                          final success = await UserService.updateCustomNotification(
                            _currentUserId!, 
                            id, 
                            isOn: true, 
                            time: formattedTime,
                          );
                          if (success) {
                            _loadProfile();
                          }
                        }
                      } else {
                        final success = await UserService.updateCustomNotification(
                          _currentUserId!, 
                          id, 
                          isOn: false,
                        );
                        if (success) {
                          _loadProfile();
                        }
                      }
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: () async {
                    if (_currentUserId != null) {
                      final success = await UserService.deleteCustomNotification(_currentUserId!, id);
                      if (success) {
                        _loadProfile();
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        if (isOn) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Time:", style: TextStyle(color: Colors.grey, fontSize: 13)),
              TextButton.icon(
                onPressed: () async {
                  TimeOfDay? timeOfDay = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (timeOfDay != null && _currentUserId != null) {
                    final formattedTime = _formatTime12Hour(timeOfDay.hour, timeOfDay.minute);
                    final success = await UserService.updateCustomNotification(_currentUserId!, id, time: formattedTime);
                    if (success) {
                      _loadProfile();
                    }
                  }
                },
                icon: const Icon(Icons.access_time, size: 16, color: Color(0xFF4CAF50)),
                label: Text(time, style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF4CAF50)),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Repeat:", style: TextStyle(color: Colors.grey, fontSize: 13)),
              DropdownButton<String>(
                value: ["None", "30 min", "1 hour", "2 hours"].contains(repeat) ? repeat : "None",
                underline: const SizedBox(),
                dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                items: ["None", "30 min", "1 hour", "2 hours"].map((val) {
                  return DropdownMenuItem<String>(
                    value: val,
                    child: Text(val, style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold)),
                  );
                }).toList(),
                onChanged: (val) async {
                  if (val != null && _currentUserId != null) {
                    final success = await UserService.updateCustomNotification(_currentUserId!, id, repeat: val);
                    if (success) {
                      _loadProfile();
                    }
                  }
                },
              ),
            ],
          ),
        ],
        const Divider(),
      ],
    );
  }

  Widget _buildAppearanceSection(ThemeProvider themeProvider, bool isDark) {
    return _buildCard(
      isDark: isDark,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.dark_mode_outlined),
              SizedBox(width: 12),
              Text("Dark Mode", style: TextStyle(fontSize: 16,fontFamily:"Cormorant", fontWeight: FontWeight.bold)),
            ],
          ),
          Switch(
            value: isDark,
            activeColor: const Color(0xFF7CB342),
            activeTrackColor: const Color(0xFF7CB342).withOpacity(0.5),
            onChanged: (val) {
              themeProvider.toggleTheme(val);
            },
          ),
        ],
      ),
    );
  }
}
