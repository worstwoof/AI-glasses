import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../demo_data.dart';
import '../models.dart';

class LocalAppState {
  const LocalAppState({
    required this.profile,
    required this.meals,
    required this.isConnected,
    required this.lastAnalysis,
  });

  final AppUserProfile profile;
  final List<MealRecord> meals;
  final bool isConnected;
  final AnalysisResult? lastAnalysis;
}

class LocalStorageService {
  LocalStorageService._();

  static const String _profileKey = 'local_profile';
  static const String _mealsKey = 'local_meals';
  static const String _isConnectedKey = 'local_is_connected';
  static const String _lastAnalysisKey = 'local_last_analysis';

  static final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  static Future<LocalAppState> loadState() async {
    final profile = await loadProfile();
    final meals = await loadMeals();
    final isConnected = await _prefs.getBool(_isConnectedKey) ?? true;
    final lastAnalysis = await loadLastAnalysis();

    return LocalAppState(
      profile: profile,
      meals: meals,
      isConnected: isConnected,
      lastAnalysis: lastAnalysis,
    );
  }

  static Future<AppUserProfile> loadProfile() async {
    final raw = await _prefs.getString(_profileKey);
    if (raw == null || raw.trim().isEmpty) {
      return DemoData.profile;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return AppUserProfile.fromMap(decoded);
    } catch (_) {
      return DemoData.profile;
    }
  }

  static Future<List<MealRecord>> loadMeals() async {
    final raw = await _prefs.getString(_mealsKey);
    if (raw == null || raw.trim().isEmpty) {
      return <MealRecord>[];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((item) => MealRecord.fromMap(Map<String, dynamic>.from(item)))
          .toList()
        ..sort((a, b) => b.eatenAt.compareTo(a.eatenAt));
    } catch (_) {
      return <MealRecord>[];
    }
  }

  static Future<void> saveProfile(AppUserProfile profile) {
    return _prefs.setString(_profileKey, jsonEncode(profile.toMap()));
  }

  static Future<void> saveMeals(List<MealRecord> meals) {
    final payload = meals.map((meal) => meal.toMap()).toList();
    return _prefs.setString(_mealsKey, jsonEncode(payload));
  }

  static Future<void> saveConnection(bool isConnected) {
    return _prefs.setBool(_isConnectedKey, isConnected);
  }

  static Future<AnalysisResult?> loadLastAnalysis() async {
    final raw = await _prefs.getString(_lastAnalysisKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return AnalysisResult.fromMap(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveLastAnalysis(AnalysisResult analysis) {
    return _prefs.setString(_lastAnalysisKey, jsonEncode(analysis.toMap()));
  }
}
