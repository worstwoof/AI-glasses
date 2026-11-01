import 'package:flutter_test/flutter_test.dart';

import 'package:ai_glasses_nutrition_app/services/capture_mode_controller.dart';
import 'package:ai_glasses_nutrition_app/services/glass_receiver_service.dart';

void main() {
  test(
    'snapshot keeps automatic capture disabled before model initialization',
    () {
      final receiver = GlassReceiverService.instance;

      expect(receiver.snapshot.captureMode, CaptureMode.manual);
      expect(receiver.snapshot.automaticCaptureAvailable, isFalse);
      expect(
        receiver.snapshot.automaticCaptureUnavailableReason,
        contains('初始化'),
      );
      expect(receiver.snapshot.mealDuringCaptures, isEmpty);

      expect(receiver.setCaptureMode(CaptureMode.automatic), isFalse);
      expect(receiver.snapshot.captureMode, CaptureMode.manual);
    },
  );
}
