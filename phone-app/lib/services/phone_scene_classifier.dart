import 'package:flutter/services.dart';

enum PhoneSceneMode { waiting, ingredientLabel, eating, unknown, error }

class PhoneSceneClassification {
  const PhoneSceneClassification({
    required this.mode,
    required this.label,
    required this.gesture,
    required this.confidence,
    required this.message,
    required this.hands,
    required this.model,
    required this.classifiedAt,
  });

  final PhoneSceneMode mode;
  final String label;
  final String gesture;
  final double confidence;
  final String message;
  final int hands;
  final String model;
  final DateTime? classifiedAt;

  static const waiting = PhoneSceneClassification(
    mode: PhoneSceneMode.waiting,
    label: '等待场景手势',
    gesture: 'waiting',
    confidence: 0,
    message: '手机端模型等待眼镜分类帧',
    hands: 0,
    model: 'phone_mediapipe_hand_landmarker',
    classifiedAt: null,
  );
}

class PhoneSceneClassifier {
  PhoneSceneClassifier._();

  static const MethodChannel _channel = MethodChannel(
    'com.aiglasses.nutrition/scene_classifier',
  );

  static Future<PhoneSceneClassification> classifyJpeg(
    Uint8List jpegBytes,
  ) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'classifyJpeg',
        jpegBytes,
      );
      if (result == null) {
        return _error('手机端分类器没有返回结果');
      }
      return PhoneSceneClassification(
        mode: _parseMode(result['scene']?.toString()),
        label: result['label']?.toString() ?? '未知场景',
        gesture: result['gesture']?.toString() ?? 'unknown',
        confidence: _asDouble(result['confidence']),
        message: result['message']?.toString() ?? '场景分类完成',
        hands: _asInt(result['hands']),
        model: result['model']?.toString() ?? 'phone_mediapipe_hand_landmarker',
        classifiedAt: DateTime.now(),
      );
    } on PlatformException catch (error) {
      return _error('手机端分类失败：${error.message ?? error.code}');
    } catch (error) {
      return _error('手机端分类失败：$error');
    }
  }

  static PhoneSceneClassification _error(String message) {
    return PhoneSceneClassification(
      mode: PhoneSceneMode.error,
      label: '分类器异常',
      gesture: 'error',
      confidence: 0,
      message: message,
      hands: 0,
      model: 'phone_mediapipe_hand_landmarker',
      classifiedAt: DateTime.now(),
    );
  }

  static PhoneSceneMode _parseMode(String? value) {
    switch (value) {
      case 'ingredient_label':
        return PhoneSceneMode.ingredientLabel;
      case 'eating':
        return PhoneSceneMode.eating;
      case 'unknown':
        return PhoneSceneMode.unknown;
      default:
        return PhoneSceneMode.unknown;
    }
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
