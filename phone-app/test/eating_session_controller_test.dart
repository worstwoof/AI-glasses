import 'package:flutter_test/flutter_test.dart';

import 'package:ai_glasses_nutrition_app/packaging_models.dart';
import 'package:ai_glasses_nutrition_app/services/capture_coordinator.dart';
import 'package:ai_glasses_nutrition_app/services/capture_intent.dart';
import 'package:ai_glasses_nutrition_app/services/capture_quality_evaluator.dart';
import 'package:ai_glasses_nutrition_app/services/eating_session_controller.dart';

void main() {
  group('EatingSessionController', () {
    test('requires two open palms and a matching meal-before ACK', () async {
      final harness = _Harness(sessionId: 'meal_test_1');
      addTearDown(harness.dispose);

      harness.controller.onGesture('open_palm');
      expect(harness.controller.state, EatingSessionState.idle);
      harness.controller.onGesture('open_palm');
      expect(harness.controller.state, EatingSessionState.starting);
      await _pump();

      final intent = harness.intents.single;
      expect(intent.trigger, 'meal_start');
      expect(intent.scene, 'meal_before');
      expect(intent.mealSessionId, 'meal_test_1');
      expect(intent.delay, Duration.zero);
      expect(harness.controller.state, EatingSessionState.starting);

      expect(harness.acknowledge(taskId: 'wrong_task'), isFalse);
      expect(harness.controller.state, EatingSessionState.starting);
      expect(harness.acknowledge(taskId: intent.taskId), isTrue);
      await _pump();
      expect(harness.controller.state, EatingSessionState.eating);
    });

    test(
      'keeps eating latched through unknown, no-hand, open-palm, and OK',
      () async {
        final harness = _Harness(sessionId: 'meal_locked');
        addTearDown(harness.dispose);
        await harness.startAndAccept();

        for (final gesture in const ['unknown', 'no_hand', 'open_palm', 'ok']) {
          harness.controller.onGesture(gesture);
          expect(harness.controller.state, EatingSessionState.eating);
        }
        expect(harness.intents, hasLength(1));
      },
    );

    test(
      'requires two fists and pairs meal-after with the active session',
      () async {
        final harness = _Harness(sessionId: 'meal_pair');
        addTearDown(harness.dispose);
        await harness.startAndAccept();

        harness.controller.onGesture('fist');
        expect(harness.controller.state, EatingSessionState.eating);
        harness.controller.onGesture('fist');
        expect(harness.controller.state, EatingSessionState.ending);
        await _pump();

        final intent = harness.intents.last;
        expect(intent.trigger, 'meal_end');
        expect(intent.scene, 'meal_after');
        expect(intent.mealSessionId, 'meal_pair');
        expect(harness.acknowledge(taskId: 'other_task'), isFalse);
        expect(harness.controller.state, EatingSessionState.ending);
        expect(harness.acknowledge(taskId: intent.taskId), isTrue);
        await _pump();
        expect(harness.controller.state, EatingSessionState.idle);
        expect(harness.controller.lastCompletedSessionId, 'meal_pair');
      },
    );

    test(
      'send failure and acknowledgement timeout recover to stable states',
      () async {
        final harness = _Harness(
          sessionId: 'meal_failure',
          acknowledgementTimeout: const Duration(milliseconds: 10),
        );
        addTearDown(harness.dispose);

        harness.shouldSend = false;
        harness.controller.onGesture('open_palm');
        harness.controller.onGesture('open_palm');
        await _pump();
        expect(harness.controller.state, EatingSessionState.idle);
        expect(harness.controller.errorMessage, '餐前抓拍失败，请重新张手开始');

        harness.shouldSend = true;
        harness.controller.onGesture('open_palm');
        harness.controller.onGesture('open_palm');
        await _pump();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(harness.controller.state, EatingSessionState.idle);

        await harness.startAndAccept();
        harness.shouldSend = false;
        harness.controller.onGesture('fist');
        harness.controller.onGesture('fist');
        await _pump();
        expect(harness.controller.state, EatingSessionState.eating);
      },
    );

    test('does not duplicate captures while starting or ending', () async {
      final harness = _Harness(sessionId: 'meal_single_command');
      addTearDown(harness.dispose);

      harness.controller.onGesture('open_palm');
      harness.controller.onGesture('open_palm');
      harness.controller.onGesture('open_palm');
      await _pump();
      expect(harness.intents, hasLength(1));
      expect(
        harness.acknowledge(taskId: harness.intents.single.taskId),
        isTrue,
      );
      await _pump();

      harness.controller.onGesture('fist');
      harness.controller.onGesture('fist');
      harness.controller.onGesture('fist');
      await _pump();
      expect(harness.intents, hasLength(2));
    });

    test(
      'cancel clears STARTING, EATING, and ENDING and ignores late ACKs',
      () async {
        final harness = _Harness(sessionId: 'meal_cancel');
        addTearDown(harness.dispose);

        harness.controller.onGesture('open_palm');
        harness.controller.onGesture('open_palm');
        await _pump();
        final startingTask = harness.intents.single.taskId;
        harness.controller.cancel();
        expect(harness.controller.state, EatingSessionState.idle);
        expect(harness.acknowledge(taskId: startingTask), isFalse);

        await harness.startAndAccept();
        harness.controller.cancel();
        expect(harness.controller.state, EatingSessionState.idle);

        await harness.startAndAccept();
        harness.controller.onGesture('fist');
        harness.controller.onGesture('fist');
        await _pump();
        final endingTask = harness.intents.last.taskId;
        harness.controller.cancel();
        expect(harness.controller.state, EatingSessionState.idle);
        expect(harness.acknowledge(taskId: endingTask), isFalse);
      },
    );

    test('does not start on one open palm or an OK gesture', () async {
      final harness = _Harness(sessionId: 'meal_gesture_guard');
      addTearDown(harness.dispose);

      harness.controller.onGesture('open_palm');
      harness.controller.onGesture('ok');
      expect(harness.controller.state, EatingSessionState.idle);
      expect(harness.intents, isEmpty);
    });
  });
}

