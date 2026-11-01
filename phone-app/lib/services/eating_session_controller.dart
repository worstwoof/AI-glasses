import 'dart:async';
import 'dart:developer' as developer;

import '../packaging_models.dart';
import 'capture_coordinator.dart';
import 'capture_intent.dart';

enum EatingSessionState {
  idle,
  starting,
  eating,
  afterCandidateCapturing,
  afterCandidateReady,
  ending,
}

class EatingSessionSnapshot {
  const EatingSessionSnapshot({
    required this.state,
    required this.mealSessionId,
    required this.lastCompletedSessionId,
    required this.pendingScene,
    required this.pendingTaskId,
    required this.errorMessage,
  });

  final EatingSessionState state;
  final String? mealSessionId;
  final String? lastCompletedSessionId;
  final String? pendingScene;
  final String? pendingTaskId;
  final String? errorMessage;

  String get displayState => state.name.toUpperCase();
}

typedef SessionIdGenerator = String Function();
typedef SessionTaskIdGenerator = String Function();

/// Owns the meal state machine for both explicit gestures and automatic
/// candidates. Physical capture timing, acknowledgement matching, retry, and
/// cancellation belong to [CaptureCoordinator].
class EatingSessionController {
  EatingSessionController({
    required CaptureCoordinator captureCoordinator,
    this.settleDelay = const Duration(seconds: 2),
    SessionIdGenerator? sessionIdGenerator,
    SessionTaskIdGenerator? taskIdGenerator,
    void Function(EatingSessionSnapshot snapshot)? onChanged,
  }) : _captureCoordinator = captureCoordinator,
       _sessionIdGenerator = sessionIdGenerator ?? _defaultSessionId,
       _taskIdGenerator = taskIdGenerator ?? _defaultTaskId,
       _onChanged = onChanged;

  static const requiredGestureHits = 2;
  static const _mealRetakePolicy = CaptureRetryPolicy(maxRetakes: 2);

  final CaptureCoordinator _captureCoordinator;
  final SessionIdGenerator _sessionIdGenerator;
  final SessionTaskIdGenerator _taskIdGenerator;
  final void Function(EatingSessionSnapshot snapshot)? _onChanged;
  final Duration settleDelay;

  EatingSessionState _state = EatingSessionState.idle;
  String? _mealSessionId;
  String? _lastCompletedSessionId;
  String? _pendingScene;
  String? _pendingTaskId;
  String? _errorMessage;
  int _openPalmHits = 0;
  int _fistHits = 0;
  int _operationToken = 0;
  bool _disposed = false;

  EatingSessionState get state => _state;
  String? get mealSessionId => _mealSessionId;
  String? get lastCompletedSessionId => _lastCompletedSessionId;
  String? get errorMessage => _errorMessage;

  EatingSessionSnapshot get snapshot => EatingSessionSnapshot(
    state: _state,
    mealSessionId: _mealSessionId,
    lastCompletedSessionId: _lastCompletedSessionId,
    pendingScene: _pendingScene,
    pendingTaskId: _pendingTaskId,
    errorMessage: _errorMessage,
  );

  void onGesture(String gesture) {
    final normalized = gesture.trim().toLowerCase();
    switch (_state) {
      case EatingSessionState.idle:
        _fistHits = 0;
        if (normalized == 'open_palm') {
          _openPalmHits += 1;
          _log('[Gesture] OPEN_PALM $_openPalmHits/$requiredGestureHits');
          if (_openPalmHits >= requiredGestureHits) _beginSession();
        } else {
          _openPalmHits = 0;
        }
      case EatingSessionState.starting:
        _openPalmHits = 0;
        _fistHits = 0;
      case EatingSessionState.eating:
        _openPalmHits = 0;
        if (normalized == 'fist') {
          _fistHits += 1;
          _log('[Gesture] FIST $_fistHits/$requiredGestureHits');
          if (_fistHits >= requiredGestureHits) _beginEnding();
        } else {
          _fistHits = 0;
        }
      case EatingSessionState.afterCandidateReady:
        _openPalmHits = 0;
        if (normalized == 'fist') {
          _fistHits += 1;
          _log(
            '[Gesture] FIST $_fistHits/$requiredGestureHits confirm candidate',
          );
          if (_fistHits >= requiredGestureHits) confirmMealAfterCandidate();
        } else {
          _fistHits = 0;
        }
      case EatingSessionState.afterCandidateCapturing:
        _openPalmHits = 0;
        if (normalized == 'fist') {
          _fistHits += 1;
          _log(
            '[Gesture] FIST $_fistHits/$requiredGestureHits overrides candidate',
          );
          if (_fistHits >= requiredGestureHits) _beginEnding();
        } else {
          _fistHits = 0;
        }
      case EatingSessionState.ending:
        _openPalmHits = 0;
        _fistHits = 0;
    }
  }

