import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home/main_home.dart';
import 'screens/home/main_home.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/splash_screen.dart';
import 'providers/user_provider.dart';
import 'services/notification_scheduler.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationScheduler.initialize();
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(initialDarkMode: isDarkMode)),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,

      // 🌞 LIGHT THEME
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFAF9F5),
        cardColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF7CB342),
          surface: Colors.white,
          onSurface: Color(0xFF1B3A1E),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Cormorant', fontWeight: FontWeight.bold),
          displayMedium: TextStyle(fontFamily: 'Cormorant', fontWeight: FontWeight.bold),
          displaySmall: TextStyle(fontFamily: 'Cormorant', fontWeight: FontWeight.bold),
          headlineLarge: TextStyle(fontFamily: 'Cormorant', fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(fontFamily: 'Cormorant', fontWeight: FontWeight.bold),
          headlineSmall: TextStyle(fontFamily: 'Cormorant', fontWeight: FontWeight.bold),
          titleLarge: TextStyle(fontFamily: 'Cormorant', fontWeight: FontWeight.bold),
          titleMedium: TextStyle(fontFamily: 'Cormorant', fontWeight: FontWeight.bold),
          titleSmall: TextStyle(fontFamily: 'Cormorant', fontWeight: FontWeight.bold),
        ),
      ),

      // 🌙 DARK THEME
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        cardColor: const Color(0xFF111111),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF81C784),
          surface: Color(0xFF000000),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Cormorant', fontWeight: FontWeight.bold),
          displayMedium: TextStyle(fontFamily: 'Cormorant', fontWeight: FontWeight.bold),
          displaySmall: TextStyle(fontFamily: 'Cormorant', fontWeight: FontWeight.bold),
          headlineLarge: TextStyle(fontFamily: 'Cormorant', fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(fontFamily: 'Cormorant', fontWeight: FontWeight.bold),
          headlineSmall: TextStyle(fontFamily: 'Cormorant', fontWeight: FontWeight.bold),
          titleLarge: TextStyle(fontFamily: 'Cormorant', fontWeight: FontWeight.bold),
          titleMedium: TextStyle(fontFamily: 'Cormorant', fontWeight: FontWeight.bold),
          titleSmall: TextStyle(fontFamily: 'Cormorant', fontWeight: FontWeight.bold),
        ),
      ),

      // 📱 MOBILE FRAME (centered UI like screenshot, responsive)
      builder: (context, child) {
        final size = MediaQuery.of(context).size;
        final useFrame = size.width > 600;

        if (!useFrame) {
          return child ?? const SizedBox.shrink();
        }

        return Container(
          color: Colors.white,
          child: Center(
            child: Container(
              width: 390,
              height: 800,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: child,
              ),
            ),
          ),
        );
      },

      home: const SplashScreen(),
    );
  }
}