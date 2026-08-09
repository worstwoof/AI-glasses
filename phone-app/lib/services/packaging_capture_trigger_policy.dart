/// Owns automatic packaging-capture eligibility without depending on WebRTC.
/// A failed send releases the attempt without consuming the cooldown.
class PackagingCaptureTriggerState {
  PackagingCaptureTriggerState({this.cooldown = const Duration(seconds: 8)});

  final Duration cooldown;
  DateTime? _lastSuccessfulSendAt;
  bool _inFlight = false;
  bool _analysisActive = false;

  bool get analysisActive => _analysisActive;

  set analysisActive(bool value) {
    _analysisActive = value;
  }

  bool tryStart(DateTime now) {
    if (_analysisActive || _inFlight) return false;
    final last = _lastSuccessfulSendAt;
    if (last != null && now.difference(last) < cooldown) return false;
    _inFlight = true;
    return true;
  }

  void complete({required bool sent, required DateTime now}) {
    if (sent) _lastSuccessfulSendAt = now;
    _inFlight = false;
  }
}