  /// Starts a meal from a stable automatic food candidate.
  Future<CaptureTaskResult?> startAutomaticSession() async {
    if (_state != EatingSessionState.idle || _disposed) return null;
    _beginSession(
      source: CaptureIntentSource.automatic,
      trigger: 'auto_food_scene',
    );
    final result = _pendingResult;
    return result == null ? null : await result;
  }

  /// Requests an automatic post-meal candidate without closing the session.
  Future<CaptureTaskResult?> requestAutomaticAfterCandidate() async {
    if (_state != EatingSessionState.eating || _disposed) return null;
    _pendingScene = 'meal_after_candidate';
    _errorMessage = null;
    _state = EatingSessionState.afterCandidateCapturing;
    _emit();
    final result = await _submitMealCapture(
      scene: 'meal_after_candidate',
      trigger: 'auto_meal_end_candidate',
      source: CaptureIntentSource.automatic,
      priority: CapturePriority.automatic,
      cooldownGroup: CaptureCooldownGroup.automaticFood,
    );
    if (_disposed || _state != EatingSessionState.afterCandidateCapturing) {
      return result;
    }
    if (result?.accepted == true) {
      _state = EatingSessionState.afterCandidateReady;
      _pendingScene = 'meal_after_candidate';
      _pendingTaskId = null;
      _emit();
    } else {
      _state = EatingSessionState.eating;
      _pendingScene = null;
      _pendingTaskId = null;
      _errorMessage = '餐后候选抓拍失败，请继续进食或手动结束';
      _emit();
    }
    return result;
  }

  /// Promotes a previously accepted candidate without taking another photo.
  void confirmMealAfterCandidate() {
    if (_state != EatingSessionState.afterCandidateReady) return;
    final sessionId = _mealSessionId;
    if (sessionId == null) return;
    _operationToken += 1;
    _pendingScene = null;
    _pendingTaskId = null;
    _lastCompletedSessionId = sessionId;
    _mealSessionId = null;
    _state = EatingSessionState.idle;
    _fistHits = 0;
    _openPalmHits = 0;
    _errorMessage = null;
    _emit();
  }

  void cancelMealAfterCandidate() {
    if (_state != EatingSessionState.afterCandidateReady) return;
    _pendingScene = null;
    _pendingTaskId = null;
    _state = EatingSessionState.eating;
    _fistHits = 0;
    _errorMessage = null;
    _emit();
  }

  /// Cancels queued, delayed, or awaiting-ACK meal tasks and ignores late ACKs.
  void cancel() {
    final sessionId = _mealSessionId;
    if (_state == EatingSessionState.idle || sessionId == null) return;
    _operationToken += 1;
    _captureCoordinator.cancelWhere(
      (intent) => intent.mealSessionId == sessionId,
    );
    _state = EatingSessionState.idle;
    _mealSessionId = null;
    _pendingScene = null;
    _pendingTaskId = null;
    _openPalmHits = 0;
    _fistHits = 0;
    _errorMessage = '本次进食采集已取消';
    _emit();
  }

  void onConnectionLost() {
    if (_state == EatingSessionState.starting ||
        _state == EatingSessionState.afterCandidateCapturing) {
      _failPendingCapture('connection lost during meal start');
    } else if (_state == EatingSessionState.ending) {
      _failPendingCapture('connection lost during meal end');
    }
  }

  void dispose() {
    _disposed = true;
    _operationToken += 1;
  }

  Future<CaptureTaskResult?>? _pendingResult;

  void _beginSession({
    CaptureIntentSource source = CaptureIntentSource.mealControl,
    String trigger = 'meal_start',
  }) {
    _openPalmHits = 0;
    _fistHits = 0;
    _mealSessionId = _sessionIdGenerator();
    _pendingScene = 'meal_before';
    _errorMessage = null;
    _state = EatingSessionState.starting;
    _log('[EatingSession] IDLE -> STARTING session=$_mealSessionId');
    _emit();
    _pendingResult = _submitMealCapture(
      scene: 'meal_before',
      trigger: trigger,
      source: source,
      priority: source == CaptureIntentSource.automatic
          ? CapturePriority.automatic
          : CapturePriority.mealControl,
      cooldownGroup: source == CaptureIntentSource.automatic
          ? CaptureCooldownGroup.automaticFood
          : CaptureCooldownGroup.none,
    );
  }

