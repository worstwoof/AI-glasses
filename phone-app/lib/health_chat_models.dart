import 'models.dart';

enum HealthChatRole { user, assistant }

class HealthChatMetric {
  const HealthChatMetric({
    required this.label,
    required this.value,
    required this.status,
  });

  final String label;
  final String value;
  final String status;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'label': label,
    'value': value,
    'status': status,
  };

  factory HealthChatMetric.fromMap(Map<String, dynamic> map) {
    return HealthChatMetric(
      label: map['label']?.toString() ?? '',
      value: map['value']?.toString() ?? '',
      status: map['status']?.toString() ?? 'neutral',
    );
  }
}

class HealthChatAction {
  const HealthChatAction({
    required this.title,
    required this.detail,
    required this.priority,
  });

  final String title;
  final String detail;
  final String priority;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'title': title,
    'detail': detail,
    'priority': priority,
  };

  factory HealthChatAction.fromMap(Map<String, dynamic> map) {
    return HealthChatAction(
      title: map['title']?.toString() ?? '',
      detail: map['detail']?.toString() ?? '',
      priority: map['priority']?.toString() ?? 'later',
    );
  }
}

class HealthChatMessage {
  const HealthChatMessage({
    required this.role,
    required this.text,
    required this.createdAt,
    this.metrics = const [],
    this.actions = const [],
  });

  final HealthChatRole role;
  final String text;
  final DateTime createdAt;
  final List<HealthChatMetric> metrics;
  final List<HealthChatAction> actions;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'role': role.name,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'metrics': metrics.map((item) => item.toMap()).toList(growable: false),
    'actions': actions.map((item) => item.toMap()).toList(growable: false),
  };

  factory HealthChatMessage.fromMap(Map<String, dynamic> map) {
    final metrics = map['metrics'] is List
        ? (map['metrics'] as List)
              .whereType<Map>()
              .map(
                (item) =>
                    HealthChatMetric.fromMap(Map<String, dynamic>.from(item)),
              )
              .toList(growable: false)
        : const <HealthChatMetric>[];
    final actions = map['actions'] is List
        ? (map['actions'] as List)
              .whereType<Map>()
              .map(
                (item) =>
                    HealthChatAction.fromMap(Map<String, dynamic>.from(item)),
              )
              .toList(growable: false)
        : const <HealthChatAction>[];
    return HealthChatMessage(
      role: map['role']?.toString() == HealthChatRole.user.name
          ? HealthChatRole.user
          : HealthChatRole.assistant,
      text: map['text']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      metrics: metrics,
      actions: actions,
    );
  }
}

class HealthChatContext {
  const HealthChatContext({required this.data});

  final Map<String, dynamic> data;

  factory HealthChatContext.fromState({
    required AppUserProfile profile,
    required List<MealRecord> meals,
    required AnalysisResult lastAnalysis,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final todayMeals = meals
        .where((meal) => _sameDay(meal.eatenAt, current))
        .toList();
    final recentMeals = meals
        .where(
          (meal) => !meal.eatenAt.isBefore(
            current.subtract(const Duration(days: 14)),
          ),
        )
        .map(_mealToMap)
        .toList(growable: false);

    double sum(double Function(MealRecord meal) selector) =>
        todayMeals.fold<double>(0, (total, meal) => total + selector(meal));

    return HealthChatContext(
      data: <String, dynamic>{
        'profile': profile.toMap(),
        'today': <String, dynamic>{
          'date': _date(current),
          'eatenCalories': todayMeals.fold<int>(
            0,
            (total, meal) => total + meal.calories,
          ),
          'remainingCalories':
              (profile.dailyTargetCalories -
                      todayMeals.fold<int>(
                        0,
                        (total, meal) => total + meal.calories,
                      ))
                  .clamp(0, profile.dailyTargetCalories),
          'carbs': sum((meal) => meal.carbs),
          'protein': sum((meal) => meal.protein),
          'fat': sum((meal) => meal.fat),
          'meals': todayMeals.map(_mealToMap).toList(growable: false),
        },
        'recentMeals': recentMeals,
        'latestAnalysis': lastAnalysis.toMap(),
        'contextVersion': 1,
      },
    );
  }

  Map<String, dynamic> toMap() => data;
}

Map<String, dynamic> _mealToMap(MealRecord meal) => <String, dynamic>{
  'date': _date(meal.eatenAt),
  'time':
      '${meal.eatenAt.hour.toString().padLeft(2, '0')}:${meal.eatenAt.minute.toString().padLeft(2, '0')}',
  'mealType': meal.mealType,
  'name': meal.name,
  'calories': meal.calories,
  'carbs': meal.carbs,
  'protein': meal.protein,
  'fat': meal.fat,
  'confidence': meal.confidence,
};

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
