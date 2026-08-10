import '../packaging_models.dart';
import 'glass_receiver_service.dart';

extension GlassCapturePackagingMetadata on GlassCapture {
  CaptureType get captureType => CaptureType.fromWireValue(metadata['type']);

  String get captureSource =>
      metadata['captureSource']?.toString() ?? 'unknown';

  String? get mealSessionId => metadata['mealSessionId']?.toString();

  String? get captureTaskId => metadata['captureTaskId']?.toString();

  int? get width => _metadataInt('width');

  int? get height => _metadataInt('height');

  bool get isLowResolutionFallback {
    if (captureSource == 'preview_fallback') return true;
    final dimensions = [width, height].whereType<int>().toList();
    return dimensions.length == 2 && dimensions.every((value) => value <= 640);
  }

  int? _metadataInt(String key) {
    final value = metadata[key];
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }
}
