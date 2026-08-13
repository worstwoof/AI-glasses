import 'dart:async';
import 'dart:collection';

import '../packaging_models.dart';
import 'capture_intent.dart';
import 'capture_quality_evaluator.dart';

enum CaptureTaskState {
  queued,
  waitingDelay,
  dispatching,
  waitingAck,
  qualityChecking,
  accepted,
  retrying,
  cancelled,
  dropped,
  failed,
}

class CaptureAcknowledgement {
  const CaptureAcknowledgement({
    required this.taskId,
    required this.captureType,
    required this.scene,
    required this.mealSessionId,
  });

  final String? taskId;
  final CaptureType captureType;
  final String scene;
  final String? mealSessionId;
}

class CaptureTaskResult {
  const CaptureTaskResult({
    required this.taskId,
    required this.state,
    this.message,
  });

  final String taskId;
  final CaptureTaskState state;
  final String? message;

  bool get accepted => state == CaptureTaskState.accepted;
}

class CaptureCoordinatorSnapshot {
  const CaptureCoordinatorSnapshot({
    required this.state,
    required this.taskId,
    required this.scene,
    required this.queueLength,
  });

  final CaptureTaskState? state;
  final String? taskId;
  final String? scene;
  final int queueLength;
}

class CaptureCoordinatorConfig {
  const CaptureCoordinatorConfig({
    this.acknowledgementTimeout = const Duration(seconds: 12),
    this.automaticCooldown = const Duration(seconds: 8),
    this.packagingCooldown = const Duration(seconds: 8),
    this.completedTaskHistoryLimit = 512,
  });

  final Duration acknowledgementTimeout;
  final Duration automaticCooldown;
  final Duration packagingCooldown;
  final int completedTaskHistoryLimit;
}

typedef CaptureDispatcher = Future<bool> Function(CaptureIntent intent);
typedef CaptureTaskIdGenerator = String Function();
typedef CaptureDispatchEligibility = bool Function(CaptureIntent intent);

class CaptureCoordinator {
  CaptureCoordinator({
    required CaptureDispatcher dispatch,
    this.config = const CaptureCoordinatorConfig(),
    DateTime Function()? now,
    CaptureTaskIdGenerator? taskIdGenerator,
    CaptureDispatchEligibility? isDispatchAllowed,
    void Function(CaptureCoordinatorSnapshot snapshot)? onChanged,
  }) : _dispatch = dispatch,
       _now = now ?? DateTime.now,
       _taskIdGenerator = taskIdGenerator ?? _defaultTaskId,
       _isDispatchAllowed = isDispatchAllowed ?? _allowDispatch,
       _onChanged = onChanged;

  final CaptureDispatcher _dispatch;
  final CaptureCoordinatorConfig config;
  final DateTime Function() _now;
  final CaptureTaskIdGenerator _taskIdGenerator;
  final CaptureDispatchEligibility _isDispatchAllowed;
  final void Function(CaptureCoordinatorSnapshot snapshot)? _onChanged;
  final List<_CaptureJob> _queue = <_CaptureJob>[];
  final Map<CaptureCooldownGroup, DateTime> _cooldownUntil =
      <CaptureCooldownGroup, DateTime>{};
  final Set<String> _inFlightTaskIds = <String>{};
  final Set<String> _completedTaskIds = <String>{};
  final Queue<String> _completedTaskIdOrder = Queue<String>();
  _CaptureJob? _active;
  Timer? _delayTimer;
  Timer? _acknowledgementTimer;
  bool _disposed = false;

  CaptureCoordinatorSnapshot get snapshot => CaptureCoordinatorSnapshot(
    state: _active?.state,
    taskId: _active?.intent.taskId,
    scene: _active?.intent.scene,
    queueLength: _queue.length,
  );

  CaptureIntent? get activeIntent => _active?.intent;

  Future<CaptureTaskResult> submit(CaptureIntent intent) {
    if (_disposed) {
      return Future<CaptureTaskResult>.value(
        CaptureTaskResult(
          taskId: intent.taskId,
          state: CaptureTaskState.failed,
          message: 'CaptureCoordinator has been disposed',
        ),
      );
    }
    if (!_reserveTaskId(intent.taskId)) {
      return Future<CaptureTaskResult>.value(
        CaptureTaskResult(
          taskId: intent.taskId,
          state: CaptureTaskState.dropped,
          message: 'duplicate capture task ID',
        ),
      );
    }
    final job = _CaptureJob(intent);
    _preemptDelayedAutomaticFor(intent);
    _queue.add(job);
    _queue.sort(
      (a, b) => a.intent.priority.rank.compareTo(b.intent.priority.rank),
    );
    _emit();
    _pump();
    return job.completer.future;
  }

