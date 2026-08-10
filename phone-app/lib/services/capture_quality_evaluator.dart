import 'capture_intent.dart';

enum CaptureQualityIssue {
  invalidJpeg,
  lowResolution,
  tooDark,
  overExposed,
  blur,
  duplicate,
  notFoodScene,
}

class CaptureQualityConfig {
  const CaptureQualityConfig({
    this.minimumHighResolutionWidth = 1280,
    this.minimumHighResolutionHeight = 720,
    this.minimumBrightness = 0.12,
    this.maximumBrightness = 0.92,
    this.minimumSharpness = 0.12,
  });

  // Prototype defaults; tune against RV101 hardware captures before release.
  final int minimumHighResolutionWidth;
  final int minimumHighResolutionHeight;
  final double minimumBrightness;
  final double maximumBrightness;
  final double minimumSharpness;
}

class CaptureQualityInput {
  const CaptureQualityInput({
    required this.isJpeg,
    required this.width,
    required this.height,
    required this.brightness,
    required this.sharpness,
    this.isDuplicate = false,
    this.foodRelevance,
  });

  final bool isJpeg;
  final int width;
  final int height;
  final double brightness;
  final double sharpness;
  final bool isDuplicate;
  final bool? foodRelevance;
}

class CaptureQualityResult {
  const CaptureQualityResult({
    required this.accepted,
    required this.issues,
    required this.shouldRetake,
  });

  const CaptureQualityResult.accepted()
    : accepted = true,
      issues = const [],
      shouldRetake = false;

  const CaptureQualityResult.rejected(
    List<CaptureQualityIssue> issues, {
    bool shouldRetake = false,
  }) : accepted = false,
       issues = issues,
       shouldRetake = shouldRetake;

  final bool accepted;
  final List<CaptureQualityIssue> issues;
  final bool shouldRetake;
}

class CaptureQualityEvaluator {
  const CaptureQualityEvaluator({this.config = const CaptureQualityConfig()});

  final CaptureQualityConfig config;

  CaptureQualityResult evaluate(
    CaptureQualityInput input,
    CaptureQualityPolicy policy,
  ) {
    final issues = <CaptureQualityIssue>[];
    if (!input.isJpeg) issues.add(CaptureQualityIssue.invalidJpeg);
    if (policy.requireHighResolution &&
        (input.width < config.minimumHighResolutionWidth ||
            input.height < config.minimumHighResolutionHeight)) {
      issues.add(CaptureQualityIssue.lowResolution);
    }
    if (input.brightness < config.minimumBrightness) {
      issues.add(CaptureQualityIssue.tooDark);
    } else if (input.brightness > config.maximumBrightness) {
      issues.add(CaptureQualityIssue.overExposed);
    }
    if (input.sharpness < config.minimumSharpness) {
      issues.add(CaptureQualityIssue.blur);
    }
    if (policy.checkDuplicate && input.isDuplicate) {
      issues.add(CaptureQualityIssue.duplicate);
    }
    if (policy.requireFoodRelevance && input.foodRelevance == false) {
      issues.add(CaptureQualityIssue.notFoodScene);
    }
    if (issues.isEmpty) return const CaptureQualityResult.accepted();
    return CaptureQualityResult.rejected(
      issues,
      shouldRetake: policy.allowsRetake,
    );
  }
}
