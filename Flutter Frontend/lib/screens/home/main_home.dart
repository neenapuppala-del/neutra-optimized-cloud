import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';
import '../analytics/analytics_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import '../../services/notification_scheduler.dart';

class MainHome extends StatefulWidget {
  const MainHome({super.key});

  @override
  State<MainHome> createState() => _MainHomeState();
}

class _MainHomeState extends State<MainHome> {
  int _currentIndex = 0;
  int _historyVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadActiveTab();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationScheduler.start(context);
    });
  }

  Future<void> _loadActiveTab() async {
    final prefs = await SharedPreferences.getInstance();
    final tab = prefs.getInt('activeTab');
    if (tab != null && tab >= 0 && tab < 4 && mounted) {
      setState(() {
        _currentIndex = tab;
      });
    }
  }

  @override
  void dispose() {
    NotificationScheduler.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      DashboardScreen(key: ValueKey('dashboard_$_historyVersion')),
      AnalyticsScreen(key: ValueKey('analytics_$_historyVersion')),
      HistoryScreen(key: ValueKey('history_$_historyVersion')),
      SettingsScreen(
        key: ValueKey('settings_$_historyVersion'),
        onHistoryDeleted: () {
          setState(() {
            _historyVersion++;
          });
        },
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // The current screen
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: screens[_currentIndex],
            ),
          ),
          
          // Custom Bottom Navigation Bar Fixed at Bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.home_rounded, "Home"),
                  _buildNavItem(1, Icons.bar_chart_rounded, "Analytics"),
                  _buildNavItem(2, Icons.history_rounded, "History"),
                  _buildNavItem(3, Icons.settings_rounded, "Settings"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () async {
        setState(() {
          _currentIndex = index;
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('activeTab', index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Active Gradient Indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 4,
              width: isSelected ? 24 : 0,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
                      )
                    : null,
              ),
            ),
            Icon(
              icon,
              size: 28,
              color: isSelected
                  ? (isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50))
                  : Colors.grey.withOpacity(0.6),
            ),
            if (isSelected) ...[
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
