import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_glasses_nutrition_app/services/food_presence_classifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.aiglasses.nutrition/scene_classifier');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('returns a valid food probability from the platform classifier', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'predictFoodProbability');
          expect(call.arguments, isA<Uint8List>());
          return 0.91;
        });

    final probability = await FoodPresenceClassifier.predictFoodProbability(
      Uint8List.fromList([0xFF, 0xD8, 0xFF]),
    );

    expect(probability, 0.91);
  });

  test('rejects empty image bytes before invoking the platform channel', () {
    expect(
      () => FoodPresenceClassifier.predictFoodProbability(Uint8List(0)),
      throwsArgumentError,
    );
  });

  test('rejects an out-of-range platform probability', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => 1.1);

    await expectLater(
      FoodPresenceClassifier.predictFoodProbability(
        Uint8List.fromList([0xFF, 0xD8, 0xFF]),
      ),
      throwsStateError,
    );
  });
}
