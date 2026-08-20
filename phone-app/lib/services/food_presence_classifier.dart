import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Runs the bundled food-presence model on the Android phone.
class FoodPresenceClassifier {
  FoodPresenceClassifier._();

  static const MethodChannel _channel = MethodChannel(
    'com.aiglasses.nutrition/scene_classifier',
  );

  static Future<double> predictFoodProbability(Uint8List jpegBytes) async {
    if (jpegBytes.isEmpty) {
      throw ArgumentError.value(jpegBytes, 'jpegBytes', 'JPEG bytes are empty');
    }

    final value = await _channel.invokeMethod<Object?>(
      'predictFoodProbability',
      jpegBytes,
    );
    if (value is! num) {
      throw StateError('手机端食物分类器没有返回概率');
    }

    final probability = value.toDouble();
    if (!probability.isFinite || probability < 0 || probability > 1) {
      throw StateError('手机端食物分类器返回了无效概率：$probability');
    }
    return probability;
  }
}
