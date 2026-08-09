import 'package:flutter_test/flutter_test.dart';

import 'package:ai_glasses_nutrition_app/packaging_models.dart';

void main() {
  test(
    'capture type preserves old food behavior and safely handles unknown input',
    () {
      expect(CaptureType.fromWireValue(null), CaptureType.food);
      expect(CaptureType.fromWireValue('food'), CaptureType.food);
      expect(CaptureType.fromWireValue('packaging'), CaptureType.packaging);
      expect(CaptureType.fromWireValue('future_value'), CaptureType.unknown);
    },
  );

  test('packaging capture is never eligible for food analysis', () {
    expect(CaptureType.food.canUseFoodAnalysis, isTrue);
    expect(CaptureType.unknown.canUseFoodAnalysis, isTrue);
    expect(CaptureType.packaging.canUseFoodAnalysis, isFalse);
  });
}
