import 'package:flutter_test/flutter_test.dart';

import 'package:ai_glasses_nutrition_app/services/auto_candidate_tracker.dart';
import 'package:ai_glasses_nutrition_app/services/capture_mode_controller.dart';
import 'package:ai_glasses_nutrition_app/services/food_scene_classifier.dart';

void main() {
  test('missing food model keeps automatic and hybrid automatic capture unavailable', () {
    final controller = CaptureModeController(
      classifier: const UnavailableFoodSceneClassifier(),
    );

    expect(controller.mode, CaptureMode.manual);
    expect(controller.setMode(CaptureMode.automatic), isFalse);
    expect(controller.setMode(CaptureMode.hybrid), isFalse);
    expect(controller.mode, CaptureMode.manual);
    expect(controller.unavailableReason, contains('食品场景模型未加载'));
  });

  test('food candidates need two stable high confidence frames and respect cooldown', () {
    final tracker = AutoCandidateTracker(
      config: const AutoCandidateConfig(
        confidenceThreshold: 0.8,
        stableFrames: 2,
        cooldown: Duration(seconds: 8),
      ),
    );
    final start = DateTime(2026, 8, 11, 12);

    expect(
      tracker.observe(
        const FoodSceneResult(isFoodScene: true, confidence: 0.79),
        now: start,
        frameFingerprint: 'a',
      ).eligible,
      isFalse,
    );
    expect(
      tracker.observe(
        const FoodSceneResult(isFoodScene: true, confidence: 0.9),
        now: start,
        frameFingerprint: 'a',
      ).eligible,
      isFalse,
    );
    expect(
      tracker.observe(
        const FoodSceneResult(isFoodScene: true, confidence: 0.91),
        now: start.add(const Duration(seconds: 1)),
        frameFingerprint: 'b',
      ).eligible,
      isTrue,
    );
    tracker.markAccepted(start.add(const Duration(seconds: 1)), 'b');

    expect(
      tracker.observe(
        const FoodSceneResult(isFoodScene: true, confidence: 0.92),
        now: start.add(const Duration(seconds: 2)),
        frameFingerprint: 'c',
      ).eligible,
      isFalse,
    );
    expect(
      tracker.observe(
        const FoodSceneResult(isFoodScene: false, confidence: 0.9),
        now: start.add(const Duration(seconds: 10)),
        frameFingerprint: 'd',
      ).stableFrames,
      0,
    );
  });
}
