import 'package:flutter_test/flutter_test.dart';

import 'package:ai_glasses_nutrition_app/services/packaging_analysis_route_gate.dart';

void main() {
  test('allows one packaging analysis route until the active route closes', () {
    final gate = PackagingAnalysisRouteGate();

    expect(gate.tryOpen(), isTrue);
    expect(gate.tryOpen(), isFalse);

    gate.close();

    expect(gate.tryOpen(), isTrue);
  });
}
