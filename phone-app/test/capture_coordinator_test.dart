import 'package:flutter_test/flutter_test.dart';

import 'package:ai_glasses_nutrition_app/packaging_models.dart';
import 'package:ai_glasses_nutrition_app/services/capture_coordinator.dart';
import 'package:ai_glasses_nutrition_app/services/capture_intent.dart';
import 'package:ai_glasses_nutrition_app/services/capture_quality_evaluator.dart';

void main() {
  CaptureIntent intent({
    required String taskId,
    required CapturePriority priority,
    String scene = 'meal_during',
    Duration delay = Duration.zero,
    CaptureIntentSource source = CaptureIntentSource.automatic,
    CaptureCooldownGroup cooldownGroup = CaptureCooldownGroup.automaticFood,
    CaptureRetryPolicy retryPolicy = const CaptureRetryPolicy.none(),
  }) => CaptureIntent(
    taskId: taskId,
    captureType: CaptureType.food,
    trigger: 'test',
    scene: scene,
    mealSessionId: 'meal_test',
    source: source,
    priority: priority,
    delay: delay,
    cooldownGroup: cooldownGroup,
    qualityPolicy: CaptureQualityPolicy.forScene(scene),
    retryPolicy: retryPolicy,
  );

  test('allows only one physical high-resolution capture until exact ACK', () async {
    final dispatched = <CaptureIntent>[];
    final coordinator = CaptureCoordinator(
      dispatch: (capture) async {
        dispatched.add(capture);
        return true;
      },
    );
    addTearDown(coordinator.dispose);

    final first = coordinator.submit(
      intent(
        taskId: 'capture_a',
        priority: CapturePriority.explicitUser,
        source: CaptureIntentSource.manual,
        cooldownGroup: CaptureCooldownGroup.manualFood,
      ),
    );
    final second = coordinator.submit(
      intent(
        taskId: 'capture_b',
        priority: CapturePriority.explicitUser,
        source: CaptureIntentSource.manual,
        cooldownGroup: CaptureCooldownGroup.manualFood,
      ),
    );
    await _pump();

    expect(dispatched.map((item) => item.taskId), ['capture_a']);
    expect(
      coordinator.acknowledge(
        const CaptureAcknowledgement(
          taskId: 'capture_wrong',
          captureType: CaptureType.food,
          scene: 'meal_during',
          mealSessionId: 'meal_test',
        ),
        const CaptureQualityResult.accepted(),
      ),
      isFalse,
    );
    expect(dispatched, hasLength(1));

    expect(
      coordinator.acknowledge(
        const CaptureAcknowledgement(
          taskId: 'capture_a',
          captureType: CaptureType.food,
          scene: 'meal_during',
          mealSessionId: 'meal_test',
        ),
        const CaptureQualityResult.accepted(),
      ),
      isTrue,
    );
    await _pump();
    expect(dispatched.map((item) => item.taskId), ['capture_a', 'capture_b']);

    await first;
    coordinator.cancelTask('capture_b');
    await second;
  });

  test('meal end preempts an automatic task still waiting for its delay', () async {
    final dispatched = <CaptureIntent>[];
    final coordinator = CaptureCoordinator(
      dispatch: (capture) async {
        dispatched.add(capture);
        return true;
      },
    );
    addTearDown(coordinator.dispose);

    final automatic = coordinator.submit(
      intent(
        taskId: 'capture_auto',
        priority: CapturePriority.automatic,
        delay: const Duration(seconds: 1),
      ),
    );
    final mealEnd = coordinator.submit(
      intent(
        taskId: 'capture_end',
        priority: CapturePriority.critical,
        scene: 'meal_after',
      ),
    );
    await _pump();

    expect(dispatched.map((item) => item.taskId), ['capture_end']);
    expect((await automatic).state, CaptureTaskState.cancelled);
    coordinator.cancelTask('capture_end');
    expect((await mealEnd).state, CaptureTaskState.cancelled);
  });

  test('quality retry uses a fresh task ID and rejects a late old ACK', () async {
    final dispatched = <CaptureIntent>[];
    var id = 0;
    final coordinator = CaptureCoordinator(
      dispatch: (capture) async {
        dispatched.add(capture);
        return true;
      },
      taskIdGenerator: () => 'capture_retry_${++id}',
    );
    addTearDown(coordinator.dispose);

    final result = coordinator.submit(
      intent(
        taskId: 'capture_original',
        priority: CapturePriority.mealControl,
        scene: 'meal_before',
        retryPolicy: const CaptureRetryPolicy(maxRetakes: 1),
      ),
    );
    await _pump();
    expect(dispatched.single.taskId, 'capture_original');

    coordinator.acknowledge(
      const CaptureAcknowledgement(
        taskId: 'capture_original',
        captureType: CaptureType.food,
        scene: 'meal_before',
        mealSessionId: 'meal_test',
      ),
      const CaptureQualityResult.rejected([CaptureQualityIssue.blur]),
    );
    await _pump();
    expect(dispatched.map((item) => item.taskId), [
      'capture_original',
      'capture_retry_1',
    ]);

    expect(
      coordinator.acknowledge(
        const CaptureAcknowledgement(
          taskId: 'capture_original',
          captureType: CaptureType.food,
          scene: 'meal_before',
          mealSessionId: 'meal_test',
        ),
        const CaptureQualityResult.accepted(),
      ),
      isFalse,
    );
    expect(
      coordinator.acknowledge(
        const CaptureAcknowledgement(
          taskId: 'capture_retry_1',
          captureType: CaptureType.food,
          scene: 'meal_before',
          mealSessionId: 'meal_test',
        ),
        const CaptureQualityResult.accepted(),
      ),
      isTrue,
    );
    expect((await result).state, CaptureTaskState.accepted);
  });
}

Future<void> _pump() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
