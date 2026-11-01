import 'package:flutter_test/flutter_test.dart';
import '../lib/packaging_models.dart';
import '../lib/services/capture_intent.dart';
import '../lib/services/capture_coordinator.dart';
import '../lib/services/capture_quality_evaluator.dart';

void main() {
  testWidgets('packaging failure retries twice with fresh IDs then stops', (
    tester,
  ) async {
    final commands = <CaptureIntent>[];
    var sequence = 0;
    final coordinator = CaptureCoordinator(
      dispatch: (intent) async {
        commands.add(intent);
        return true;
      },
      taskIdGenerator: () => 'retry_${++sequence}',
    );
    final finished = coordinator.submit(
      CaptureIntent(
        taskId: 'first',
        captureType: CaptureType.packaging,
        trigger: 'ok',
        scene: 'ingredient_label',
        mealSessionId: null,
        source: CaptureIntentSource.manual,
        priority: CapturePriority.explicitUser,
        delay: Duration.zero,
        cooldownGroup: CaptureCooldownGroup.packaging,
        qualityPolicy: CaptureQualityPolicy.forScene('ingredient_label'),
        retryPolicy: const CaptureRetryPolicy(maxRetakes: 2),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    for (var attempt = 0; attempt < 3; attempt++) {
      expect(commands.length, attempt + 1);
      final current = commands.last;
      expect(
        coordinator.acknowledge(
          CaptureAcknowledgement(
            taskId: current.taskId,
            captureType: CaptureType.packaging,
            scene: 'ingredient_label',
            mealSessionId: null,
          ),
          const CaptureQualityResult.rejected([
            CaptureQualityIssue.captureFailed,
          ], shouldRetake: true),
        ),
        isTrue,
      );
      if (attempt < 2) await tester.pump(const Duration(seconds: 1));
    }
    expect((await finished).state, CaptureTaskState.failed);
    expect(commands.map((e) => e.taskId).toSet(), hasLength(3));
    coordinator.dispose();
  });
}
