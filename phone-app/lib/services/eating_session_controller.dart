import 'dart:async';

enum EatingSessionState { idle, starting, eating, ending }

class MealCaptureCommand {
  const MealCaptureCommand({
    required this.captureType,
    required this.trigger,
    required this.scene,
    required this.mealSessionId,
  });

  final String captureType;
  final String trigger;
  final String scene;
  final String mealSessionId;
}

class MealCaptureAcknowledgement {
  const MealCaptureAcknowledgement({
    required this.captureType,
    required this.scene,
    required this.mealSessionId,
  });

  final String captureType;
  final String scene;
  final String mealSessionId;
}

class EatingSessionSnapshot {
  const EatingSessionSnapshot({
    required this.state,
    required this.mealSessionId,
    required this.lastCompletedSessionId,
    required this.pendingScene,
    required this.errorMessage,
  });

  final EatingSessionState state;
  final String? mealSessionId;
  final String? lastCompletedSessionId;
  final String? pendingScene;
  final String? errorMessage;

  String get displayState => state.name.toUpperCase();
}

typedef MealCaptureSender = Future<bool> Function(MealCaptureCommand command);
typedef SessionIdGenerator = String Function();

class EatingSessionController {
  EatingSessionController({
    required MealCaptureSender sendCapture,
    this.settleDelay = const Duration(seconds: 2),
    this.acknowledgementTimeout = const Duration(seconds: 12),
    SessionIdGenerator? sessionIdGenerator,
    void Function(EatingSessionSnapshot snapshot)? onChanged,
  }) : _sendCapture = sendCapture,
       _sessionIdGenerator = sessionIdGenerator ?? _defaultSessionId,
       _onChanged = onChanged;

  static const requiredGestureHits = 2;

  final MealCaptureSender _sendCapture;
  final SessionIdGenerator _sessionIdGenerator;
  final void Function(EatingSessionSnapshot snapshot)? _onChanged;
  final Duration settleDelay;
  final Duration acknowledgementTimeout;

  EatingSessionState _state = EatingSessionState.idle;
  String? _mealSessionId;
  String? _lastCompletedSessionId;
  String? _pendingScene;
  String? _errorMessage;
  int _openPalmHits = 0;
  int _fistHits = 0;
  int _operationToken = 0;
  Timer? _settleTimer;
  Timer? _acknowledgementTimer;

  EatingSessionState get state => _state;
  String? get mealSessionId => _mealSessionId;
  String? get lastCompletedSessionId => _lastCompletedSessionId;
  String? get errorMessage => _errorMessage;

  EatingSessionSnapshot get snapshot => EatingSessionSnapshot(
    state: _state,
    mealSessionId: _mealSessionId,
    lastCompletedSessionId: _lastCompletedSessionId,
    pendingScene: _pendingScene,
    errorMessage: _errorMessage,
  );

  void onGesture(String gesture) {
    final normalized = gesture.trim().toLowerCase();
    switch (_state) {
      case EatingSessionState.idle:
        _fistHits = 0;
        if (normalized == 'open_palm') {
          _openPalmHits += 1;
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
          if (_fistHits >= requiredGestureHits) _beginEnding();
        } else {
          _fistHits = 0;
        }
      case EatingSessionState.ending:
        _openPalmHits = 0;
        _fistHits = 0;
    }
  }

  bool onCaptureReceived(MealCaptureAcknowledgement acknowledgement) {
    final expectedScene = _pendingScene;
    final sessionId = _mealSessionId;
    if (expectedScene == null || sessionId == null) return false;
    if (acknowledgement.captureType != 'food' ||
        acknowledgement.scene != expectedScene ||
        acknowledgement.mealSessionId != sessionId) {
      return false;
    }

    _cancelAcknowledgementTimer();
    _operationToken += 1;
    _pendingScene = null;
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
    return true;
  }

  void onConnectionLost() {
    if (_state == EatingSessionState.starting) {
      _failPendingCapture('connection lost during meal start');
    } else if (_state == EatingSessionState.ending) {
      _failPendingCapture('connection lost during meal end');
    }
  }

  void dispose() {
    _settleTimer?.cancel();
    _acknowledgementTimer?.cancel();
    _operationToken += 1;
  }

  void _beginSession() {
    _openPalmHits = 0;
    _fistHits = 0;
    _mealSessionId = _sessionIdGenerator();
    _pendingScene = 'meal_before';
    _errorMessage = null;
    _state = EatingSessionState.starting;
    _emit();
    _scheduleCapture(
      expectedState: EatingSessionState.starting,
      scene: 'meal_before',
      trigger: 'meal_start',
    );
  }

  void _beginEnding() {
    _fistHits = 0;
    _pendingScene = 'meal_after';
    _errorMessage = null;
    _state = EatingSessionState.ending;
    _emit();
    _scheduleCapture(
      expectedState: EatingSessionState.ending,
      scene: 'meal_after',
      trigger: 'meal_end',
    );
  }

  void _scheduleCapture({
    required EatingSessionState expectedState,
    required String scene,
    required String trigger,
  }) {
    _settleTimer?.cancel();
    final token = ++_operationToken;
    _settleTimer = Timer(settleDelay, () {
      if (token != _operationToken ||
          _state != expectedState ||
          _pendingScene != scene ||
          _mealSessionId == null) {
        return;
      }
      unawaited(_sendScheduledCapture(token, scene, trigger));
    });
  }

  Future<void> _sendScheduledCapture(
    int token,
    String scene,
    String trigger,
  ) async {
    final sessionId = _mealSessionId;
    if (sessionId == null) return;
    final command = MealCaptureCommand(
      captureType: 'food',
      trigger: trigger,
      scene: scene,
      mealSessionId: sessionId,
    );
    bool sent = false;
    try {
      sent = await _sendCapture(command);
    } catch (_) {
      sent = false;
    }
    if (token != _operationToken ||
        _pendingScene != scene ||
        _mealSessionId != sessionId) {
      return;
    }
    if (!sent) {
      _failPendingCapture('$trigger send failed: 发送失败');
      return;
    }
    _acknowledgementTimer?.cancel();
    _acknowledgementTimer = Timer(acknowledgementTimeout, () {
      if (token == _operationToken && _pendingScene == scene) {
        _failPendingCapture('$trigger acknowledgement timeout');
      }
    });
    _emit();
  }

  void _failPendingCapture(String message) {
    if (_pendingScene == null) return;
    final wasEnding = _state == EatingSessionState.ending;
    _settleTimer?.cancel();
    _cancelAcknowledgementTimer();
    _operationToken += 1;
    _pendingScene = null;
    _errorMessage = message;
    _state = wasEnding ? EatingSessionState.eating : EatingSessionState.idle;
    _openPalmHits = 0;
    _fistHits = 0;
    if (_state == EatingSessionState.idle) _mealSessionId = null;
    _emit();
  }

  void _cancelAcknowledgementTimer() {
    _acknowledgementTimer?.cancel();
    _acknowledgementTimer = null;
  }

  void _emit() => _onChanged?.call(snapshot);

  static String _defaultSessionId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'meal_${now}_${now % 997}';
  }
}
