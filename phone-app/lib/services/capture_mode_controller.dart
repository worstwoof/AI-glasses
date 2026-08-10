import 'food_scene_classifier.dart';

enum CaptureMode { manual, automatic, hybrid }

class CaptureModeController {
  CaptureModeController({required this.classifier});

  final FoodSceneClassifier classifier;
  CaptureMode _mode = CaptureMode.manual;

  CaptureMode get mode => _mode;

  bool get automaticAvailable => classifier.isAvailable;

  String get unavailableReason => classifier.unavailableReason;

  bool canSelect(CaptureMode candidate) =>
      candidate == CaptureMode.manual || classifier.isAvailable;

  bool setMode(CaptureMode candidate) {
    if (!canSelect(candidate)) return false;
    _mode = candidate;
    return true;
  }
}
