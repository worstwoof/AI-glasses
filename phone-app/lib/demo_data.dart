import 'package:flutter/material.dart';

import 'models.dart';

class DemoData {
  static const profile = AppUserProfile(
    name: '王先生',
    deviceName: 'AI 眼镜 Pro',
    gender: '男',
    age: 25,
    heightCm: 178,
    weightKg: 70,
    goal: '减脂 & 健康',
    preference: '少油少盐',
    dailyTargetCalories: 1768,
    allergies: ['花生', '奶制品'],
    conditions: ['肠胃炎'],
  );

  static final initialMeals = <MealRecord>[
    MealRecord(
      mealType: '早餐',
      name: '荷包蛋（油煎）',
      calories: 119,
      carbs: 1,
      protein: 8,
      fat: 9,
      confidence: 0.50,
      eatenAt: _todayAt(8, 30),
      accent: const Color(0xFFF6B65E),
      icon: Icons.egg_alt_rounded,
    ),
    MealRecord(
      mealType: '午餐',
      name: '麻婆豆腐',
      calories: 383,
      carbs: 18,
      protein: 22,
      fat: 24,
      confidence: 0.90,
      eatenAt: _todayAt(12, 15),
      accent: const Color(0xFFF07A62),
      icon: Icons.soup_kitchen_rounded,
    ),
    MealRecord(
      mealType: '晚餐',
      name: '藜麦鸡胸肉沙拉',
      calories: 281,
      carbs: 32,
      protein: 29,
      fat: 8,
      confidence: 0.95,
      eatenAt: _todayAt(18, 0),
      accent: const Color(0xFF64EBC3),
      icon: Icons.lunch_dining_rounded,
    ),
  ];

  static final analysisCandidates = <AnalysisResult>[
    AnalysisResult(
      foodName: '香煎鸡胸肉配西兰花',
      suggestedMealType: '加餐',
      calories: 246,
      carbs: 11,
      protein: 31,
      fat: 8,
      fiber: 5,
      confidence: 0.94,
      recommendations: [
        '这份食物高蛋白、低糖，适合作为训练后补充。',
        '你今天碳水略低，建议搭配半份玉米或糙米提高饱腹感。',
        '肠胃较敏感时建议减少煎制油脂，优先蒸煮。',
      ],
      accent: const Color(0xFF71FFD4),
      icon: Icons.set_meal_rounded,
    ),
    AnalysisResult(
      foodName: '牛肉藜麦能量碗',
      suggestedMealType: '午餐',
      calories: 418,
      carbs: 34,
      protein: 27,
      fat: 15,
      fiber: 6,
      confidence: 0.91,
      recommendations: [
        '整体营养均衡，适合作为主餐。',
        '你今天剩余热量仍充足，但晚餐建议减少额外油炸食品。',
        '注意避开含花生酱沙拉汁，过敏原风险需要单独提醒。',
      ],
      accent: const Color(0xFF6CB8FF),
      icon: Icons.rice_bowl_rounded,
    ),
    AnalysisResult(
      foodName: '三文鱼时蔬便当',
      suggestedMealType: '晚餐',
      calories: 365,
      carbs: 24,
      protein: 30,
      fat: 14,
      fiber: 7,
      confidence: 0.96,
      recommendations: [
        'Omega-3 和优质蛋白比较充足，适合减脂期晚餐。',
        '如果后续还有运动，可以补充少量全麦碳水避免过饿。',
        '整体盐分偏低，符合你的少油少盐偏好。',
      ],
      accent: const Color(0xFF7AF1A8),
      icon: Icons.dinner_dining_rounded,
    ),
  ];

  static DateTime _todayAt(int hour, int minute) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }
}

