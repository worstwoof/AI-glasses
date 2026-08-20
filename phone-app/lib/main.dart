import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'app_shell_pro.dart';
import 'app_theme.dart';
import 'services/glass_receiver_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WebRTC.initialize(options: const {'disableNetworkMonitor': true});
  unawaited(GlassReceiverService.instance.start());
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
