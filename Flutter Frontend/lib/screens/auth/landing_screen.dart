import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF1B3A1E);
    const bgColor = Color(0xFFFAF9F5);
    const lightGreen = Color(0xFF7CB342);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo / Title (Premium Design)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C1B3A1E),
                        blurRadius: 25,
                        offset: Offset(0, 5),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/images/logo.jpg',
                      width: 220,
                      height: 220,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Healthy choices start here.",
                  style: TextStyle(
                    fontSize: 16, 
                    color: Color(0xFF5A6E5C), 
                    fontWeight: FontWeight.w600,
                    fontFamily: "Cormorant",
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 40),

                // Standard Card (Premium Polish)
                Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0x0C1B3A1E), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A2E7D32),
                        blurRadius: 25,
                        offset: Offset(0, 12),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Get Started",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor, fontFamily: 'serif'),
                      ),
                      const SizedBox(height: 30),
                      _buildButton(
                        context, 
                        "Log In", 
                        lightGreen, 
                        Colors.white, 
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                      ),
                      const SizedBox(height: 16),
                      _buildButton(
                        context, 
                        "Sign Up", 
                        Colors.transparent, 
                        lightGreen, 
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen())),
                        isOutline: true,
                        outlineColor: lightGreen
                      ),
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

  Widget _buildButton(BuildContext context, String text, Color bgColor, Color textColor, VoidCallback onTap, {bool isOutline = false, Color outlineColor = Colors.transparent}) {
    if (isOutline) {
      return SizedBox(
        width: double.infinity,
        height: 55,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: outlineColor,
            side: BorderSide(color: outlineColor, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: onTap,
          child: Text(
            text,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: outlineColor),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
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
              color: const Color(0xFF2E7D32).withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
          ),
        ),
      ),
    );
  }
}
