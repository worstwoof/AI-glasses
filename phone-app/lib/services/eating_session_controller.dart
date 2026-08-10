import 'dart:async';
import 'dart:developer' as developer;

import '../packaging_models.dart';
import 'capture_coordinator.dart';
import 'capture_intent.dart';

enum EatingSessionState { idle, starting, eating, ending }

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

/// Owns only the gesture-driven meal state machine. Physical capture timing,
/// acknowledgement matching, retry, and cancellation belong to [CaptureCoordinator].
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
      case EatingSessionState.ending:
        _openPalmHits = 0;
        _fistHits = 0;
    }
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
    if (_state == EatingSessionState.starting) {
      _failPendingCapture('connection lost during meal start');
    } else if (_state == EatingSessionState.ending) {
      _failPendingCapture('connection lost during meal end');
    }
  }

  void dispose() {
    _disposed = true;
    _operationToken += 1;
  }

  void _beginSession() {
    _openPalmHits = 0;
    _fistHits = 0;
    _mealSessionId = _sessionIdGenerator();
    _pendingScene = 'meal_before';
    _errorMessage = null;
    _state = EatingSessionState.starting;
    _log('[EatingSession] IDLE -> STARTING session=$_mealSessionId');
    _emit();
    _submitMealCapture(scene: 'meal_before', trigger: 'meal_start');
  }

  void _beginEnding() {
    _fistHits = 0;
    final sessionId = _mealSessionId;
    if (sessionId == null) return;
    _captureCoordinator.cancelWhere(
      (intent) =>
          intent.mealSessionId == sessionId &&
          intent.source == CaptureIntentSource.automatic,
    );
    _pendingScene = 'meal_after';
    _errorMessage = null;
    _state = EatingSessionState.ending;
    _log('[EatingSession] EATING -> ENDING session=$sessionId');
    _emit();
    _submitMealCapture(scene: 'meal_after', trigger: 'meal_end');
  }

  void _submitMealCapture({required String scene, required String trigger}) {
    final sessionId = _mealSessionId;
    if (_disposed || sessionId == null) return;
    final taskId = _taskIdGenerator();
    final token = ++_operationToken;
    _pendingTaskId = taskId;
    _log('[MealCapture] $scene submitted task=$taskId session=$sessionId');
    unawaited(
      _awaitCaptureResult(
        token: token,
        expectedScene: scene,
        sessionId: sessionId,
        intent: CaptureIntent(
          taskId: taskId,
          captureType: CaptureType.food,
          trigger: trigger,
          scene: scene,
          mealSessionId: sessionId,
          source: CaptureIntentSource.mealControl,
          priority: scene == 'meal_after'
              ? CapturePriority.critical
              : CapturePriority.mealControl,
          delay: settleDelay,
          cooldownGroup: CaptureCooldownGroup.none,
          qualityPolicy: CaptureQualityPolicy.forScene(scene),
          retryPolicy: _mealRetakePolicy,
        ),
      ),
    );
  }

  Future<void> _awaitCaptureResult({
    required int token,
    required String expectedScene,
    required String sessionId,
    required CaptureIntent intent,
  }) async {
    final result = await _captureCoordinator.submit(intent);
    if (_disposed ||
        token != _operationToken ||
        _pendingScene != expectedScene ||
        _mealSessionId != sessionId) {
      return;
    }
    if (!result.accepted) {
      _failPendingCapture(
        '${intent.trigger} ${result.state.name}: ${result.message ?? 'capture failed'}',
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
    _pendingScene = null;
    _pendingTaskId = null;
    _state = wasEnding ? EatingSessionState.eating : EatingSessionState.idle;
    _errorMessage = wasEnding ? '餐后抓拍失败，请再次握拳结束' : '餐前抓拍失败，请重新张手开始';
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
