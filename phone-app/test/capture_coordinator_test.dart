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

  test(
    'allows only one physical high-resolution capture until exact ACK',
    () async {
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
    },
  );

  test(
    'meal end preempts an automatic task still waiting for its delay',
    () async {
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
    },
  );

  test(
    'quality retry uses a fresh task ID and rejects a late old ACK',
    () async {
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
    },
  );

  test(
    'background cancellation recognizes an automatic task while it retries',
    () async {
      final dispatched = <CaptureIntent>[];
      var retryId = 0;
      final coordinator = CaptureCoordinator(
        dispatch: (capture) async {
          dispatched.add(capture);
          return true;
        },
        taskIdGenerator: () => 'automatic_retry_${++retryId}',
      );
      addTearDown(coordinator.dispose);

      final result = coordinator.submit(
        intent(
          taskId: 'automatic_original',
          priority: CapturePriority.automatic,
          scene: 'meal_before',
          retryPolicy: const CaptureRetryPolicy(maxRetakes: 1),
        ),
      );
      await _pump();

      expect(
        coordinator.acknowledge(
          const CaptureAcknowledgement(
            taskId: 'automatic_original',
            captureType: CaptureType.food,
            scene: 'meal_before',
            mealSessionId: 'meal_test',
          ),
          const CaptureQualityResult.rejected([CaptureQualityIssue.blur]),
        ),
        isTrue,
      );

      expect(coordinator.activeIntent!.taskId, 'automatic_retry_1');
      expect(coordinator.activeIntent!.source, CaptureIntentSource.retake);
      coordinator.cancelPendingWhere((intent) => intent.isAutomaticOrigin);

      expect((await result).state, CaptureTaskState.cancelled);
      expect(dispatched.map((capture) => capture.taskId), [
        'automatic_original',
      ]);
    },
  );

  test(
    'a rejected ACK cannot dispatch an automatic retry after backgrounding',
    () async {
      final dispatched = <CaptureIntent>[];
      var automaticCapturesAllowed = true;
      final coordinator = CaptureCoordinator(
        dispatch: (capture) async {
          dispatched.add(capture);
          return true;
        },
        isDispatchAllowed: (capture) =>
            !capture.isAutomaticOrigin || automaticCapturesAllowed,
        taskIdGenerator: () => 'automatic_retry_1',
      );
      addTearDown(coordinator.dispose);

      final result = coordinator.submit(
        intent(
          taskId: 'automatic_original',
          priority: CapturePriority.automatic,
          scene: 'meal_before',
          retryPolicy: const CaptureRetryPolicy(maxRetakes: 1),
        ),
      );
      await _pump();
      automaticCapturesAllowed = false;

      expect(
        coordinator.acknowledge(
          const CaptureAcknowledgement(
            taskId: 'automatic_original',
            captureType: CaptureType.food,
            scene: 'meal_before',
            mealSessionId: 'meal_test',
          ),
          const CaptureQualityResult.rejected([CaptureQualityIssue.blur]),
        ),
        isTrue,
      );
      await _pump();

      expect(dispatched.map((capture) => capture.taskId), [
        'automatic_original',
      ]);
      expect((await result).state, CaptureTaskState.dropped);
    },
  );

  test(
    'critical work preempts an automatic retry while its dispatch is delayed',
    () async {
      final dispatched = <CaptureIntent>[];
      final coordinator = CaptureCoordinator(
        dispatch: (capture) async {
          dispatched.add(capture);
          return true;
        },
        taskIdGenerator: () => 'automatic_retry_1',
      );
      addTearDown(coordinator.dispose);

      final automatic = coordinator.submit(
        intent(
          taskId: 'automatic_original',
          priority: CapturePriority.automatic,
          scene: 'meal_before',
          retryPolicy: const CaptureRetryPolicy(maxRetakes: 1),
        ),
      );
      await _pump();
      coordinator.acknowledge(
        const CaptureAcknowledgement(
          taskId: 'automatic_original',
          captureType: CaptureType.food,
          scene: 'meal_before',
          mealSessionId: 'meal_test',
        ),
        const CaptureQualityResult.rejected([CaptureQualityIssue.blur]),
      );

      final critical = coordinator.submit(
        intent(
          taskId: 'meal_after',
          priority: CapturePriority.critical,
          scene: 'meal_after',
        ),
      );
      await _pump();

      expect(dispatched.map((capture) => capture.taskId), [
        'automatic_original',
        'meal_after',
      ]);
      expect((await automatic).state, CaptureTaskState.cancelled);
      coordinator.cancelTask('meal_after');
      expect((await critical).state, CaptureTaskState.cancelled);
    },
  );

  test(
    'rejects duplicate task IDs without creating another physical capture',
    () async {
      final dispatched = <CaptureIntent>[];
      final coordinator = CaptureCoordinator(
        dispatch: (capture) async {
          dispatched.add(capture);
          return true;
        },
      );
      addTearDown(coordinator.dispose);

      final original = coordinator.submit(
        intent(
          taskId: 'capture_duplicate',
          priority: CapturePriority.explicitUser,
        ),
      );
      final duplicate = await coordinator.submit(
        intent(taskId: 'capture_duplicate', priority: CapturePriority.critical),
      );
      await _pump();

      expect(duplicate.state, CaptureTaskState.dropped);
      expect(dispatched.map((item) => item.taskId), ['capture_duplicate']);
      expect(
        coordinator.acknowledge(
          const CaptureAcknowledgement(
            taskId: 'capture_duplicate',
            captureType: CaptureType.food,
            scene: 'meal_during',
            mealSessionId: 'meal_test',
          ),
          const CaptureQualityResult.accepted(),
        ),
        isTrue,
      );
      expect((await original).state, CaptureTaskState.accepted);

      final replay = await coordinator.submit(
        intent(taskId: 'capture_duplicate', priority: CapturePriority.critical),
      );
      expect(replay.state, CaptureTaskState.dropped);
      expect(dispatched, hasLength(1));
    },
  );

  test(
    'drains 120 mixed intents with one in flight and priority progress',
    () async {
      final dispatched = <CaptureIntent>[];
      var dispatchesInProgress = 0;
      var maxDispatchesInProgress = 0;
      final coordinator = CaptureCoordinator(
        dispatch: (capture) async {
          dispatchesInProgress += 1;
          maxDispatchesInProgress =
              maxDispatchesInProgress < dispatchesInProgress
              ? dispatchesInProgress
              : maxDispatchesInProgress;
          dispatched.add(capture);
          await Future<void>.delayed(Duration.zero);
          dispatchesInProgress -= 1;
          return true;
        },
      );
      addTearDown(coordinator.dispose);

      final priorities = CapturePriority.values;
      final sources = <CaptureIntentSource>[
        CaptureIntentSource.automatic,
        CaptureIntentSource.manual,
        CaptureIntentSource.mealControl,
        CaptureIntentSource.retake,
      ];
      final futures = List<Future<CaptureTaskResult>>.generate(120, (index) {
        return coordinator.submit(
          intent(
            taskId: 'stress_$index',
            priority: priorities[index % priorities.length],
            source: sources[index % sources.length],
            cooldownGroup: CaptureCooldownGroup.none,
          ),
        );
      });

      for (var index = 0; index < futures.length; index += 1) {
        await _pump();
        final active = coordinator.activeIntent;
        expect(active, isNotNull);
        expect(
          coordinator.acknowledge(
            CaptureAcknowledgement(
              taskId: active!.taskId,
              captureType: active.captureType,
              scene: active.scene,
              mealSessionId: active.mealSessionId,
            ),
            const CaptureQualityResult.accepted(),
          ),
          isTrue,
        );
      }

      final results = await Future.wait(futures);
      expect(results.every((result) => result.accepted), isTrue);
      expect(dispatched, hasLength(120));
      expect(maxDispatchesInProgress, 1);
      expect(coordinator.snapshot.queueLength, 0);
      expect(coordinator.activeIntent, isNull);
    },
  );

  test(
    'dispose cancels queued and waiting-ACK work without a later callback',
    () async {
      final snapshots = <CaptureCoordinatorSnapshot>[];
      final coordinator = CaptureCoordinator(
        dispatch: (_) async => true,
        onChanged: snapshots.add,
      );
      final active = coordinator.submit(
        intent(
          taskId: 'dispose_active',
          priority: CapturePriority.explicitUser,
        ),
      );
      final queued = coordinator.submit(
        intent(taskId: 'dispose_queued', priority: CapturePriority.automatic),
      );
      await _pump();
      expect(coordinator.snapshot.state, CaptureTaskState.waitingAck);

      coordinator.dispose();
      final snapshotCount = snapshots.length;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect((await active).state, CaptureTaskState.cancelled);
      expect((await queued).state, CaptureTaskState.cancelled);
      expect(snapshots, hasLength(snapshotCount));
    },
  );
}

Future<void> _pump() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
