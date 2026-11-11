import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'widgets/diagrams/base_billiard_diagram.dart';

void main() {
  runApp(const XavierBilliardLibreApp());
}

class XavierBilliardLibreApp extends StatelessWidget {
  const XavierBilliardLibreApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF156947);
    final darkScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
      primary: BilliardPalette.diamondGold,
      secondary: BilliardPalette.cueTrajectory,
      surface: const Color(0xFF0C1410),
    );

    return MaterialApp(
      title: 'Xavier Billiard Libre',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: darkScheme,
        scaffoldBackgroundColor: const Color(0xFF0A110E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0E1813),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0E1813),
          indicatorColor: BilliardPalette.diamondGold.withValues(alpha: 0.22),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