  void _beginEnding() {
    _fistHits = 0;
    final sessionId = _mealSessionId;
    if (sessionId == null) return;
    // A command already sent to the glasses must be allowed to finish. The
    // coordinator will then dispatch the critical meal-after task; queued or
    // delayed automatic work is cancelled immediately.
    _captureCoordinator.cancelPendingWhere(
      (intent) => intent.mealSessionId == sessionId && intent.isAutomaticOrigin,
    );
    _pendingScene = 'meal_after';
    _errorMessage = null;
    _state = EatingSessionState.ending;
    _log('[EatingSession] EATING -> ENDING session=$sessionId');
    _emit();
    _pendingResult = _submitMealCapture(
      scene: 'meal_after',
      trigger: 'meal_end',
      source: CaptureIntentSource.mealControl,
      priority: CapturePriority.critical,
      cooldownGroup: CaptureCooldownGroup.none,
    );
  }

  Future<CaptureTaskResult?> _submitMealCapture({
    required String scene,
    required String trigger,
    required CaptureIntentSource source,
    required CapturePriority priority,
    required CaptureCooldownGroup cooldownGroup,
  }) async {
    final sessionId = _mealSessionId;
    if (_disposed || sessionId == null) return null;
    final taskId = _taskIdGenerator();
    final token = ++_operationToken;
    _pendingTaskId = taskId;
    _log('[MealCapture] $scene submitted task=$taskId session=$sessionId');
    final resultFuture = _captureCoordinator.submit(
      CaptureIntent(
        taskId: taskId,
        captureType: CaptureType.food,
        trigger: trigger,
        scene: scene,
        mealSessionId: sessionId,
        source: source,
        priority: priority,
        delay: settleDelay,
        cooldownGroup: cooldownGroup,
        qualityPolicy: CaptureQualityPolicy.forScene(scene),
        retryPolicy: _mealRetakePolicy,
      ),
    );
    unawaited(
      _awaitCaptureResult(
        token: token,
        expectedScene: scene,
        sessionId: sessionId,
        resultFuture: resultFuture,
      ),
    );
    return resultFuture;
  }

  Future<void> _awaitCaptureResult({
    required int token,
    required String expectedScene,
    required String sessionId,
    required Future<CaptureTaskResult> resultFuture,
  }) async {
    final result = await resultFuture;
    if (_disposed ||
        token != _operationToken ||
        _pendingScene != expectedScene ||
        _mealSessionId != sessionId) {
      return;
    }
    if (!result.accepted) {
      _failPendingCapture(
        '$expectedScene ${result.state.name}: ${result.message ?? 'capture failed'}',
      );
      return;
    }

    _log('[MealCapture] $expectedScene accepted session=$sessionId');
    _pendingScene = null;
    _pendingTaskId = null;
    _errorMessage = null;
    if (expectedScene == 'meal_before') {
      _state = EatingSessionState.eating;
      _fistHits = 0;
    } else if (expectedScene == 'meal_after_candidate') {
      _state = EatingSessionState.afterCandidateReady;
      _pendingScene = expectedScene;
    } else {
      _state = EatingSessionState.idle;
      _lastCompletedSessionId = sessionId;
      _mealSessionId = null;
      _openPalmHits = 0;
      _fistHits = 0;
    }
    _emit();
  }

  void _failPendingCapture(String message) {
    final pendingScene = _pendingScene;
    if (pendingScene == null) return;
    final sessionId = _mealSessionId;
    _operationToken += 1;
    if (sessionId != null) {
      _captureCoordinator.cancelWhere(
        (intent) =>
            intent.mealSessionId == sessionId && intent.scene == pendingScene,
      );
    }
    final wasEnding = _state == EatingSessionState.ending;
    final wasCandidate =
        _state == EatingSessionState.afterCandidateCapturing ||
        pendingScene == 'meal_after_candidate';
    _pendingScene = null;
    _pendingTaskId = null;
    _state = wasEnding || wasCandidate
        ? EatingSessionState.eating
        : EatingSessionState.idle;
    _errorMessage = wasCandidate
        ? '餐后候选抓拍失败，请继续进食或手动结束'
        : wasEnding
        ? '餐后抓拍失败，请再次握拳结束'
        : '餐前抓拍失败，请重新张手开始';
    _log('[MealCapture] failed reason=$message session=$sessionId');
    _openPalmHits = 0;
    _fistHits = 0;
    if (_state == EatingSessionState.idle) _mealSessionId = null;
    _emit();
  }

  void _emit() => _onChanged?.call(snapshot);

  void _log(String message) => developer.log(message, name: 'EatingSession');

  static String _defaultSessionId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'meal_${now}_${now % 997}';
  }

  static String _defaultTaskId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'capture_${now}_${now % 997}';
  }
}
