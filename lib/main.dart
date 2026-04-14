import 'package:flutter/material.dart';

import 'app_shell_pro.dart';
import 'app_theme.dart';

void main() {
  runApp(const AiGlassesNutritionApp());
}

class AiGlassesNutritionApp extends StatefulWidget {
  const AiGlassesNutritionApp({super.key});

  @override
  State<AiGlassesNutritionApp> createState() => _AiGlassesNutritionAppState();
}

class _AiGlassesNutritionAppState extends State<AiGlassesNutritionApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Glasses Nutrition',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: AppShellPro(
        themeMode: _themeMode,
        onThemeModeChanged: (mode) {
          setState(() {
            _themeMode = mode;
          });
        },
      ),
    );
  }
}