  bool acknowledge(
    CaptureAcknowledgement acknowledgement,
    CaptureQualityResult quality,
  ) {
    final job = _active;
    if (job == null || job.state != CaptureTaskState.waitingAck) return false;
    final intent = job.intent;
    if (acknowledgement.taskId == null ||
        acknowledgement.taskId != intent.taskId ||
        acknowledgement.captureType != intent.captureType ||
        acknowledgement.scene != intent.scene ||
        acknowledgement.mealSessionId != intent.mealSessionId) {
      return false;
    }

    _acknowledgementTimer?.cancel();
    job.state = CaptureTaskState.qualityChecking;
    _emit();
    if (quality.accepted) {
      _setCooldown(intent);
      _finishActive(CaptureTaskState.accepted);
      return true;
    }
    if (job.retakeCount < intent.retryPolicy.maxRetakes &&
        intent.qualityPolicy.allowsRetake) {
      final retryTaskId = _taskIdGenerator();
      if (!_reserveTaskId(retryTaskId)) {
        _finishActive(
          CaptureTaskState.failed,
          message: 'retry capture task ID collision',
        );
        return true;
      }
      job.retakeCount += 1;
      _rememberCompletedTaskId(intent.taskId);
      job.intent = intent.copyWith(
        taskId: retryTaskId,
        source: CaptureIntentSource.retake,
        delay: Duration.zero,
      );
      job.state = CaptureTaskState.retrying;
      _emit();
      _scheduleActive(job);
      return true;
    }
    _finishActive(
      intent.isAutomaticOrigin
          ? CaptureTaskState.dropped
          : CaptureTaskState.failed,
      message: quality.issues.map((issue) => issue.name).join(', '),
    );
    return true;
  }

  void cancelTask(String taskId) {
    if (_active?.intent.taskId == taskId) {
      _cancelActive();
      return;
    }
    final index = _queue.indexWhere((job) => job.intent.taskId == taskId);
    if (index < 0) return;
    final job = _queue.removeAt(index);
    _complete(job, CaptureTaskState.cancelled);
    _emit();
  }

  void cancelWhere(bool Function(CaptureIntent intent) predicate) {
    final queued = _queue.where((job) => predicate(job.intent)).toList();
    for (final job in queued) {
      _queue.remove(job);
      _complete(job, CaptureTaskState.cancelled);
    }
    if (_active != null && predicate(_active!.intent)) {
      _cancelActive(pump: false);
    }
    _emit();
    _pump();
  }

  /// Stops only delayed/queued work. A command already sent to the glasses is
  /// allowed to complete so a real camera capture does not become orphaned.
  void cancelPendingWhere(bool Function(CaptureIntent intent) predicate) {
    final queued = _queue.where((job) => predicate(job.intent)).toList();
    for (final job in queued) {
      _queue.remove(job);
      _complete(job, CaptureTaskState.cancelled);
    }
    if (_active != null &&
        _active!.state == CaptureTaskState.waitingDelay &&
        predicate(_active!.intent)) {
      _cancelActive(pump: false);
    }
    _emit();
    _pump();
  }

  void dispose() {
    _disposed = true;
    _delayTimer?.cancel();
    _acknowledgementTimer?.cancel();
    if (_active != null) _complete(_active!, CaptureTaskState.cancelled);
    for (final job in _queue) {
      _complete(job, CaptureTaskState.cancelled);
    }
    _queue.clear();
    _active = null;
  }

  void _preemptDelayedAutomaticFor(CaptureIntent next) {
    final active = _active;
    if (active == null || active.state != CaptureTaskState.waitingDelay) return;
    if (!active.intent.isAutomaticOrigin ||
        next.priority.rank >= active.intent.priority.rank) {
      return;
    }
    _cancelActive(pump: false);
  }

  void _pump() {
    if (_disposed || _active != null || _queue.isEmpty) return;
    final job = _queue.removeAt(0);
    if (_isCooldownBlocked(job.intent)) {
      _complete(job, CaptureTaskState.dropped, message: 'cooldown active');
      _emit();
      _pump();
      return;
    }
    _active = job;
    _scheduleActive(job);
  }

