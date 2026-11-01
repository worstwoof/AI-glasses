import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'app_shell_pro.dart';
import 'app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android installs HotspotNetworkDetector before Flutter starts. Keep the
  // standard monitor enabled; disableNetworkMonitor is not a supported option
  // in this plugin. ICE uses Wi-Fi, while HTTP AI calls can use mobile data.
  await WebRTC.initialize();
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
