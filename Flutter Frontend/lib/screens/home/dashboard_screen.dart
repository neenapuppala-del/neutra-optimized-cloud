import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/user_service.dart';

class Modification {
  String type;
  String targetIngredient;
  String newIngredient;
  double quantity;
  String unit;

  Modification({
    required this.type,
    this.targetIngredient = '',
    this.newIngredient = '',
    this.quantity = 0,
    this.unit = 'g',
  });
}

class DishData {
  String name;
  String matchedName;
  String imagePath;
  double portionQuantity;
  String portionUnit;
  List<Modification> modifications;

  DishData({
    required this.name,
    this.matchedName = '',
    this.imagePath = '',
    this.portionQuantity = 1,
    this.portionUnit = 'serves',
    List<Modification>? modifications,
  }) : modifications = modifications ?? [];
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _step = 0;

  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  List<DishData> _dishes = [];
  String _sessionId = "";
  Map<String, dynamic> _finalNutrients = {};
  int _calculatedHealthScore = 0;

  List<Map<String, dynamic>> _completedMeals = [];
  int _dailyAverageScore = 0;
  
  int _dailyCalories = 0;
  int _dailyProtein = 0;
  int _dailyCarbs = 0;
  int _dailyFats = 0;

  List<dynamic> _suggestions = [];
  String _userName = "Healthy User";
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _loadDailyStats();
  }

  Future<void> _loadDailyStats() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId != null) {
      final profile = await UserService.getProfile(userId);
      if (profile != null && profile['name'] != null && profile['name'].toString().isNotEmpty) {
        setState(() {
          _userName = profile['name'];
        });
      }
    }

    final stats = await ApiService.getDailyStats();
    if (stats != null) {
      setState(() {
        _dailyAverageScore = stats['averageScore'] ?? 0;
        _dailyCalories = stats['totalCalories'] ?? 0;
        _dailyProtein = stats['totalProtein'] ?? 0;
        _dailyCarbs = stats['totalCarbs'] ?? 0;
        _dailyFats = stats['totalFats'] ?? 0;
        _completedMeals = (stats['meals'] as List).map((m) => {
          'name': m['dishName'],
          'score': m['healthScore'],
        }).toList();
      });
    }
  }

  void _pickImageSource() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Library'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      }
    );
  }

  void _showScanBottomSheet(BuildContext context, bool isDark, Color textColor, Color lightGreen) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFAF9F5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0x0C1B3A1E)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Scan Your Meal 📸",
                style: TextStyle(
                  fontSize: 22,
                  fontFamily: "Cormorant",
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Snap a picture of your dish to calculate nutrients and health score instantly.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  height: 1.4,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImageSource();
                },
                child: Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8BC34A), Color(0xFF2E7D32)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2E7D32).withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text(
                        "Add Photo",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final List<XFile> images = await _picker.pickMultiImage();
        if (images.isNotEmpty) {
          setState(() {
            _selectedImages.addAll(images);
            _step = 5;
          });
        }
      } else {
        final XFile? image = await _picker.pickImage(source: source);
        if (image != null) {
          setState(() {
            _selectedImages.add(image);
            _step = 5;
          });
        }
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  void _startScanning() async {
    if (_selectedImages.isEmpty) return;

    setState(() {
      _step = 1;
    });

    try {
      List<List<int>> multipleImageBytes = [];
      List<String> filenames = [];

      for (var file in _selectedImages) {
        final bytes = await file.readAsBytes();
        multipleImageBytes.add(bytes);
        filenames.add(file.name);
      }

      var result = await ApiService.detectFood(multipleImageBytes, filenames);

      if (mounted) {
        setState(() {
          if (result != null && result['detected_dishes'] != null) {
            _sessionId = result['session_id'] ?? "test";
            final nutrientsMap = result['nutrients_per_100g'] as Map<String, dynamic>? ?? {};
            _dishes = (result['detected_dishes'] as List).map<DishData>((d) {
              final rawName = d['name'] ?? 'unknown meal';
              final matchedName = nutrientsMap[rawName]?['matched_name'] ?? '';
              final int regionId = d['region_id'] ?? 1;
              final String localPath = (regionId > 0 && regionId <= _selectedImages.length)
                  ? _selectedImages[regionId - 1].path
                  : '';
              return DishData(
                name: rawName,
                matchedName: matchedName,
                imagePath: localPath,
                portionQuantity: 1,
                portionUnit: 'serves',
                modifications: [],
              );
            }).toList();
          } else {
            _dishes = [];
          }
          _step = 2;
        });
      }
    } catch (e) {
      debugPrint("Error scanning: $e");
      if (mounted) {
        setState(() {
          _step = 5;
        });
      }
    }
  }

  void _removeDish(int index) {
    setState(() => _dishes.removeAt(index));
  }

  void _addModification(int dishIndex) {
    setState(() => _dishes[dishIndex].modifications.add(
      Modification(type: 'Replace', targetIngredient: '', newIngredient: '', quantity: 1, unit: 'tbsp'),
    ));
  }

  void _removeModification(int dishIndex, int modIndex) {
    setState(() => _dishes[dishIndex].modifications.removeAt(modIndex));
  }

  void _proceedToNutrition() async {
    setState(() => _step = 1);

    var payload = {
      "session_id": _sessionId,
      "detected_dishes": _dishes.map((d) => d.name).toList(),
      "portions": _dishes.map((d) => {
        "dish_name": d.name,
        "amount": d.portionQuantity,
        "unit": d.portionUnit,
      }).toList(),
      "modifications": _dishes.expand((d) => d.modifications.map((m) => {
        "action": m.type,
        "dish_name": d.name,
        "new_item": m.newIngredient,
        "original_item": m.targetIngredient,
        "amount": m.quantity,
        "unit": m.unit,
      })).toList(),
      "user_profile": {}
    };

    var result = await ApiService.calculateNutrition(payload);

    if (mounted) {
      setState(() {
        if (result != null && result['health_score'] != null) {
          _calculatedHealthScore = result['health_score']['score'] ?? 0;
          _finalNutrients = result['final_nutrients']?['nutrients'] ?? {};
          if (result['suggestions'] != null) {
            _suggestions = result['suggestions'];
          } else {
            _suggestions = [];
          }
        }
        _step = 3;
      });
    }
  }

  void _viewRecommendations() => setState(() => _step = 4);

  void _completeFlow() async {
    if (_isCompleting) return;
    setState(() {
      _isCompleting = true;
    });

    final dishName = _dishes.isNotEmpty ? _dishes.map((d) => d.name).join(", ") : "Meal";
    
    try {
      // Log meal to backend
      await ApiService.logMeal(dishName, _calculatedHealthScore, _finalNutrients);

      // Refresh stats
      await _loadDailyStats();
    } catch (e) {
      debugPrint("Error completing flow: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isCompleting = false;
          _step = 0;
          _selectedImages.clear();
          _dishes = [];
        });
      }
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 75) return Colors.greenAccent;
    if (score >= 40) return Colors.orange;
    return Colors.redAccent;
  }

  String _formatName(String raw) {
    if (raw.isEmpty) return "";
    return raw
        .split(',')
        .map((part) {
          final trimmed = part.trim();
          if (trimmed.isEmpty) return "";
          return trimmed
              .replaceAll('_', ' ')
              .replaceAll('-', ' ')
              .split(' ')
              .map((word) => word.isEmpty ? "" : "${word[0].toUpperCase()}${word.substring(1)}")
              .join(' ');
        })
        .where((part) => part.isNotEmpty)
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1B3A1E);
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFFAF9F5);
    const lightGreen = Color(0xFF7CB342);

    return Container(
      color: bgColor,
      child: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "🍽️ Home",
                    style: TextStyle(
                      fontSize: 34, 
                      color: textColor, 
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Cormorant',
                    ),
                  ),
                  if (_step == 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF8BC34A).withOpacity(0.5),
                            const Color(0xFF2E7D32).withOpacity(0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2E7D32).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        "Welcome, $_userName ✨",
                        style: const TextStyle(
                          fontSize: 26,
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Cormorant',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 24, left: 20, right: 20, bottom: 120),
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _buildCurrentStep(isDark, textColor, lightGreen, bgColor),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      if (_step == 0)
        Positioned(
          bottom: 96,
          right: 20,
          child: FloatingActionButton(
            onPressed: () => _showScanBottomSheet(context, isDark, textColor, lightGreen),
            backgroundColor: lightGreen,
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 24),
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep(bool isDark, Color textColor, Color lightGreen, Color bgColor) {
    switch (_step) {
      case 0:
        return Column(
          key: const ValueKey(0),
          children: [
            _buildDailyAverageScore(isDark, textColor, lightGreen),
            const SizedBox(height: 16),
            _buildDailyIntakeCard(isDark, textColor, lightGreen),
            const SizedBox(height: 24),
            ..._completedMeals.map((meal) => _buildMealScoreCard(meal, isDark, textColor)),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _showDailyReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: lightGreen,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text("Get Daily Review", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        );
      case 1:
        return _buildAnalyzingStep(textColor, lightGreen);
      case 2:
        return _buildPortionsAndModificationsStep(isDark, textColor, lightGreen);
      case 3:
        return _buildNutritionStep(isDark, textColor, lightGreen);
      case 4:
        return _buildRecommendationsStep(isDark, textColor, lightGreen);
      case 5:
        return _buildImageSelectionPreviewStep(isDark, textColor, lightGreen);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDailyAverageScore(bool isDark, Color textColor, Color lightGreen) {
    return _buildCard(
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Today's Average", style: TextStyle(color: isDark ? Colors.grey.shade400 : const Color(0xFF5A6E5C), fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text("Health Score", style: TextStyle(color: textColor,fontFamily:"Cormorant",fontWeight: FontWeight.w800, fontSize: 20)),
            ],
          ),
          SizedBox(
            height: 70,
            width: 70,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: PremiumProgressPainter(
                    progress: _dailyAverageScore / 100.0,
                    trackColor: isDark ? Colors.white10 : const Color(0xFFE2E2D9),
                    gradientColors: [
                      const Color(0xFF8BC34A),
                      _getScoreColor(_dailyAverageScore),
                      const Color(0xFF2E7D32),
                    ],
                  ),
                ),
                Center(
                  child: Text(
                    "$_dailyAverageScore",
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      isDark,
    );
  }

  Widget _buildDailyIntakeCard(bool isDark, Color textColor, Color lightGreen) {
    final numberStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w900,
      color: textColor,
    );
    final labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.grey.shade400 : const Color(0xFF5A6E5C),
    );

    return _buildCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Color(0xFF7CB342), size: 20),
              const SizedBox(width: 8),
              Text(
                "Today's Nutrition Summary",
                style: TextStyle(
                  color: textColor,
                  fontFamily: "Cormorant",
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildIntakeMetric("Energy", "$_dailyCalories", "kcal", Colors.orange.shade400, numberStyle, labelStyle),
              _buildIntakeMetric("Protein", "$_dailyProtein", "g", Colors.purple.shade300, numberStyle, labelStyle),
              _buildIntakeMetric("Carbs", "$_dailyCarbs", "g", Colors.blue.shade400, numberStyle, labelStyle),
              _buildIntakeMetric("Fats", "$_dailyFats", "g", const Color(0xFF7CB342), numberStyle, labelStyle),
            ],
          ),
        ],
      ),
      isDark,
    );
  }

  Widget _buildIntakeMetric(
    String label,
    String value,
    String unit,
    Color indicatorColor,
    TextStyle numberStyle,
    TextStyle labelStyle,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: indicatorColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value, style: numberStyle),
                  const SizedBox(width: 2),
                  Text(unit, style: TextStyle(fontSize: 10, color: indicatorColor, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: indicatorColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: labelStyle),
      ],
    );
  }

  void _showDailyReview() async {
    final reviewData = await ApiService.getDailyReview();
    if (reviewData != null && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("End of Day Review"),
          content: Text(reviewData['review'] ?? "No review available."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            )
          ],
        ),
      );
    }
  }

  Widget _buildCard(Widget child, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0x0C1B3A1E)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF2E7D32).withOpacity(0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: child,
    );
  }

  Widget _buildImageSelectionPreviewStep(bool isDark, Color textColor, Color lightGreen) {
    return Column(
      key: const ValueKey(5),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () {
                setState(() {
                  _selectedImages.clear();
                  _step = 0;
                });
              },
            ),
            const SizedBox(width: 8),
            Text(
              "Review Food Items",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor, fontFamily: 'Cormorant'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          "Verify the captured items. Delete any accidental frames or add more pictures.",
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        ),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.0,
          ),
          itemCount: _selectedImages.length,
          itemBuilder: (context, index) {
            final image = _selectedImages[index];
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    kIsWeb
                        ? Image.network(image.path, fit: BoxFit.cover)
                        : Image.file(File(image.path), fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedImages.removeAt(index);
                            if (_selectedImages.isEmpty) {
                              _step = 0;
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: Icon(Icons.add_a_photo, color: lightGreen),
                label: Text("Take Photo", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: lightGreen, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: Icon(Icons.photo_library, color: lightGreen),
                label: Text("Add Gallery", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: lightGreen, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _selectedImages.isEmpty ? null : _startScanning,
          style: ElevatedButton.styleFrom(
            backgroundColor: lightGreen,
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                "Scan ${_selectedImages.length} Food Item${_selectedImages.length > 1 ? 's' : ''}",
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMealScoreCard(Map<String, dynamic> meal, bool isDark, Color textColor) {
    final score = meal['score'] as int;
    final scoreColor = _getScoreColor(score);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _buildCard(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: scoreColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          score >= 75 ? "Excellent 🥦" : (score >= 40 ? "Moderate ⚖️" : "Critical ⚠️"),
                          style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatName(meal['name']),
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 60,
              width: 60,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: PremiumProgressPainter(
                      progress: score / 100.0,
                      trackColor: isDark ? Colors.white10 : const Color(0xFFE2E2D9),
                      gradientColors: [
                        const Color(0xFF8BC34A),
                        scoreColor,
                        const Color(0xFF2E7D32),
                      ],
                    ),
                  ),
                  Center(
                    child: Text(
                      "$score",
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        isDark,
      ),
    );
  }

  Widget _buildAnalyzingStep(Color textColor, Color lightGreen) {
    return Column(
      key: const ValueKey(1),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        if (_selectedImages.isNotEmpty)
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                final image = _selectedImages[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: kIsWeb
                        ? Image.network(image.path, width: 150, height: 150, fit: BoxFit.cover)
                        : Image.file(File(image.path), width: 150, height: 150, fit: BoxFit.cover),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 30),
        CircularProgressIndicator(color: lightGreen),
        const SizedBox(height: 20),
        Text("Analyzing your ${_selectedImages.length} food items...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
      ],
    );
  }

  Widget _buildPortionsAndModificationsStep(bool isDark, Color textColor, Color lightGreen) {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () {
                setState(() {
                  _step = 5;
                });
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Portions & Modifications",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor, fontFamily: 'Cormorant'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.scale_rounded, color: Color(0xFF7CB342), size: 26),
              onPressed: () => _showUnitConversionsDialog(context, isDark),
              tooltip: "Unit Scale Guide",
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          "Set portion size for each item. Optionally add, replace, or remove ingredients.",
          style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 14),
        ),
        const SizedBox(height: 20),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _dishes.length,
          itemBuilder: (context, index) => _buildDishCard(index, isDark, textColor, lightGreen),
        ),
        if (_dishes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text("No dishes detected.", style: TextStyle(color: Colors.grey))),
          ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _dishes.isEmpty ? null : _proceedToNutrition,
          style: ElevatedButton.styleFrom(
            backgroundColor: lightGreen,
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text(
            "Proceed for Nutrients",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  void _showUnitConversionsDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) {
        final textColor = isDark ? Colors.white : const Color(0xFF1B3A1E);
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFAF9F5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.scale_rounded, color: Color(0xFF7CB342), size: 28),
              const SizedBox(width: 10),
              Text(
                "Unit Scale Guide",
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Here is how our AI converts each portion unit into grams (g) or milliliters (ml) for accurate nutrient calculations:",
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, height: 1.4),
                ),
                const SizedBox(height: 18),
                _buildUnitGuideRow("1 serve (serves)", "150 grams", isDark),
                _buildUnitGuideRow("1 bowl (bowls)", "250 grams", isDark),
                _buildUnitGuideRow("1 cup", "240 grams / ml", isDark),
                _buildUnitGuideRow("1 tbsp (tablespoon)", "15 grams / ml", isDark),
                _buildUnitGuideRow("1 tsp (teaspoon)", "5 grams / ml", isDark),
                _buildUnitGuideRow("1 gram (g / grams)", "1 gram", isDark),
                _buildUnitGuideRow("1 milliliter (ml)", "1 ml", isDark),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Got it! 👍",
                style: TextStyle(color: Color(0xFF7CB342), fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUnitGuideRow(String unitName, String equivalent, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(unitName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF7CB342).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              equivalent,
              style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDishCard(int dishIndex, bool isDark, Color textColor, Color lightGreen) {
    final dish = _dishes[dishIndex];
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: _buildCard(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (dish.imagePath.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb
                              ? Image.network(dish.imagePath, width: 60, height: 60, fit: BoxFit.cover)
                              : Image.file(File(dish.imagePath), width: 60, height: 60, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          _formatName(dish.name),
                          style: TextStyle(fontSize: 20, color: textColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => _removeDish(dishIndex),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text("Portion size", style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
                const Spacer(),
                SizedBox(
                  width: 80,
                  child: _buildInputField(
                    dish.portionQuantity.toString().replaceAll(RegExp(r'\.0$'), ''),
                    isDark,
                    textColor,
                    "Qty",
                    keyboardType: TextInputType.number,
                    onChanged: (val) => dish.portionQuantity = double.tryParse(val) ?? 1,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: _buildDropdown(
                    dish.portionUnit,
                    ["serves", "grams", "g", "ml", "bowls", "cup", "tbsp", "tsp"],
                    isDark,
                    textColor,
                    (val) => setState(() => dish.portionUnit = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  "MODIFICATIONS",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "OPTIONAL",
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dish.modifications.length,
              itemBuilder: (context, modIndex) => _buildModificationRow(dishIndex, modIndex, isDark, textColor),
            ),
            InkWell(
              onTap: () => _addModification(dishIndex),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  "+ Add / Replace / Remove Ingredient",
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
        isDark,
      ),
    );
  }

  Widget _buildModificationRow(int dishIndex, int modIndex, bool isDark, Color textColor) {
    final mod = _dishes[dishIndex].modifications[modIndex];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            child: _buildDropdown(
              mod.type,
              ["Replace", "Remove", "Add"],
              isDark,
              textColor,
              (val) => setState(() => mod.type = val!),
            ),
          ),
          const SizedBox(width: 4),
          if (mod.type == "Replace") ...[
            Expanded(
              child: _buildInputField(mod.targetIngredient, isDark, textColor, "Original",
                  onChanged: (val) => mod.targetIngredient = val),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildInputField(mod.newIngredient, isDark, textColor, "New",
                  onChanged: (val) => mod.newIngredient = val),
            ),
          ] else if (mod.type == "Remove") ...[
            Expanded(
              flex: 2,
              child: _buildInputField(mod.targetIngredient, isDark, textColor, "Ingredient to remove",
                  onChanged: (val) => mod.targetIngredient = val),
            ),
          ] else if (mod.type == "Add") ...[
            Expanded(
              flex: 2,
              child: _buildInputField(mod.newIngredient, isDark, textColor, "Ingredient (e.g. Ghee)",
                  onChanged: (val) => mod.newIngredient = val),
            ),
          ],
          const SizedBox(width: 4),
          SizedBox(
            width: 45,
            child: _buildInputField(
              mod.quantity == 0 ? "" : mod.quantity.toString().replaceAll(RegExp(r'\.0$'), ''),
              isDark,
              textColor,
              "Qty",
              keyboardType: TextInputType.number,
              onChanged: (val) => mod.quantity = double.tryParse(val) ?? 0,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 60,
            child: _buildDropdown(
              mod.unit,
              ["tbsp", "g", "ml", "cup", "tsp", "grams", "bowls", "serves"],
              isDark,
              textColor,
              (val) => setState(() => mod.unit = val!),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _removeModification(dishIndex, modIndex),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(
    String initialValue,
    bool isDark,
    Color textColor,
    String hint, {
    TextInputType? keyboardType,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: keyboardType,
      style: TextStyle(color: textColor, fontSize: 13),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        filled: true,
        fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildDropdown(
    String value,
    List<String> items,
    bool isDark,
    Color textColor,
    Function(String?) onChanged,
  ) {
    if (!items.contains(value)) items.add(value);
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down, size: 16),
      dropdownColor: isDark ? const Color(0xFF3C3C3C) : Colors.white,
      style: TextStyle(color: textColor, fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        filled: true,
        fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
      items: items
          .map((unit) => DropdownMenuItem(
                value: unit,
                child: Text(unit, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildNutritionStep(bool isDark, Color textColor, Color lightGreen) {
    final scoreColor = _getScoreColor(_calculatedHealthScore);
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () {
                setState(() {
                  _step = 2;
                });
              },
            ),
            const SizedBox(width: 8),
            Text(
              "Nutrition Details",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor, fontFamily: 'Cormorant'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildCard(
          Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _dishes.isNotEmpty ? _dishes.map((d) => _formatName(d.name)).join(", ") : "Meal",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "${_finalNutrients['Calories (kcal)']?.toStringAsFixed(0) ?? '0'} kcal",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: lightGreen),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ..._finalNutrients.entries.where((e) => e.key != 'Calories (kcal)' && e.key != 'Calories').map((entry) {
                return _buildNutrientRow(
                  "🔹 ${entry.key}",
                  (entry.value is num ? (entry.value as num).toStringAsFixed(1) : entry.value.toString()),
                  true,
                  textColor,
                );
              }),
              const SizedBox(height: 30),
              SizedBox(
                height: 120,
                width: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: _calculatedHealthScore / 100,
                      backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                      color: scoreColor,
                      strokeWidth: 10,
                    ),
                    Center(
                      child: Text(
                        "$_calculatedHealthScore",
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: scoreColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text("Health Score", style: TextStyle(fontSize: 18, color: textColor, fontWeight: FontWeight.bold)),
            ],
          ),
          isDark,
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _viewRecommendations,
          style: ElevatedButton.styleFrom(
            backgroundColor: lightGreen,
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text(
            "View Recommendations",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildNutrientRow(String name, String value, bool isOptimal, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor)),
              const SizedBox(width: 8),
              if (!isOptimal) const Icon(Icons.warning, color: Colors.orange, size: 16),
            ],
          ),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isOptimal ? textColor : Colors.orange),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsStep(bool isDark, Color textColor, Color lightGreen) {
    return Column(
      key: const ValueKey(4),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () {
                setState(() {
                  _step = 3;
                });
              },
            ),
            const SizedBox(width: 8),
            Text(
              "AI Insights",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor, fontFamily: 'Cormorant'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_suggestions.isEmpty)
          const Text("No insights available for this meal.", style: TextStyle(color: Colors.grey)),
        ..._suggestions.map((sugg) {
          Color cardColor;
          IconData icon;
          if (sugg['type'] == 'positive') {
            cardColor = Colors.green;
            icon = Icons.thumb_up;
          } else if (sugg['type'] == 'warning') {
            cardColor = Colors.orange;
            icon = Icons.warning;
          } else {
            cardColor = Colors.blue;
            icon = Icons.info_outline;
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildRecommendationCard(
              sugg['title'] ?? 'Insight',
              sugg['description'] ?? '',
              cardColor,
              icon,
              textColor,
            ),
          );
        }),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isCompleting ? null : _completeFlow,
          style: ElevatedButton.styleFrom(
            backgroundColor: lightGreen,
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _isCompleting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  "Complete",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(String title, String desc, Color color, IconData icon, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(desc, style: TextStyle(height: 1.4, color: textColor.withOpacity(0.8))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumProgressPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color trackColor;
  final List<Color> gradientColors;

  PremiumProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 8) / 2;

    // 1. Draw track
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, trackPaint);

    // 2. Draw active sweep with gradient
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final activePaint = Paint()
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..shader = SweepGradient(
          colors: gradientColors,
          startAngle: -3.14159265 / 2,
          endAngle: 3 * 3.14159265 / 2,
        ).createShader(rect);

      // Sweep angle in radians
      double sweepAngle = progress * 2 * 3.14159265;
      canvas.drawArc(rect, -3.14159265 / 2, sweepAngle > 2 * 3.14159265 ? 2 * 3.14159265 : sweepAngle, false, activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}