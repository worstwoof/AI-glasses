import 'food_scene_classifier.dart';

class AutoMealEndConfig {
  const AutoMealEndConfig({
    this.minimumMealDuration = const Duration(minutes: 3),
    this.noHandFrames = 20,
    this.stableFrames = 8,
    this.confirmationDelay = const Duration(seconds: 5),
    this.lastFoodWindow = const Duration(seconds: 10),
    this.candidateExpiry = const Duration(seconds: 60),
  });

  final Duration minimumMealDuration;
  final int noHandFrames;
  final int stableFrames;
  final Duration confirmationDelay;
  final Duration lastFoodWindow;
  final Duration candidateExpiry;
}

class AutoMealEndDecision {
  const AutoMealEndDecision({
    required this.candidateReady,
    required this.noHandFrames,
    required this.stableFrames,
    required this.message,
  });

  final bool candidateReady;
  final int noHandFrames;
  final int stableFrames;
  final String message;
}

/// Detects a possible end of eating from several weak signals. It never
/// claims that a meal is complete; it only authorizes a candidate capture.
class AutoMealEndDetector {
  AutoMealEndDetector({this.config = const AutoMealEndConfig()});

  final AutoMealEndConfig config;
  DateTime? _mealStartedAt;
  DateTime? _lastFoodAt;
  DateTime? _candidateSince;
  int _noHandFrames = 0;
  int _stableFrames = 0;
  bool _requested = false;

  int get noHandFrames => _noHandFrames;
  int get stableFrames => _stableFrames;
  DateTime? get candidateSince => _candidateSince;

  void start(DateTime now) {
    reset();
    _mealStartedAt = now;
  }

  AutoMealEndDecision observe({
    required DateTime now,
    required FoodSceneResult food,
    required int hands,
    required bool frameStable,
  }) {
    final startedAt = _mealStartedAt;
    if (startedAt == null) {
      return const AutoMealEndDecision(
        candidateReady: false,
        noHandFrames: 0,
        stableFrames: 0,
        message: '等待进餐 Session 开始',
      );
    }
    if (food.isFoodScene) _lastFoodAt = now;
    if (hands == 0) {
      _noHandFrames += 1;
    } else {
      _noHandFrames = 0;
    }
    _stableFrames = frameStable ? _stableFrames + 1 : 0;

    if (hands > 0 || !frameStable) {
      _candidateSince = null;
      _requested = false;
    }
    final duration = now.difference(startedAt);
    final foodRecent =
        _lastFoodAt != null &&
        now.difference(_lastFoodAt!) <= config.lastFoodWindow;
    final conditionsMet =
        duration >= config.minimumMealDuration &&
        _noHandFrames >= config.noHandFrames &&
        _stableFrames >= config.stableFrames &&
        foodRecent;
    if (!conditionsMet) {
      return AutoMealEndDecision(
        candidateReady: false,
        noHandFrames: _noHandFrames,
        stableFrames: _stableFrames,
        message: '等待停止进食与稳定餐盘画面',
      );
    }
    _candidateSince ??= now;
    final ready =
        !_requested &&
        now.difference(_candidateSince!) >= config.confirmationDelay;
    if (ready) _requested = true;
    return AutoMealEndDecision(
      candidateReady: ready,
      noHandFrames: _noHandFrames,
      stableFrames: _stableFrames,
      message: ready ? '已生成餐后候选' : '餐后候选确认中',
    );
  }

  bool isCandidateExpired(DateTime now) {
    final since = _candidateSince;
    return since != null && now.difference(since) > config.candidateExpiry;
  }

  void reset() {
    _mealStartedAt = null;
    _lastFoodAt = null;
    _candidateSince = null;
    _noHandFrames = 0;
    _stableFrames = 0;
    _requested = false;
  }
}
