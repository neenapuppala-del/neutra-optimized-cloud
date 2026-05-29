import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = true;
  int _avgDailyCalories = 0;
  int _daysLoggedThisWeek = 0;
  int _proteinAvg = 0;
  List<int> _weeklyCalories = [0, 0, 0, 0, 0, 0, 0];
  List<int> _proteinTrend = [0, 0, 0, 0, 0, 0, 0];
  Map<String, int> _macroDistribution = {'protein': 0, 'carbs': 0, 'fats': 0};

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    final data = await ApiService.getWeeklyAnalytics();
    if (data != null && mounted) {
      setState(() {
        _avgDailyCalories = data['avgDailyCalories'] ?? 0;
        _daysLoggedThisWeek = data['daysLoggedThisWeek'] ?? 0;
        _proteinAvg = data['proteinAvg'] ?? 0;
        
        if (data['macroDistribution'] != null) {
          _macroDistribution = Map<String, int>.from(data['macroDistribution']);
        }
        
        if (data['proteinTrend'] != null) {
          _proteinTrend = List<int>.from(data['proteinTrend']);
        }
        
        if (data['weeklyCalories'] != null) {
          _weeklyCalories = List<int>.from(data['weeklyCalories']);
        }
        
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Core colors representing Dark/Light "white & green" / "black & green"
    final Color bgColor = isDark ? Colors.black : const Color(0xFFFAF9F5);
    final Color cardColor = isDark ? const Color(0xFF111111) : Colors.white;
    final Color txtColor = isDark ? Colors.white : const Color(0xFF1B3A1E);
    final Color accentColor = const Color(0xFF7CB342); // Green
    
    if (_isLoading) {
      return Container(
        color: bgColor,
        child: Center(child: CircularProgressIndicator(color: accentColor)),
      );
    }

    // Calculate max value for calorie chart normalization
    int maxCal = _weeklyCalories.isNotEmpty ? _weeklyCalories.reduce((curr, next) => curr > next ? curr : next) : 0;
    if (maxCal == 0) maxCal = 1; // avoid division by zero

    return Container(
      color: bgColor,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
          children: [
            Text(
              "◔ Analytics",
              style: TextStyle(
                fontSize: 34, 
                fontWeight: FontWeight.w900,
                color: txtColor,
                fontFamily: 'Cormorant',
              ),
            ),
            const SizedBox(height: 30),
            
            // Stat Cards
            _buildStatCard("Avg Daily Calories", "$_avgDailyCalories", "Based on last 7 days", Icons.show_chart, Colors.blue, cardColor, txtColor, isDark),
            const SizedBox(height: 16),
            _buildStatCard("Weekly Goal", "$_daysLoggedThisWeek/7 Days", "Logged this week", Icons.track_changes, accentColor, cardColor, txtColor, isDark),
            const SizedBox(height: 16),
            _buildStatCard("Protein Avg", "${_proteinAvg}g", "Based on last 7 days", Icons.trending_up, Colors.purple, cardColor, txtColor, isDark),
            
            const SizedBox(height: 24),
            
            // Protein Trend (Line Chart Card)
            _buildChartCard(
              title: "Protein Trend",
              subtitle: "Daily protein intake (last 7 days)",
              cardColor: cardColor,
              txtColor: txtColor,
              isDark: isDark,
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: CustomPaint(
                  painter: _LineChartPainter(isDark: isDark, lineColor: Colors.purple.shade400, dataPoints: _proteinTrend),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Macro Distribution (Donut Chart)
            _buildChartCard(
              title: "Macro Distribution",
              subtitle: "Average breakdown this week",
              cardColor: cardColor,
              txtColor: txtColor,
              isDark: isDark,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _DonutChartPainter(macros: _macroDistribution),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem("Protein ${_macroDistribution['protein']}%", Colors.purple.shade400, isDark),
                      const SizedBox(width: 12),
                      _buildLegendItem("Carbs ${_macroDistribution['carbs']}%", Colors.orange, isDark),
                      const SizedBox(width: 12),
                      _buildLegendItem("Fats ${_macroDistribution['fats']}%", accentColor, isDark),
                    ],
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Weekly Calories (Bar Chart)
            _buildChartCard(
              title: "Weekly Calories",
              subtitle: "Your calorie intake last 7 days",
              cardColor: cardColor,
              txtColor: txtColor,
              isDark: isDark,
              child: SizedBox(
                height: 160,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildBar("M", _weeklyCalories[0] / maxCal, Colors.purple.shade400),
                    _buildBar("T", _weeklyCalories[1] / maxCal, Colors.purple.shade400),
                    _buildBar("W", _weeklyCalories[2] / maxCal, Colors.purple.shade400),
                    _buildBar("T", _weeklyCalories[3] / maxCal, Colors.purple.shade400),
                    _buildBar("F", _weeklyCalories[4] / maxCal, Colors.purple.shade400),
                    _buildBar("S", _weeklyCalories[5] / maxCal, Colors.purple.shade400),
                    _buildBar("S", _weeklyCalories[6] / maxCal, Colors.purple.shade400),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, IconData icon, Color iconColor, Color cardColor, Color txtColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0x0C1B3A1E)),
        boxShadow: isDark ? null : [
          const BoxShadow(color: Color(0x0C1B3A1E), blurRadius: 20, offset: Offset(0, 8))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(color: txtColor, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: iconColor, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({required String title, required String subtitle, required Color cardColor, required Color txtColor, required bool isDark, Widget? child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0x0C1B3A1E)),
        boxShadow: isDark ? null : [
          const BoxShadow(color: Color(0x0C1B3A1E), blurRadius: 20, offset: Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: txtColor, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          const SizedBox(height: 20),
          child!,
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDark) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
      ],
    );
  }

  Widget _buildBar(String day, double heightRatio, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 24,
          height: 130 * (heightRatio > 1 ? 1 : heightRatio),
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ),
        const SizedBox(height: 8),
        Text(day, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final bool isDark;
  final Color lineColor;
  final List<int> dataPoints;
  
  _LineChartPainter({required this.isDark, required this.lineColor, required this.dataPoints});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
      
    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
      
    final bgLinePaint = Paint()
      ..color = isDark ? Colors.white10 : Colors.grey.shade200
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw Y axis lines
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), bgLinePaint);
    canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), bgLinePaint);
    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), bgLinePaint);

    if (dataPoints.isEmpty) return;

    int maxVal = dataPoints.reduce((curr, next) => curr > next ? curr : next);
    if (maxVal == 0) maxVal = 1;

    final path = Path();
    final stepX = size.width / (dataPoints.length > 1 ? dataPoints.length - 1 : 1);
    
    List<Offset> points = [];
    for (int i = 0; i < dataPoints.length; i++) {
      double x = i * stepX;
      double y = size.height - (dataPoints[i] / maxVal * size.height);
      points.add(Offset(x, y));
    }
    
    if (points.isNotEmpty) {
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);
      
      // Draw dots
      for (var point in points) {
        canvas.drawCircle(point, 5, dotPaint);
        canvas.drawCircle(point, 3, Paint()..color = isDark ? const Color(0xFF111111) : Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DonutChartPainter extends CustomPainter {
  final Map<String, int> macros;
  _DonutChartPainter({required this.macros});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.height / 2 - 10;
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
      
    double proteinPct = (macros['protein'] ?? 30) / 100.0;
    double carbsPct = (macros['carbs'] ?? 45) / 100.0;
    double fatsPct = (macros['fats'] ?? 25) / 100.0;

    double pi2 = 3.141592653589793 * 2;
    double proteinSweep = proteinPct * pi2;
    double carbsSweep = carbsPct * pi2;
    double fatsSweep = fatsPct * pi2;

    double currentAngle = -1.5; // Start at top roughly

    // Draw Carbs (Orange)
    if (carbsSweep > 0) {
      paint.color = Colors.orange;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), currentAngle, carbsSweep - 0.1, false, paint);
      currentAngle += carbsSweep;
    }
    
    // Draw Protein (Purple)
    if (proteinSweep > 0) {
      paint.color = Colors.purple.shade400;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), currentAngle, proteinSweep - 0.1, false, paint);
      currentAngle += proteinSweep;
    }
    
    // Draw Fats (Green)
    if (fatsSweep > 0) {
      paint.color = const Color(0xFF4CAF50);
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), currentAngle, fatsSweep - 0.1, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
