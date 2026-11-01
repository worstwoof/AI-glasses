/// Candidate selection for RV101's local-network-only video connection.
/// Match the candidate's actual address, never its related-address extension.
class LanIcePolicy {
  static String? address(String candidate) {
    final fields = candidate.trim().split(RegExp(r'\s+'));
    if (fields.length < 8 ||
        !fields.first.replaceFirst('a=', '').startsWith('candidate:') ||
        fields[6] != 'typ')
      return null;
    return fields[4];
  }

  static bool matches(String candidate, String prefix) =>
      address(candidate)?.startsWith(prefix) ?? false;

  static List<String> select(List<String> candidates, String? prefix) {
    final usable = candidates
        .where((candidate) {
          final ip = address(candidate);
          return ip != null &&
              ip != '::1' &&
              ip != '0.0.0.0' &&
              !ip.startsWith('127.');
        })
        .toList(growable: false);
    if (prefix == null) return usable;
    final local = usable
        .where((c) => matches(c, prefix))
        .toList(growable: false);
    // Preserve other valid paths when no subnet match exists. Filtering cannot
    // manufacture a missing interface; the Android detector must expose it.
    return local.isNotEmpty ? local : usable;
  }

  static String filterSdp(String sdp, String? prefix) {
    final lines = sdp.split(RegExp(r'\r?\n'));
    final candidates = lines
        .where((l) => l.startsWith('a=candidate:'))
        .toList();
    final selected = select(candidates, prefix).toSet();
    return lines
        .where((l) => !l.startsWith('a=candidate:') || selected.contains(l))
        .join('\r\n');
  }
}
