import 'dart:typed_data';

class FoodSceneResult {
  const FoodSceneResult({
    required this.isFoodScene,
    required this.confidence,
  });

  final bool isFoodScene;
  final double confidence;
}

abstract class FoodSceneClassifier {
  bool get isAvailable;

  String get unavailableReason;

  Future<FoodSceneResult> classify(Uint8List jpegBytes);
}

/// Deliberate production fallback until a separately supplied food/not-food
/// TFLite model is integrated. Gesture output must never stand in for it.
class UnavailableFoodSceneClassifier implements FoodSceneClassifier {
  const UnavailableFoodSceneClassifier();

  @override
  bool get isAvailable => false;

  @override
  String get unavailableReason => '食品场景模型未加载，自动采集不可用。';

  @override
  Future<FoodSceneResult> classify(Uint8List jpegBytes) {
    throw StateError(unavailableReason);
  }
}