class _Harness {
  _Harness({
    required this.sessionId,
    this.acknowledgementTimeout = const Duration(seconds: 1),
  }) {
    coordinator = CaptureCoordinator(
      config: CaptureCoordinatorConfig(
        acknowledgementTimeout: acknowledgementTimeout,
      ),
      dispatch: (intent) async {
        intents.add(intent);
        return shouldSend;
      },
      taskIdGenerator: () => 'capture_retry_${++taskNumber}',
    );
    controller = EatingSessionController(
      captureCoordinator: coordinator,
      settleDelay: Duration.zero,
      sessionIdGenerator: () => sessionId,
      taskIdGenerator: () => 'capture_task_${++taskNumber}',
    );
  }

  final String sessionId;
  final Duration acknowledgementTimeout;
  final List<CaptureIntent> intents = <CaptureIntent>[];
  late final CaptureCoordinator coordinator;
  late final EatingSessionController controller;
  bool shouldSend = true;
  int taskNumber = 0;

  Future<void> startAndAccept() async {
    controller.onGesture('open_palm');
    controller.onGesture('open_palm');
    await _pump();
    expect(intents, isNotEmpty);
    expect(acknowledge(taskId: intents.last.taskId), isTrue);
    await _pump();
  }

  bool acknowledge({required String taskId}) => coordinator.acknowledge(
    CaptureAcknowledgement(
      taskId: taskId,
      captureType: CaptureType.food,
      scene: intents.last.scene,
      mealSessionId: sessionId,
    ),
    const CaptureQualityResult.accepted(),
  );

  void dispose() {
    controller.dispose();
    coordinator.dispose();
  }
}

Future<void> _pump() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
