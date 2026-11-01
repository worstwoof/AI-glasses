import 'package:flutter_test/flutter_test.dart';
import '../lib/services/lan_ice_policy.dart';

void main() {
  const hotspot = 'candidate:1 1 udp 100 192.168.43.1 40000 typ host';
  const cellular = 'candidate:2 1 udp 100 10.112.52.240 40001 typ host';
  const loopback = 'candidate:3 1 udp 100 127.0.0.1 40002 typ host';
  const related =
      'candidate:4 1 udp 90 10.0.0.2 40003 typ srflx raddr 192.168.43.1 rport 40000';
  test('hotspot wins over cellular, loopback and related-address matches', () {
    expect(
      LanIcePolicy.select([
        cellular,
        loopback,
        related,
        hotspot,
      ], '192.168.43.'),
      [hotspot],
    );
  });
  test('missing subnet does not fabricate a hotspot candidate', () {
    expect(LanIcePolicy.select([cellular, loopback], '192.168.43.'), [
      cellular,
    ]);
  });
  test(
    'SDP and candidate list apply the same policy, preserving media lines',
    () {
      final sdp =
          'v=0\r\nm=video 9 UDP/TLS/RTP/SAVPF 96\r\na=mid:0\r\na=$cellular\r\na=$hotspot\r\na=end-of-candidates\r\n';
      final filtered = LanIcePolicy.filterSdp(sdp, '192.168.43.');
      expect(filtered, contains('a=$hotspot'));
      expect(filtered, isNot(contains(cellular)));
      expect(filtered, contains('a=mid:0'));
      expect(filtered, endsWith('a=end-of-candidates\r\n'));
    },
  );
  test('malformed and IPv6 loopback candidates are rejected', () {
    expect(
      LanIcePolicy.select([
        'invalid',
        'candidate:5 1 udp 100 ::1 40004 typ host',
      ], null),
      isEmpty,
    );
  });
}
