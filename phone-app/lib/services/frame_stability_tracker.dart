import 'dart:typed_data';
import 'dart:ui' as ui;

class FrameStabilitySnapshot {
  const FrameStabilitySnapshot({
    required this.stable,
    required this.meanDifference,
    required this.consecutiveStableFrames,
  });

  final bool stable;
  final double meanDifference;
  final int consecutiveStableFrames;
}

/// Compares low-rate preview frames after reducing them to a tiny grayscale
/// image. It is intentionally a motion proxy for candidate detection, not a
/// food segmentation or quantity estimator.
class FrameStabilityTracker {
  FrameStabilityTracker({
    this.threshold = 0.08,
    this.sampleWidth = 32,
    this.sampleHeight = 32,
  });

  final double threshold;
  final int sampleWidth;
  final int sampleHeight;

  List<int>? _previous;
  int _consecutiveStableFrames = 0;

  int get consecutiveStableFrames => _consecutiveStableFrames;

  Future<FrameStabilitySnapshot> observe(Uint8List jpegBytes) async {
    final codec = await ui.instantiateImageCodec(
      jpegBytes,
      targetWidth: sampleWidth,
      targetHeight: sampleHeight,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) {
        _previous = null;
        _consecutiveStableFrames = 0;
        return const FrameStabilitySnapshot(
          stable: false,
          meanDifference: 1,
          consecutiveStableFrames: 0,
        );
      }
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final grayscale = <int>[];
      for (var index = 0; index < bytes.length; index += 4) {
        grayscale.add(
          (0.2126 * bytes[index] +
                  0.7152 * bytes[index + 1] +
                  0.0722 * bytes[index + 2])
              .round(),
        );
      }
      final previous = _previous;
      final difference = previous == null || previous.length != grayscale.length
          ? 1.0
          : _meanDifference(previous, grayscale);
      final stable = previous != null && difference <= threshold;
      _consecutiveStableFrames = stable ? _consecutiveStableFrames + 1 : 0;
      _previous = grayscale;
      return FrameStabilitySnapshot(
        stable: stable,
        meanDifference: difference,
        consecutiveStableFrames: _consecutiveStableFrames,
      );
    } finally {
      image.dispose();
      codec.dispose();
    }
  }

  void reset() {
    _previous = null;
    _consecutiveStableFrames = 0;
  }

  double _meanDifference(List<int> previous, List<int> current) {
    var total = 0;
    for (var index = 0; index < current.length; index++) {
      total += (current[index] - previous[index]).abs();
    }
    return current.isEmpty ? 1 : total / current.length / 255;
  }
}