  void _scheduleActive(_CaptureJob job) {
    if (_active != job || _disposed) return;
    _delayTimer?.cancel();
    job.state = CaptureTaskState.waitingDelay;
    _emit();
    _delayTimer = Timer(job.intent.delay, () {
      if (_active != job || _disposed) return;
      unawaited(_dispatchActive(job));
    });
  }

  Future<void> _dispatchActive(_CaptureJob job) async {
    if (_active != job || _disposed) return;
    if (!_isDispatchAllowed(job.intent)) {
      _finishActive(
        CaptureTaskState.dropped,
        message: 'capture dispatch is not currently allowed',
      );
      return;
    }
    job.state = CaptureTaskState.dispatching;
    _emit();
    bool sent;
    try {
      sent = await _dispatch(job.intent);
    } catch (_) {
      sent = false;
    }
    if (_active != job || _disposed) return;
    if (!sent) {
      _finishActive(
        CaptureTaskState.failed,
        message: 'capture command send failed',
      );
      return;
    }
    job.state = CaptureTaskState.waitingAck;
    _acknowledgementTimer?.cancel();
    _acknowledgementTimer = Timer(config.acknowledgementTimeout, () {
      if (_active == job && job.state == CaptureTaskState.waitingAck) {
        _finishActive(
          CaptureTaskState.failed,
          message: 'capture acknowledgement timeout',
        );
      }
    });
    _emit();
  }

  void _cancelActive({bool pump = true}) {
    final active = _active;
    if (active == null) return;
    _delayTimer?.cancel();
    _acknowledgementTimer?.cancel();
    _active = null;
    _complete(active, CaptureTaskState.cancelled);
    _emit();
    if (pump) _pump();
  }

  void _finishActive(CaptureTaskState state, {String? message}) {
    final active = _active;
    if (active == null) return;
    _delayTimer?.cancel();
    _acknowledgementTimer?.cancel();
    _active = null;
    _complete(active, state, message: message);
    _emit();
    _pump();
  }

  void _complete(_CaptureJob job, CaptureTaskState state, {String? message}) {
    job.state = state;
    _rememberCompletedTaskId(job.intent.taskId);
    if (!job.completer.isCompleted) {
      job.completer.complete(
        CaptureTaskResult(
          taskId: job.intent.taskId,
          state: state,
          message: message,
        ),
      );
    }
  }

  bool _reserveTaskId(String taskId) {
    if (_inFlightTaskIds.contains(taskId) ||
        _completedTaskIds.contains(taskId)) {
      return false;
    }
    _inFlightTaskIds.add(taskId);
    return true;
  }

  void _rememberCompletedTaskId(String taskId) {
    _inFlightTaskIds.remove(taskId);
    if (!_completedTaskIds.add(taskId)) return;
    _completedTaskIdOrder.addLast(taskId);
    while (_completedTaskIdOrder.length > config.completedTaskHistoryLimit) {
      _completedTaskIds.remove(_completedTaskIdOrder.removeFirst());
    }
  }

  bool _isCooldownBlocked(CaptureIntent intent) {
    if (!intent.isAutomaticOrigin ||
        intent.cooldownGroup == CaptureCooldownGroup.none) {
      return false;
    }
    final until = _cooldownUntil[intent.cooldownGroup];
    return until != null && _now().isBefore(until);
  }

  void _setCooldown(CaptureIntent intent) {
    final duration = switch (intent.cooldownGroup) {
      CaptureCooldownGroup.automaticFood => config.automaticCooldown,
      CaptureCooldownGroup.packaging => config.packagingCooldown,
      CaptureCooldownGroup.none ||
      CaptureCooldownGroup.manualFood => Duration.zero,
    };
    if (duration > Duration.zero) {
      _cooldownUntil[intent.cooldownGroup] = _now().add(duration);
    }
  }

  void _emit() => _onChanged?.call(snapshot);

  static String _defaultTaskId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'capture_${now}_${now % 997}';
  }

  static bool _allowDispatch(CaptureIntent _) => true;
}

class _CaptureJob {
  _CaptureJob(this.intent);

  CaptureIntent intent;
  CaptureTaskState state = CaptureTaskState.queued;
  int retakeCount = 0;
  final Completer<CaptureTaskResult> completer = Completer<CaptureTaskResult>();
}
