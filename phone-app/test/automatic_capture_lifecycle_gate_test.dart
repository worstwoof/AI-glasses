import 'package:flutter_test/flutter_test.dart';

import 'package:ai_glasses_nutrition_app/services/capture_intent.dart';
import 'package:ai_glasses_nutrition_app/services/capture_coordinator.dart';
import 'package:ai_glasses_nutrition_app/services/glass_receiver_service.dart';

void main() {
  test('background blocks new automatic capture commands but leaves manual mode usable', () async {
    final receiver = GlassReceiverService.instance;
    addTearDown(() => receiver.setAutomaticCapturesAllowed(true));

    receiver.setAutomaticCapturesAllowed(false);
    final blocked = await receiver.requestPackagingCapture(
      trigger: 'phone_ok_gesture',
      source: CaptureIntentSource.automatic,
    );

    expect(blocked.state, CaptureTaskState.dropped);
    expect(blocked.message, contains('后台'));
  });
}
