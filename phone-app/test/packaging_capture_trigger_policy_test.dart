import 'package:flutter_test/flutter_test.dart';

import 'package:ai_glasses_nutrition_app/services/packaging_capture_trigger_policy.dart';

void main() {
  test('failed automatic capture does not consume cooldown', () {
    final state = PackagingCaptureTriggerState(
      cooldown: const Duration(seconds: 8),
    );
    final first = DateTime(2026, 1, 1, 12);

    expect(state.tryStart(first), isTrue);
    state.complete(sent: false, now: first);
    expect(state.tryStart(first.add(const Duration(seconds: 1))), isTrue);
  });

  test('successful automatic capture consumes cooldown', () {
    final state = PackagingCaptureTriggerState(
      cooldown: const Duration(seconds: 8),
    );
    final first = DateTime(2026, 1, 1, 12);

    expect(state.tryStart(first), isTrue);
    state.complete(sent: true, now: first);
    expect(state.tryStart(first.add(const Duration(seconds: 1))), isFalse);
    expect(state.tryStart(first.add(const Duration(seconds: 8))), isTrue);
  });

  test(
    'automatic capture is suppressed while packaging analysis is active',
    () {
      final state = PackagingCaptureTriggerState();
      state.analysisActive = true;

      expect(state.tryStart(DateTime(2026, 1, 1, 12)), isFalse);

      state.analysisActive = false;
      expect(state.tryStart(DateTime(2026, 1, 1, 12)), isTrue);
    },
  );
}
