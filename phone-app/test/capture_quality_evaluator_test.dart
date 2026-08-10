import 'package:flutter_test/flutter_test.dart';

import 'package:ai_glasses_nutrition_app/services/capture_intent.dart';
import 'package:ai_glasses_nutrition_app/services/capture_quality_evaluator.dart';

void main() {
  const evaluator = CaptureQualityEvaluator();

  test('rejects invalid JPEG and low-resolution meal-before captures', () {
    final result = evaluator.evaluate(
      const CaptureQualityInput(
        isJpeg: false,
        width: 640,
        height: 480,
        brightness: 0.5,
        sharpness: 0.5,
      ),
      CaptureQualityPolicy.forScene('meal_before'),
    );

    expect(result.accepted, isFalse);
    expect(result.issues, contains(CaptureQualityIssue.invalidJpeg));
    expect(result.issues, contains(CaptureQualityIssue.lowResolution));
    expect(result.shouldRetake, isTrue);
  });

  test('allows a not-food meal-after when all image-quality checks pass', () {
    final result = evaluator.evaluate(
      const CaptureQualityInput(
        isJpeg: true,
        width: 1920,
        height: 1080,
        brightness: 0.5,
        sharpness: 0.5,
        foodRelevance: false,
      ),
      CaptureQualityPolicy.forScene('meal_after'),
    );

    expect(result.accepted, isTrue);
    expect(result.issues, isEmpty);
  });

  test('drops duplicate automatic meal-during captures without a retry', () {
    final result = evaluator.evaluate(
      const CaptureQualityInput(
        isJpeg: true,
        width: 1920,
        height: 1080,
        brightness: 0.5,
        sharpness: 0.5,
        isDuplicate: true,
      ),
      CaptureQualityPolicy.forScene('meal_during'),
    );

    expect(result.accepted, isFalse);
    expect(result.issues, contains(CaptureQualityIssue.duplicate));
    expect(result.shouldRetake, isFalse);
  });
}
