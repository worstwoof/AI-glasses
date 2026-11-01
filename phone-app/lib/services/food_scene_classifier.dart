import 'package:flutter/services.dart';

class FoodSceneResult {
  const FoodSceneResult({
    required this.isFoodScene,
    required this.confidence,
    required this.foodProbability,
  });

  final bool isFoodScene;
  final double confidence;
  final double foodProbability;
}

abstract class FoodSceneClassifier {
  bool get isAvailable;

  String get unavailableReason;

  String get runtimeDescription;

  Future<void> initialize();

  Future<FoodSceneResult> classify(Uint8List jpegBytes);
}

/// Runs the bundled MobileNet food-presence model on the Android phone.
class TfliteFoodSceneClassifier implements FoodSceneClassifier {
  TfliteFoodSceneClassifier({this.threshold = 0.80});

  static const MethodChannel _channel = MethodChannel(
    'com.aiglasses.nutrition/scene_classifier',
  );

  final double threshold;
  bool _initialized = false;
  bool _available = false;
  String _unavailableReason = '食品模型正在初始化';
  String _runtimeDescription = '未初始化';

  @override
  bool get isAvailable => _available;

  @override
  String get unavailableReason => _unavailableReason;

  @override
  String get runtimeDescription => _runtimeDescription;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      if (!_available) throw StateError(_unavailableReason);
      return;
    }
    final raw = await _channel.invokeMapMethod<String, Object?>(
      'foodModelStatus',
    );
    if (raw == null || raw['loaded'] != true) {
      _initialized = true;
      _available = false;
      _unavailableReason = '食品模型不可用：${raw?['error'] ?? '手机端没有返回模型状态'}';
      throw StateError(_unavailableReason);
    }
    _initialized = true;
    _available = true;
    _runtimeDescription = (raw['runtime'] ?? 'cpu').toString();
    _unavailableReason = '';
  }

  @override
  Future<FoodSceneResult> classify(Uint8List jpegBytes) async {
    await initialize();
    if (jpegBytes.isEmpty) {
      throw ArgumentError.value(jpegBytes, 'jpegBytes', 'JPEG bytes are empty');
    }
    final raw = await _channel.invokeMethod<Object?>(
      'predictFoodProbability',
      jpegBytes,
    );
    if (raw is! num) {
      throw StateError('手机端食品模型没有返回概率');
    }
    final probability = raw.toDouble();
    if (!probability.isFinite || probability < 0 || probability > 1) {
      throw StateError('手机端食品模型返回了无效概率：$probability');
    }
    return FoodSceneResult(
      isFoodScene: probability >= threshold,
      confidence: probability,
      foodProbability: probability,
    );
  }
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
  String get runtimeDescription => '不可用';

  @override
  Future<void> initialize() async {}

  @override
  Future<FoodSceneResult> classify(Uint8List jpegBytes) {
    throw StateError(unavailableReason);
  }
}
