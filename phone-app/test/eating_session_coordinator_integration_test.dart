import 'package:flutter_test/flutter_test.dart';

import 'package:ai_glasses_nutrition_app/packaging_models.dart';
import 'package:ai_glasses_nutrition_app/services/capture_coordinator.dart';
import 'package:ai_glasses_nutrition_app/services/capture_intent.dart';
import 'package:ai_glasses_nutrition_app/services/capture_quality_evaluator.dart';
import 'package:ai_glasses_nutrition_app/services/eating_session_controller.dart';

void main() {
  test('meal start waits for the coordinator exact acknowledgement', () async {
    final dispatched = <CaptureIntent>[];
    final coordinator = CaptureCoordinator(
      dispatch: (intent) async {
        dispatched.add(intent);
        return true;
      },
    );
    final controller = EatingSessionController(
      captureCoordinator: coordinator,
      settleDelay: Duration.zero,
      sessionIdGenerator: () => 'meal_coordinator_test',
      taskIdGenerator: () => 'capture_meal_before',
    );
    addTearDown(() {
      controller.dispose();
      coordinator.dispose();
    });

    controller.onGesture('open_palm');
    controller.onGesture('open_palm');
    await _pump();

    expect(controller.state, EatingSessionState.starting);
    expect(dispatched, hasLength(1));
    expect(dispatched.single.scene, 'meal_before');
    expect(dispatched.single.mealSessionId, 'meal_coordinator_test');
    expect(dispatched.single.taskId, 'capture_meal_before');

    expect(
      coordinator.acknowledge(
        const CaptureAcknowledgement(
          taskId: 'wrong_task',
          captureType: CaptureType.food,
          scene: 'meal_before',
          mealSessionId: 'meal_coordinator_test',
        ),
        const CaptureQualityResult.accepted(),
      ),
      isFalse,
    );
    expect(controller.state, EatingSessionState.starting);

    expect(
      coordinator.acknowledge(
        const CaptureAcknowledgement(
          taskId: 'capture_meal_before',
          captureType: CaptureType.food,
          scene: 'meal_before',
          mealSessionId: 'meal_coordinator_test',
        ),
        const CaptureQualityResult.accepted(),
      ),
      isTrue,
    );
    await _pump();

    expect(controller.state, EatingSessionState.eating);
  });
}

Future<void> _pump() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
