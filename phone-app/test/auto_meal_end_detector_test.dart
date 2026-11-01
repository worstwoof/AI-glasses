import 'package:flutter_test/flutter_test.dart';

import 'package:ai_glasses_nutrition_app/services/auto_meal_end_detector.dart';
import 'package:ai_glasses_nutrition_app/services/food_scene_classifier.dart';

void main() {
  test(
    'requires minimum duration, no hands, stable frames, and recent food',
    () {
      final detector = AutoMealEndDetector(
        config: const AutoMealEndConfig(
          minimumMealDuration: Duration(seconds: 5),
          noHandFrames: 2,
          stableFrames: 2,
          confirmationDelay: Duration(seconds: 2),
          lastFoodWindow: Duration(seconds: 3),
        ),
      );
      final start = DateTime(2026, 9, 29, 12);
      detector.start(start);
      const food = FoodSceneResult(
        isFoodScene: true,
        confidence: 0.9,
        foodProbability: 0.9,
      );

      expect(
        detector
            .observe(
              now: start.add(const Duration(seconds: 1)),
              food: food,
              hands: 0,
              frameStable: false,
            )
            .candidateReady,
        isFalse,
      );
      expect(
        detector
            .observe(
              now: start.add(const Duration(seconds: 5)),
              food: food,
              hands: 0,
              frameStable: true,
            )
            .candidateReady,
        isFalse,
      );
      expect(
        detector
            .observe(
              now: start.add(const Duration(seconds: 6)),
              food: food,
              hands: 0,
              frameStable: true,
            )
            .candidateReady,
        isFalse,
      );
      expect(
        detector
            .observe(
              now: start.add(const Duration(seconds: 8)),
              food: food,
              hands: 0,
              frameStable: true,
            )
            .candidateReady,
        isTrue,
      );
    },
  );

  test('a new hand or moving frame cancels the candidate window', () {
    final detector = AutoMealEndDetector(
      config: const AutoMealEndConfig(
        minimumMealDuration: Duration.zero,
        noHandFrames: 1,
        stableFrames: 1,
        confirmationDelay: Duration.zero,
      ),
    );
    final start = DateTime(2026, 9, 29, 12);
    detector.start(start);
    const food = FoodSceneResult(
      isFoodScene: true,
      confidence: 0.9,
      foodProbability: 0.9,
    );
    expect(
      detector
          .observe(now: start, food: food, hands: 0, frameStable: true)
          .candidateReady,
      isTrue,
    );
    final cancelled = detector.observe(
      now: start.add(const Duration(seconds: 1)),
      food: food,
      hands: 1,
      frameStable: false,
    );
    expect(cancelled.candidateReady, isFalse);
    expect(detector.noHandFrames, 0);
    expect(detector.stableFrames, 0);
  });
}
