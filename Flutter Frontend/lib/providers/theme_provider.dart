import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_service.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode;

  ThemeProvider({bool initialDarkMode = false})
      : _themeMode = initialDarkMode ? ThemeMode.dark : ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme(bool isDark, {bool syncToBackend = true}) async {
    if (isDarkMode == isDark) return;

    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);

    if (syncToBackend) {
      final userId = prefs.getString('userId');
      if (userId != null && userId.isNotEmpty) {
        // Sync theme preference to database asynchronously in the background
        UserService.saveProfile({
          'userId': userId,
          'theme': isDark ? 'dark' : 'light',
        });
      }
    }
  }
}
