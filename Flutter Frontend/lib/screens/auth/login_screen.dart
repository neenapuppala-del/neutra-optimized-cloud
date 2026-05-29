import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../home/main_home.dart';
import '../onboarding/onboarding_screen.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/notification_scheduler.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  
  void _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    
    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Please enter email and password',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orangeAccent.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(20),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final user = await AuthService().login(email, pass);
      if (user != null && mounted) {
        // Check if user has a profile
        final profile = await UserService.getProfile(user['userId']);
        
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

            if (profile['weight'] == null || profile['weight'] == 0 || 
                profile['height'] == null || profile['height'] == 0) {
              // No profile found or incomplete, route to onboarding
              Navigator.pushAndRemoveUntil(
                context, 
                MaterialPageRoute(builder: (_) => OnboardingScreen(userId: user['userId'], name: user['name'] ?? (profile['name'] ?? ''))), 
                (route) => false
              );
            } else {
              // Profile exists and is complete, go to home
              Navigator.pushAndRemoveUntil(
                context, 
                MaterialPageRoute(builder: (_) => const MainHome()), 
                (route) => false
              );
            }
          } else {
            // No profile found, route to onboarding
            Navigator.pushAndRemoveUntil(
              context, 
              MaterialPageRoute(builder: (_) => OnboardingScreen(userId: user['userId'], name: user['name'] ?? '')), 
              (route) => false
            );
          }
        }
      } else if (mounted) {
        throw Exception('Login failed. Please check your credentials or create an account.');
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.startsWith('Exception: ')) {
          errorMsg = errorMsg.substring('Exception: '.length);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    errorMsg,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.redAccent.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF1B3A1E);
    const bgColor = Color(0xFFFAF9F5); // Strict Light Mode Warm Ivory

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: textColor),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Text(
                  "Welcome Back",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor, fontFamily: 'Cormorant'),
                ),
                const SizedBox(height: 8),
                Text(
                  "Login to continue tracking your meals",
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 40),
                
                Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0x0C1B3A1E), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C1B3A1E),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildInput("Email Address", Icons.email_outlined, _emailCtrl, false, textColor),
                      const SizedBox(height: 20),
                      _buildInput("Password", Icons.lock_outline_rounded, _passCtrl, true, textColor),
                      const SizedBox(height: 30),
                      
                      GestureDetector(
                        onTap: _isLoading ? null : _login,
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
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              )
                            ],
                          ),
                          child: Center(
                            child: _isLoading 
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("Log In", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String hint, IconData icon, TextEditingController controller, bool isPassword, Color textColor) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
        prefixIcon: Icon(icon, color: const Color(0xFF5A6E5C)),
        filled: true,
        fillColor: const Color(0xFFF0EFEA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF7CB342), width: 1.5),
        ),
      ),
    );
  }
}
