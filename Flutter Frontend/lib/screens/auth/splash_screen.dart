import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/user_service.dart';
import '../../services/notification_scheduler.dart';
import '../home/main_home.dart';
import 'landing_screen.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final userId = prefs.getString('userId');

      if (token != null && userId != null) {
        // Check if user has a profile
        final profile = await UserService.getProfile(userId);
        
        if (mounted) {
          if (profile != null) {
            // Apply stored backend theme dynamically if present
            if (profile['theme'] != null) {
              final isDark = profile['theme'] == 'dark';
              Provider.of<ThemeProvider>(context, listen: false)
                  .toggleTheme(isDark, syncToBackend: false);
            }

            // Sync notifications natively in background
            final customNotifs = profile['custom_notifications'] as List<dynamic>?;
            if (customNotifs != null) {
              NotificationScheduler.scheduleAll(customNotifs);
            }

            if (profile['weight'] != null && profile['weight'] != 0 && 
                profile['height'] != null && profile['height'] != 0) {
              // Profile exists and is complete, go to home
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const MainHome()),
              );
            } else {
              // No profile or profile is incomplete, go to onboarding
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => OnboardingScreen(userId: userId, name: profile['name'] ?? ''),
                ),
              );
            }
          } else {
            // No profile, go to onboarding
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => OnboardingScreen(userId: userId, name: ''),
              ),
            );
          }
        }
      } else {
        // No token or userId, go to landing
        _goToLanding();
      }
    } catch (e) {
      print("Error checking session: $e");
      _goToLanding();
    }
  }

  void _goToLanding() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LandingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const lightGreen = Color(0xFF7CB342);
    const bgColor = Color(0xFFFAF9F5); // Strict Light Mode Warm Ivory

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C1B3A1E),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  'assets/images/logo.jpg',
                  width: 140,
                  height: 140,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: lightGreen),
          ],
        ),
      ),
    );
  }
}
