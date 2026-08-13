import 'dart:collection';

enum CaptureUploadDisposition {
  firstDelivery,
  inFlightDuplicate,
  completedDuplicate,
}

/// Bounds duplicate upload history without preventing an upload retry after
/// the first delivery fails before acknowledgement.
class CaptureUploadDeduplicator {
  CaptureUploadDeduplicator({this.completedHistoryLimit = 512});

  final int completedHistoryLimit;
  final Set<String> _inFlight = <String>{};
  final Set<String> _completed = <String>{};
  final Queue<String> _completedOrder = Queue<String>();

  CaptureUploadDisposition begin(String? taskId) {
    final normalized = taskId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return CaptureUploadDisposition.firstDelivery;
    }
    if (_completed.contains(normalized)) {
      return CaptureUploadDisposition.completedDuplicate;
    }
    if (!_inFlight.add(normalized)) {
      return CaptureUploadDisposition.inFlightDuplicate;
    }
    return CaptureUploadDisposition.firstDelivery;
  }

  void complete(String? taskId) {
    final normalized = taskId?.trim();
    if (normalized == null || normalized.isEmpty) return;
    _inFlight.remove(normalized);
    if (!_completed.add(normalized)) return;
    _completedOrder.addLast(normalized);
    while (_completedOrder.length > completedHistoryLimit) {
      _completed.remove(_completedOrder.removeFirst());
    }
  }

  void fail(String? taskId) {
    final normalized = taskId?.trim();
    if (normalized == null || normalized.isEmpty) return;
    _inFlight.remove(normalized);
  }
}
