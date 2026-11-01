import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_glasses_nutrition_app/services/food_scene_classifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.aiglasses.nutrition/scene_classifier');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('initializes the native CPU model and classifies a JPEG', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'foodModelStatus') {
            return <String, Object?>{
              'loaded': true,
              'runtime': 'cpu',
              'inputShape': [1, 224, 224, 3],
              'outputShape': [1, 3],
            };
          }
          expect(call.method, 'predictFoodProbability');
          expect(call.arguments, isA<Uint8List>());
          return 0.91;
        });

    final classifier = TfliteFoodSceneClassifier();
    await classifier.initialize();
    final result = await classifier.classify(
      Uint8List.fromList([0xFF, 0xD8, 0xFF]),
    );

    expect(classifier.isAvailable, isTrue);
    expect(classifier.runtimeDescription, 'cpu');
    expect(result.isFoodScene, isTrue);
    expect(result.foodProbability, 0.91);
  });

  test(
    'latches an initialization failure and does not retry each frame',
    () async {
      var statusCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'foodModelStatus');
            statusCalls += 1;
            return <String, Object?>{
              'loaded': false,
              'runtime': 'cpu',
              'error': 'CPU model initialization failed',
            };
          });

      final classifier = TfliteFoodSceneClassifier();
      await expectLater(classifier.initialize(), throwsStateError);
      await expectLater(
        classifier.classify(Uint8List.fromList([0xFF, 0xD8, 0xFF])),
        throwsStateError,
      );

      expect(statusCalls, 1);
      expect(classifier.isAvailable, isFalse);
    },
  );
}
