import '../packaging_models.dart';

enum CaptureIntentSource { manual, mealControl, automatic, retake }

enum CapturePriority {
  critical,
  explicitUser,
  mealControl,
  automatic;

  int get rank => switch (this) {
    CapturePriority.critical => 0,
    CapturePriority.explicitUser => 1,
    CapturePriority.mealControl => 2,
    CapturePriority.automatic => 3,
  };
}

enum CaptureCooldownGroup { none, automaticFood, packaging, manualFood }

class CaptureRetryPolicy {
  const CaptureRetryPolicy({this.maxRetakes = 0});

  const CaptureRetryPolicy.none() : maxRetakes = 0;

  final int maxRetakes;
}

class CaptureQualityPolicy {
  const CaptureQualityPolicy({
    required this.requireHighResolution,
    required this.requireFoodRelevance,
    required this.checkDuplicate,
    required this.allowsRetake,
  });

  final bool requireHighResolution;
  final bool requireFoodRelevance;
  final bool checkDuplicate;
  final bool allowsRetake;

  factory CaptureQualityPolicy.forScene(String scene) {
    switch (scene) {
      case 'meal_before':
        return const CaptureQualityPolicy(
          requireHighResolution: true,
          requireFoodRelevance: true,
          checkDuplicate: false,
          allowsRetake: true,
        );
      case 'meal_during':
        return const CaptureQualityPolicy(
          requireHighResolution: false,
          requireFoodRelevance: true,
          checkDuplicate: true,
          allowsRetake: false,
        );
      case 'meal_after':
      case 'ingredient_label':
      default:
        return const CaptureQualityPolicy(
          requireHighResolution: true,
          requireFoodRelevance: false,
          checkDuplicate: false,
          allowsRetake: true,
        );
    }
  }
}

class CaptureIntent {
  const CaptureIntent({
    required this.taskId,
    required this.captureType,
    required this.trigger,
    required this.scene,
    required this.mealSessionId,
    required this.source,
    required this.priority,
    required this.delay,
    required this.cooldownGroup,
    required this.qualityPolicy,
    required this.retryPolicy,
  });

  final String taskId;
  final CaptureType captureType;
  final String trigger;
  final String scene;
  final String? mealSessionId;
  final CaptureIntentSource source;
  final CapturePriority priority;
  final Duration delay;
  final CaptureCooldownGroup cooldownGroup;
  final CaptureQualityPolicy qualityPolicy;
  final CaptureRetryPolicy retryPolicy;

  CaptureIntent copyWith({
    String? taskId,
    CaptureIntentSource? source,
    Duration? delay,
  }) => CaptureIntent(
    taskId: taskId ?? this.taskId,
    captureType: captureType,
    trigger: trigger,
    scene: scene,
    mealSessionId: mealSessionId,
    source: source ?? this.source,
    priority: priority,
    delay: delay ?? this.delay,
    cooldownGroup: cooldownGroup,
    qualityPolicy: qualityPolicy,
    retryPolicy: retryPolicy,
  );
}
