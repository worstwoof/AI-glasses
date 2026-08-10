import 'dart:io';

import 'package:ai_glasses_nutrition_app/services/glass_capture_extensions.dart';
import 'package:ai_glasses_nutrition_app/services/glass_receiver_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads captureTaskId from incoming glasses metadata', () {
    final capture = GlassCapture(
      imageFile: File('unused.jpg'),
      metadata: const <String, dynamic>{
        'captureTaskId': 'capture_round_trip_1',
      },
      receivedAt: DateTime(2026, 8, 11),
    );

    expect(capture.captureTaskId, 'capture_round_trip_1');
  });

  test('keeps legacy uploads without captureTaskId compatible', () {
    final capture = GlassCapture(
      imageFile: File('unused.jpg'),
      metadata: const <String, dynamic>{},
      receivedAt: DateTime(2026, 8, 11),
    );

    expect(capture.captureTaskId, isNull);
  });
}
