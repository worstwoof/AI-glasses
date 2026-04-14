import 'package:flutter/material.dart';

class AppUserProfile {
  const AppUserProfile({
    required this.name,
    required this.deviceName,
    required this.gender,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.goal,
    required this.preference,
    required this.dailyTargetCalories,
    required this.allergies,
    required this.conditions,
  });

  final String name;
  final String deviceName;
  final String gender;
  final int age;
  final int heightCm;
  final int weightKg;
  final String goal;
  final String preference;
  final int dailyTargetCalories;
  final List<String> allergies;
  final List<String> conditions;

  AppUserProfile copyWith({
    String? name,
    String? deviceName,
    String? gender,
    int? age,
    int? heightCm,
    int? weightKg,
    String? goal,
    String? preference,
    int? dailyTargetCalories,
    List<String>? allergies,
    List<String>? conditions,
  }) {
    return AppUserProfile(
      name: name ?? this.name,
      deviceName: deviceName ?? this.deviceName,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      goal: goal ?? this.goal,
      preference: preference ?? this.preference,
      dailyTargetCalories: dailyTargetCalories ?? this.dailyTargetCalories,
      allergies: allergies ?? this.allergies,
      conditions: conditions ?? this.conditions,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'deviceName': deviceName,
      'gender': gender,
      'age': age,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'goal': goal,
      'preference': preference,
      'dailyTargetCalories': dailyTargetCalories,
      'allergies': allergies,
      'conditions': conditions,
    };
  }

  factory AppUserProfile.fromMap(Map<String, dynamic> map) {
    return AppUserProfile(
      name: map['name']?.toString() ?? '',
      deviceName: map['deviceName']?.toString() ?? '',
      gender: map['gender']?.toString() ?? '',
      age: _toInt(map['age']),
      heightCm: _toInt(map['heightCm']),
      weightKg: _toInt(map['weightKg']),
      goal: map['goal']?.toString() ?? '',
      preference: map['preference']?.toString() ?? '',
      dailyTargetCalories: _toInt(map['dailyTargetCalories']),
      allergies: _toStringList(map['allergies']),
      conditions: _toStringList(map['conditions']),
    );
  }
}

class MealRecord {
  const MealRecord({
    required this.mealType,
    required this.name,
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.confidence,
    required this.eatenAt,
    required this.accent,
    required this.icon,
  });

  final String mealType;
  final String name;
  final int calories;
  final double carbs;
  final double protein;
  final double fat;
  final double confidence;
  final DateTime eatenAt;
  final Color accent;
  final IconData icon;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'mealType': mealType,
      'name': name,
      'calories': calories,
      'carbs': carbs,
      'protein': protein,
      'fat': fat,
      'confidence': confidence,
      'eatenAt': eatenAt.toIso8601String(),
      'accent': accent.value,
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'iconFontPackage': icon.fontPackage,
      'iconMatchTextDirection': icon.matchTextDirection,
    };
  }

  factory MealRecord.fromMap(Map<String, dynamic> map) {
    return MealRecord(
      mealType: map['mealType']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      calories: _toInt(map['calories']),
      carbs: _toDouble(map['carbs']),
      protein: _toDouble(map['protein']),
      fat: _toDouble(map['fat']),
      confidence: _toDouble(map['confidence']),
      eatenAt: DateTime.tryParse(map['eatenAt']?.toString() ?? '') ?? DateTime.now(),
      accent: Color(_toInt(map['accent'])),
      icon: IconData(
        _toInt(map['iconCodePoint']),
        fontFamily: map['iconFontFamily']?.toString(),
        fontPackage: map['iconFontPackage']?.toString(),
        matchTextDirection: map['iconMatchTextDirection'] == true,
      ),
    );
  }
}

class MacroSummary {
  const MacroSummary({
    required this.carbs,
    required this.protein,
    required this.fat,
  });

  final double carbs;
  final double protein;
  final double fat;

  double get total => carbs + protein + fat;
}

class AnalysisResult {
  const AnalysisResult({
    required this.foodName,
    required this.suggestedMealType,
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.fiber,
    required this.confidence,
    required this.recommendations,
    required this.accent,
    required this.icon,
  });

  final String foodName;
  final String suggestedMealType;
  final int calories;
  final double carbs;
  final double protein;
  final double fat;
  final double fiber;
  final double confidence;
  final List<String> recommendations;
  final Color accent;
  final IconData icon;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'foodName': foodName,
      'suggestedMealType': suggestedMealType,
      'calories': calories,
      'carbs': carbs,
      'protein': protein,
      'fat': fat,
      'fiber': fiber,
      'confidence': confidence,
      'recommendations': recommendations,
      'accent': accent.value,
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'iconFontPackage': icon.fontPackage,
      'iconMatchTextDirection': icon.matchTextDirection,
    };
  }

  factory AnalysisResult.fromMap(Map<String, dynamic> map) {
    return AnalysisResult(
      foodName: map['foodName']?.toString() ?? '',
      suggestedMealType: map['suggestedMealType']?.toString() ?? '',
      calories: _toInt(map['calories']),
      carbs: _toDouble(map['carbs']),
      protein: _toDouble(map['protein']),
      fat: _toDouble(map['fat']),
      fiber: _toDouble(map['fiber']),
      confidence: _toDouble(map['confidence']),
      recommendations: _toStringList(map['recommendations']),
      accent: Color(_toInt(map['accent'])),
      icon: IconData(
        _toInt(map['iconCodePoint']),
        fontFamily: map['iconFontFamily']?.toString(),
        fontPackage: map['iconFontPackage']?.toString(),
        matchTextDirection: map['iconMatchTextDirection'] == true,
      ),
    );
  }
}

enum ScanStage {
  idle,
  capturing,
  recognizing,
  analyzing,
  completed,
}

int _toInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _toDouble(dynamic value, [double fallback = 0]) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

List<String> _toStringList(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  return const [];
}
