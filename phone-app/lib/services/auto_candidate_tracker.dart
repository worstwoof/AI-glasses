import 'food_scene_classifier.dart';

class AutoCandidateConfig {
  const AutoCandidateConfig({
    this.confidenceThreshold = 0.8,
    this.stableFrames = 2,
    this.cooldown = const Duration(seconds: 8),
  });

  final double confidenceThreshold;
  final int stableFrames;
  final Duration cooldown;
}

class AutoCandidateDecision {
  const AutoCandidateDecision({
    required this.eligible,
    required this.stableFrames,
    required this.confidence,
    required this.duplicate,
  });

  final bool eligible;
  final int stableFrames;
  final double confidence;
  final bool duplicate;
}

class AutoCandidateTracker {
  AutoCandidateTracker({this.config = const AutoCandidateConfig()});

  final AutoCandidateConfig config;
  int _consecutiveFoodHits = 0;
  double _latestConfidence = 0;
  DateTime? _lastAutomaticAcceptedAt;
  String? _lastAcceptedFingerprint;

  int get consecutiveFoodHits => _consecutiveFoodHits;
  double get latestConfidence => _latestConfidence;
  DateTime? get lastAutomaticAcceptedAt => _lastAutomaticAcceptedAt;

  AutoCandidateDecision observe(
    FoodSceneResult result, {
    required DateTime now,
    required String frameFingerprint,
  }) {
    _latestConfidence = result.confidence;
    if (!result.isFoodScene || result.confidence < config.confidenceThreshold) {
      _consecutiveFoodHits = 0;
      return AutoCandidateDecision(
        eligible: false,
        stableFrames: _consecutiveFoodHits,
        confidence: result.confidence,
        duplicate: false,
      );
    }

    _consecutiveFoodHits += 1;
    final duplicate = frameFingerprint.isNotEmpty &&
        frameFingerprint == _lastAcceptedFingerprint;
    final cooldownActive = _lastAutomaticAcceptedAt != null &&
        now.difference(_lastAutomaticAcceptedAt!) < config.cooldown;
    return AutoCandidateDecision(
      eligible: _consecutiveFoodHits >= config.stableFrames &&
          !duplicate &&
          !cooldownActive,
      stableFrames: _consecutiveFoodHits,
      confidence: result.confidence,
      duplicate: duplicate,
    );
  }

  void markAccepted(DateTime now, String frameFingerprint) {
    _lastAutomaticAcceptedAt = now;
    _lastAcceptedFingerprint = frameFingerprint;
    _consecutiveFoodHits = 0;
  }

  void reset() {
    _consecutiveFoodHits = 0;
    _latestConfidence = 0;
  }
}
