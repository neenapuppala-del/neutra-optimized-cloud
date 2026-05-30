import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final data = await ApiService.getHistory();
    if (mounted) {
      setState(() {
        _history = data ?? [];
        _isLoading = false;
      });
    }
  }

  double _getNutrientVal(Map<String, dynamic>? nutrients, List<String> possibleKeys) {
    if (nutrients == null) return 0.0;
    for (var key in nutrients.keys) {
      final lowerKey = key.toLowerCase();
      if (possibleKeys.any((pk) => lowerKey.contains(pk))) {
        final val = nutrients[key];
        if (val == null) continue;
        if (val is num) return val.toDouble();
        final parsed = double.tryParse(val.toString().replaceAll(RegExp(r'[^0-9.]'), ''));
        if (parsed != null) return parsed;
      }
    }
    return 0.0;
  }

  void _showMealDetails(BuildContext context, String title, String calories, bool isDark, String realTime, Map<String, dynamic>? nutrients) {
    final protein = _getNutrientVal(nutrients, ["protein", "prot"]);
    final carbs = _getNutrientVal(nutrients, ["carbohydrate", "carb"]);
    final fats = _getNutrientVal(nutrients, ["fat"]);

    final total = protein + carbs + fats;
    final proteinPercentage = total > 0 ? protein / total : 0.0;
    final carbsPercentage = total > 0 ? carbs / total : 0.0;
    final fatsPercentage = total > 0 ? fats / total : 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFAF9F5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                title,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                "Logged at $realTime.",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total Calories", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(calories, style: const TextStyle(fontSize: 22, color: Color(0xFF7CB342), fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(height: 30),
              const Text("Macro Breakdown", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildMacroBar("Protein", proteinPercentage, Colors.purple.shade300, "${protein.round()}g", isDark),
              _buildMacroBar("Carbs", carbsPercentage, Colors.orange.shade400, "${carbs.round()}g", isDark),
              _buildMacroBar("Fats", fatsPercentage, const Color(0xFF7CB342), "${fats.round()}g", isDark),
              const SizedBox(height: 30),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
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
                  child: const Center(
                    child: Text("Close", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildMacroBar(String name, double percentage, Color color, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
            color: color,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF000000) : const Color(0xFFFAF9F5),
      child: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF7CB342)))
            : ListView(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
                children: [
                  Text(
                    "🧾 History",
                    style: TextStyle(
                      fontSize: 34, 
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1B3A1E),
                      fontFamily: 'Cormorant',
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_history.isEmpty)
                    const Center(child: Text("No history available yet."))
                  else
                    ..._buildHistoryGroups(isDark),
                ],
              ),
      ),
    );
  }

  List<Widget> _buildHistoryGroups(bool isDark) {
    if (_history.isEmpty) return [];

    // Group by date
    Map<String, List<dynamic>> grouped = {};
    for (var item in _history) {
      final dateStr = item['date'] as String?;
      if (dateStr == null) continue;
      final date = DateTime.parse(dateStr).toLocal();
      final formatter = DateFormat('MMM dd, yyyy');
      final key = formatter.format(date);
      grouped.putIfAbsent(key, () => []).add(item);
    }

    List<Widget> widgets = [];
    grouped.forEach((dateKey, items) {
      widgets.add(
        _buildDayGroup(dateKey, isDark, items.asMap().entries.map((entry) {
          final index = entry.key;
          final meal = entry.value;
          final isLast = index == items.length - 1;
          final timeFormatter = DateFormat('h:mm a');
          final time = timeFormatter.format(DateTime.parse(meal['date']).toLocal());
          return _buildTimelineItem(
            context,
            time,
            _formatName(meal['dishName'] ?? "Meal"),
            "${meal['nutrients']?['Calories (kcal)']?.toStringAsFixed(0) ?? '0'} kcal",
            Icons.fastfood_rounded,
            const Color(0xFF7CB342),
            isDark,
            isLast: isLast,
            meal: meal,
          );
        }).toList()),
      );
      widgets.add(const SizedBox(height: 16));
    });
    return widgets;
  }

  Widget _buildDayGroup(String day, bool isDark, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDark ? null : [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 5,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Text(
            day,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF7CB342),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...items,
      ],
    );
  }

  Widget _buildTimelineItem(BuildContext context, String time, String title, String calories, IconData icon, Color iconColor, bool isDark, {bool isLast = false, required dynamic meal}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Column
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: iconColor.withOpacity(0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withOpacity(0.1),
                        blurRadius: 8,
                      )
                    ],
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                    ),
                  )
              ],
            ),
          ),
          const SizedBox(width: 12),
          
          // Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: GestureDetector(
                onTap: () => _showMealDetails(context, title, calories, isDark, time, meal['nutrients'] as Map<String, dynamic>?),
                child: Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        time,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7CB342).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              calories,
                              style: const TextStyle(color: Color(0xFF7CB342), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
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
}
