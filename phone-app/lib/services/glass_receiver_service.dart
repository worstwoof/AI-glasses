import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'phone_scene_classifier.dart';

class GlassCapture {
  const GlassCapture({
    required this.imageFile,
    required this.metadata,
    required this.receivedAt,
  });

  final File imageFile;
  final Map<String, dynamic> metadata;
  final DateTime receivedAt;

  String get trigger => metadata['trigger']?.toString() ?? 'unknown';

  String get scene => metadata['scene']?.toString() ?? 'unknown';
}

class GlassReceiverSnapshot {
  const GlassReceiverSnapshot({
    required this.running,
    required this.port,
    required this.localIps,
    required this.token,
    required this.serverMessage,
    required this.peerState,
    required this.iceState,
    required this.controlReady,
    required this.remoteVideoReady,
    required this.statsText,
    required this.connectingGlasses,
    required this.glassesMessage,
    required this.glassesIp,
    required this.sceneClassification,
    required this.sceneFrameCount,
    required this.lastCapture,
    required this.error,
  });

  final bool running;
  final int? port;
  final List<String> localIps;
  final String token;
  final String serverMessage;
  final String peerState;
  final String iceState;
  final bool controlReady;
  final bool remoteVideoReady;
  final String statsText;
  final bool connectingGlasses;
  final String glassesMessage;
  final String? glassesIp;
  final PhoneSceneClassification sceneClassification;
  final int sceneFrameCount;
  final GlassCapture? lastCapture;
  final String? error;

  String get primaryIp {
    if (localIps.isEmpty) return '0.0.0.0';
    return localIps.firstWhere(
      (ip) => !ip.startsWith('169.254.'),
      orElse: () => localIps.first,
    );
  }

  String get uploadEndpoint {
    final currentPort = port ?? GlassReceiverService.defaultPort;
    return 'http://$primaryIp:$currentPort/api/v1/captures';
  }

  String get signalingEndpoint {
    final currentPort = port ?? GlassReceiverService.defaultPort;
    return 'http://$primaryIp:$currentPort/api/v1/webrtc/offer';
  }
}

class _WebRtcAnswer {
  const _WebRtcAnswer(this.description, this.candidates);

  final RTCSessionDescription description;
  final List<RTCIceCandidate> candidates;
}

class GlassReceiverService extends ChangeNotifier {
  GlassReceiverService._();

  static final GlassReceiverService instance = GlassReceiverService._();
  static const int defaultPort = 8080;
  static const String defaultPairingToken = 'CsF8V6pEOWqlfcktClawh60N';

  static const _tokenKey = 'rv101_receiver_pairing_token';
  static const _lastGlassesIpKey = 'rv101_last_glasses_ip';
  static const _capturePath = '/api/v1/captures';
  static const _offerPath = '/api/v1/webrtc/offer';
  static const _sceneFramePath = '/api/v1/scene/frames';
  static const _glassesStartPath = '/api/v1/glasses/start';
  static const _glassesControlPort = 8088;
  static const _maxImageBytes = 20 * 1024 * 1024;
  static const _maxSceneFrameBytes = 2 * 1024 * 1024;
  static const _probeTimeout = Duration(milliseconds: 650);
  static const _discoveryInterval = Duration(seconds: 12);

  final _captureController = StreamController<GlassCapture>.broadcast();
  final _remoteStreamController = StreamController<MediaStream?>.broadcast();

  HttpServer? _server;
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _controlChannel;
  MediaStream? _fallbackRemoteStream;
  Timer? _statsTimer;
  Timer? _glassesDiscoveryTimer;
  Completer<void>? _iceGatheringCompleter;
  bool _starting = false;
  bool _handlingOffer = false;
  bool _classifyingSceneFrame = false;
  bool _connectingGlasses = false;
  int? _lastBytesReceived;
  DateTime? _lastStatsAt;

  bool _running = false;
  int? _port;
  List<String> _localIps = const [];
  String _token = '';
  String _serverMessage = '接收服务未启动';
  String _peerState = '等待眼镜连接';
  String _iceState = '未开始';
  bool _controlReady = false;
  bool _remoteVideoReady = false;
  String _statsText = '等待视频统计';
  String _glassesMessage = '打开本页后会自动搜索并连接 RV101 眼镜';
  String? _glassesIp;
  PhoneSceneClassification _sceneClassification =
      PhoneSceneClassification.waiting;
  PhoneSceneMode _sceneCandidateMode = PhoneSceneMode.waiting;
  int _sceneCandidateHits = 0;
  int _sceneFrameCount = 0;
  GlassCapture? _lastCapture;
  String? _error;

  Stream<GlassCapture> get captures => _captureController.stream;

  Stream<MediaStream?> get remoteStreams => _remoteStreamController.stream;

  GlassReceiverSnapshot get snapshot => GlassReceiverSnapshot(
    running: _running,
    port: _port,
    localIps: _localIps,
    token: _token,
    serverMessage: _serverMessage,
    peerState: _peerState,
    iceState: _iceState,
    controlReady: _controlReady,
    remoteVideoReady: _remoteVideoReady,
    statsText: _statsText,
    connectingGlasses: _connectingGlasses,
    glassesMessage: _glassesMessage,
    glassesIp: _glassesIp,
    sceneClassification: _sceneClassification,
    sceneFrameCount: _sceneFrameCount,
    lastCapture: _lastCapture,
    error: _error,
  );

  Future<void> start() async {
    if (_starting) return;
    _starting = true;
    try {
      _token = await _loadOrCreateToken();
      _localIps = await _loadLocalIps();
      if (_server == null) {
        _server = await _bindServer();
        _port = _server!.port;
        _server!.listen((request) {
          unawaited(_handleRequest(request));
        });
      }
      _running = true;
      _serverMessage = '正在监听 ${_port ?? defaultPort} 端口';
      _error = null;
      _ensureGlassesDiscoveryLoop();
    } catch (error) {
      _running = false;
      _serverMessage = '接收服务启动失败';
      _error = error.toString();
    } finally {
      _starting = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _stopGlassesDiscoveryLoop();
    await _closePeerConnection();
    await _server?.close(force: true);
    _server = null;
    _running = false;
    _port = null;
    _serverMessage = '接收服务已停止';
    notifyListeners();
  }

  Future<void> restart() async {
    await stop();
    await start();
  }

  Future<void> refreshNetworkAddresses() async {
    _localIps = await _loadLocalIps();
    notifyListeners();
  }

  Future<void> connectToGlasses({bool force = false}) async {
    if (_connectingGlasses) return;
    if (!_running) {
      _glassesMessage = '手机接收服务尚未启动，请先进入实时预览页。';
      notifyListeners();
      return;
    }
    if (_remoteVideoReady && !force) return;

    _connectingGlasses = true;
    _glassesMessage = '正在同一 Wi-Fi/热点内搜索 RV101 眼镜...';
    _error = null;
    notifyListeners();

    try {
      _token = _token.isEmpty ? await _loadOrCreateToken() : _token;
      _localIps = await _loadLocalIps();
      final candidates = await _buildGlassesCandidateIps();
      if (candidates.isEmpty) {
        _glassesMessage = '未读取到手机局域网 IPv4，请先打开热点或连接 Wi-Fi。';
        return;
      }
      final foundIp = await _startFirstReachableGlasses(candidates, _token);
      if (foundIp == null) {
        _glassesMessage = '还没找到 RV101。确认眼镜已开机，并已连入这个手机热点/Wi-Fi。';
        return;
      }
      _glassesIp = foundIp;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastGlassesIpKey, foundIp);
      _glassesMessage = '已连接眼镜 $foundIp，正在等待实时视频接入。';
    } catch (error) {
      _glassesMessage = '连接眼镜失败：$error';
      _error = error.toString();
    } finally {
      _connectingGlasses = false;
      notifyListeners();
    }
  }

  Future<void> resetToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = defaultPairingToken;
    await prefs.setString(_tokenKey, _token);
    notifyListeners();
  }

  Future<bool> sendCaptureCommand() async {
    final channel = _controlChannel;
    if (channel == null ||
        channel.state != RTCDataChannelState.RTCDataChannelOpen) {
      _error = '控制通道尚未建立，等实时画面连上后再试。';
      notifyListeners();
      return false;
    }

    final payload = jsonEncode({
      'type': 'capture',
      'trigger': 'app_button',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await channel.send(RTCDataChannelMessage(payload));
    _serverMessage = '已向眼镜发送抓拍指令';
    _error = null;
    notifyListeners();
    return true;
  }

  Future<String> _loadOrCreateToken() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_tokenKey)?.trim();
    if (existing == defaultPairingToken) {
      return defaultPairingToken;
    }
    await prefs.setString(_tokenKey, defaultPairingToken);
    return defaultPairingToken;
  }

  Future<List<String>> _loadLocalIps() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    final addresses = <String>[];
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback && !addresses.contains(address.address)) {
          addresses.add(address.address);
        }
      }
    }
    addresses.sort((a, b) {
      final aRank = _networkAddressRank(a);
      final bRank = _networkAddressRank(b);
      if (aRank != bRank) return aRank.compareTo(bRank);
      final aLinkLocal = a.startsWith('169.254.');
      final bLinkLocal = b.startsWith('169.254.');
      if (aLinkLocal == bLinkLocal) return a.compareTo(b);
      return aLinkLocal ? 1 : -1;
    });
    return addresses;
  }

  void _ensureGlassesDiscoveryLoop() {
    if (_glassesDiscoveryTimer != null) return;
    unawaited(connectToGlasses());
    _glassesDiscoveryTimer = Timer.periodic(_discoveryInterval, (_) {
      if (!_running || _remoteVideoReady) {
        _stopGlassesDiscoveryLoop();
        return;
      }
      unawaited(connectToGlasses());
    });
  }

  void _stopGlassesDiscoveryLoop() {
    _glassesDiscoveryTimer?.cancel();
    _glassesDiscoveryTimer = null;
  }

  Future<List<String>> _buildGlassesCandidateIps() async {
    final prefs = await SharedPreferences.getInstance();
    final ordered = <String>[];
    void addCandidate(String ip) {
      if (_isProbeCandidate(ip) && !ordered.contains(ip)) {
        ordered.add(ip);
      }
    }

    final lastIp = prefs.getString(_lastGlassesIpKey)?.trim();
    if (lastIp != null && lastIp.isNotEmpty) addCandidate(lastIp);

    for (final phoneIp in _localIps) {
      final prefix = _ipv4Prefix(phoneIp);
      if (prefix == null) continue;
      addCandidate('${prefix}219');
      for (var host = 2; host <= 254; host += 1) {
        final ip = '$prefix$host';
        if (ip != phoneIp) addCandidate(ip);
      }
    }
    return ordered;
  }

  bool _isProbeCandidate(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    final values = parts.map(int.tryParse).toList(growable: false);
    if (values.any((value) => value == null || value < 0 || value > 255)) {
      return false;
    }
    final last = values.last!;
    return last > 0 && last < 255;
  }

  Future<String?> _startFirstReachableGlasses(
    List<String> candidates,
    String token,
  ) async {
    const batchSize = 28;
    for (var offset = 0; offset < candidates.length; offset += batchSize) {
      if (!_running || _remoteVideoReady) return null;
      final batch = candidates.skip(offset).take(batchSize).toList();
      final results = await Future.wait(
        batch.map((ip) async => await _tryStartGlasses(ip, token) ? ip : null),
      );
      for (final result in results) {
        if (result != null) return result;
      }
    }
    return null;
  }

  Future<bool> _tryStartGlasses(String ip, String token) async {
    final client = HttpClient()..connectionTimeout = _probeTimeout;
    try {
      final uri = Uri.parse(
        'http://$ip:$_glassesControlPort$_glassesStartPath',
      );
      final request = await client.postUrl(uri).timeout(_probeTimeout);
      request.headers.set('X-Device-Token', token);
      request.headers.contentType = ContentType.json;
      request.add(
        utf8.encode(
          jsonEncode({
            'uploadEndpoint': snapshot.uploadEndpoint,
            'token': token,
          }),
        ),
      );
      final response = await request.close().timeout(_probeTimeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_probeTimeout, onTimeout: () => '');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      if (body.isEmpty) return true;
      final json = jsonDecode(body);
      return json is Map && json['device'] == 'rv101-camera-probe';
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  int _networkAddressRank(String ip) {
    if (ip == '192.168.43.1') return 0;
    if (ip.startsWith('192.168.')) return 1;
    if (ip.startsWith('172.')) return 2;
    if (ip.startsWith('10.')) return 3;
    if (ip.startsWith('169.254.')) return 9;
    return 4;
  }

  Future<HttpServer> _bindServer() async {
    Object? lastError;
    for (final port in const [8080, 8081, 8082]) {
      try {
        return await HttpServer.bind(
          InternetAddress.anyIPv4,
          port,
          shared: false,
        );
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError('8080-8082 端口均不可用：$lastError');
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (request.method != 'POST') {
        await _json(request, HttpStatus.notFound, {
          'accepted': false,
          'code': 'not_found',
          'message': '接口不存在',
        });
        return;
      }
      if (request.headers.value('x-device-token') != _token) {
        await _json(request, HttpStatus.unauthorized, {
          'accepted': false,
          'code': 'unauthorized',
          'message': '配对令牌无效',
        });
        return;
      }

      switch (request.uri.path) {
        case _capturePath:
          await _handleCaptureUpload(request);
          return;
        case _offerPath:
          await _handleWebRtcOffer(request);
          return;
        case _sceneFramePath:
          await _handleSceneFrame(request);
          return;
        default:
          await _json(request, HttpStatus.notFound, {
            'accepted': false,
            'code': 'not_found',
            'message': '接口不存在',
          });
      }
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      try {
        await _json(request, HttpStatus.internalServerError, {
          'accepted': false,
          'code': 'server_error',
          'message': '服务器处理失败',
        });
      } catch (_) {}
    }
  }

  Future<void> _handleCaptureUpload(HttpRequest request) async {
    final contentType = request.headers.contentType;
    if (contentType == null ||
        !contentType.mimeType.toLowerCase().contains('multipart/form-data')) {
      await _json(request, HttpStatus.badRequest, {
        'accepted': false,
        'code': 'invalid_request',
        'message': '请求必须为 multipart/form-data',
      });
      return;
    }
    final boundary = contentType.parameters['boundary'];
    if (boundary == null || boundary.isEmpty) {
      await _json(request, HttpStatus.badRequest, {
        'accepted': false,
        'code': 'invalid_request',
        'message': 'multipart boundary 缺失',
      });
      return;
    }

    final body = await _readBody(request, limit: _maxImageBytes + 1024 * 1024);
    final parts = _parseMultipart(body, boundary);
    final imageBytes = parts['image'];
    final metadataBytes = parts['metadata'];
    if (imageBytes == null || imageBytes.isEmpty) {
      await _json(request, HttpStatus.badRequest, {
        'accepted': false,
        'code': 'invalid_request',
        'message': '缺少 image 文件',
      });
      return;
    }
    if (imageBytes.length > _maxImageBytes) {
      await _json(request, HttpStatus.requestEntityTooLarge, {
        'accepted': false,
        'code': 'image_too_large',
        'message': '图片不能超过 20 MB',
      });
      return;
    }
    if (!_isJpeg(imageBytes)) {
      await _json(request, HttpStatus.badRequest, {
        'accepted': false,
        'code': 'invalid_request',
        'message': '仅支持 JPEG 图片',
      });
      return;
    }

    final metadata = metadataBytes == null
        ? <String, dynamic>{}
        : (jsonDecode(utf8.decode(metadataBytes)) as Map<String, dynamic>);
    final directory = await getApplicationDocumentsDirectory();
    final captureDir = Directory(
      '${directory.path}${Platform.pathSeparator}captures',
    );
    await captureDir.create(recursive: true);
    final id = 'capture_${DateTime.now().millisecondsSinceEpoch}';
    final imageFile = File(
      '${captureDir.path}${Platform.pathSeparator}$id.jpg',
    );
    await imageFile.writeAsBytes(imageBytes, flush: true);

    final capture = GlassCapture(
      imageFile: imageFile,
      metadata: metadata,
      receivedAt: DateTime.now(),
    );
    _lastCapture = capture;
    _serverMessage = '已收到眼镜抓拍图片';
    _error = null;
    _captureController.add(capture);
    notifyListeners();

    await _json(request, HttpStatus.created, {
      'accepted': true,
      'captureId': id,
      'status': 'received',
    });
  }

  Future<void> _handleWebRtcOffer(HttpRequest request) async {
    if (_handlingOffer) {
      await _json(request, HttpStatus.conflict, {
        'accepted': false,
        'code': 'offer_in_progress',
        'message': '上一次 WebRTC 建链仍在处理中',
      });
      return;
    }
    _handlingOffer = true;
    try {
      final body = await _readBody(request, limit: 1024 * 1024);
      final offerJson = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
      final sdp = offerJson['sdp']?.toString();
      final type = offerJson['type']?.toString() ?? 'offer';
      if (sdp == null || sdp.isEmpty) {
        await _json(request, HttpStatus.badRequest, {
          'accepted': false,
          'code': 'invalid_offer',
          'message': 'offer SDP 缺失',
        });
        return;
      }

      final answer = await _acceptOffer(
        RTCSessionDescription(sdp, type),
        _parseIceCandidates(offerJson['candidates']),
        remoteIp: request.connectionInfo?.remoteAddress.address,
      );
      await _json(request, HttpStatus.ok, {
        'accepted': true,
        'type': answer.description.type,
        'sdp': answer.description.sdp,
        'candidates': _encodeIceCandidates(answer.candidates),
      });
    } finally {
      _handlingOffer = false;
    }
  }

  Future<void> _handleSceneFrame(HttpRequest request) async {
    if (_classifyingSceneFrame) {
      await _json(request, HttpStatus.accepted, {
        'accepted': true,
        'status': 'classifier_busy',
      });
      return;
    }
    final contentType = request.headers.contentType;
    if (contentType == null ||
        !contentType.mimeType.toLowerCase().contains('multipart/form-data')) {
      await _json(request, HttpStatus.badRequest, {
        'accepted': false,
        'code': 'invalid_request',
        'message': '场景帧必须为 multipart/form-data',
      });
      return;
    }
    final boundary = contentType.parameters['boundary'];
    if (boundary == null || boundary.isEmpty) {
      await _json(request, HttpStatus.badRequest, {
        'accepted': false,
        'code': 'invalid_request',
        'message': '场景帧 multipart boundary 缺失',
      });
      return;
    }

    _classifyingSceneFrame = true;
    try {
      final body = await _readBody(
        request,
        limit: _maxSceneFrameBytes + 256 * 1024,
      );
      final imageBytes = _parseMultipart(body, boundary)['image'];
      if (imageBytes == null || imageBytes.isEmpty) {
        await _json(request, HttpStatus.badRequest, {
          'accepted': false,
          'code': 'invalid_request',
          'message': '缺少场景分类 image',
        });
        return;
      }
      if (imageBytes.length > _maxSceneFrameBytes || !_isJpeg(imageBytes)) {
        await _json(request, HttpStatus.badRequest, {
          'accepted': false,
          'code': 'invalid_scene_frame',
          'message': '场景帧必须是 2 MB 以内的 JPEG',
        });
        return;
      }

      final raw = await PhoneSceneClassifier.classifyJpeg(imageBytes);
      _sceneFrameCount += 1;
      _applySceneClassification(raw);
      notifyListeners();
      await _json(request, HttpStatus.ok, {
        'accepted': true,
        'status': 'classified',
        'scene': raw.mode.name,
        'gesture': raw.gesture,
        'confidence': raw.confidence,
        'stableScene': _sceneClassification.mode.name,
        'candidateHits': _sceneCandidateHits,
      });
    } finally {
      _classifyingSceneFrame = false;
    }
  }

  void _applySceneClassification(PhoneSceneClassification raw) {
    final isActionable =
        raw.mode == PhoneSceneMode.ingredientLabel ||
        raw.mode == PhoneSceneMode.eating;
    if (!isActionable) {
      _sceneCandidateMode = PhoneSceneMode.unknown;
      _sceneCandidateHits = 0;
      if (_sceneClassification.mode == PhoneSceneMode.waiting ||
          _sceneClassification.mode == PhoneSceneMode.unknown ||
          _sceneClassification.mode == PhoneSceneMode.error) {
        _sceneClassification = raw;
      }
      return;
    }

    if (_sceneCandidateMode == raw.mode) {
      _sceneCandidateHits += 1;
    } else {
      _sceneCandidateMode = raw.mode;
      _sceneCandidateHits = 1;
    }
    if (_sceneCandidateHits >= 2) {
      _sceneClassification = raw;
      _serverMessage = raw.message;
      _sceneCandidateHits = 0;
      _sceneCandidateMode = PhoneSceneMode.waiting;
    }
  }

  Future<_WebRtcAnswer> _acceptOffer(
    RTCSessionDescription offer,
    List<RTCIceCandidate> remoteCandidates, {
    String? remoteIp,
  }) async {
    await _closePeerConnection();
    final hotspotPrefix = _ipv4Prefix(remoteIp);
    _log(
      'offer from $remoteIp prefix=$hotspotPrefix '
      'remoteCandidates=${remoteCandidates.length} '
      'offerSdpCandidates=${_countSdpCandidateLines(offer.sdp)}',
    );
    _peerState = '正在响应眼镜 offer';
    _iceState = '正在收集局域网候选地址';
    _remoteVideoReady = false;
    _controlReady = false;
    _statsText = '等待首帧';
    notifyListeners();

    final peer = await createPeerConnection(
      {'iceServers': <Map<String, dynamic>>[], 'sdpSemantics': 'unified-plan'},
      {'mandatory': <String, dynamic>{}, 'optional': <dynamic>[]},
    );
    _peerConnection = peer;
    final localCandidates = <RTCIceCandidate>[];

    peer.onConnectionState = (state) {
      _log('connectionState=$state');
      _peerState = _describePeerState(state);
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _markPreviewDisconnected(
          '实时预览连接中断，正在重新连接眼镜。',
          clearStream:
              state == RTCPeerConnectionState.RTCPeerConnectionStateFailed,
        );
        _ensureGlassesDiscoveryLoop();
      }
      notifyListeners();
    };
    peer.onIceConnectionState = (state) {
      _log('iceConnectionState=$state');
      _iceState = _describeIceState(state);
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        _markPreviewDisconnected(
          '局域网路径中断，正在重新连接眼镜。',
          clearStream:
              state == RTCIceConnectionState.RTCIceConnectionStateFailed,
        );
      }
      notifyListeners();
    };
    peer.onIceGatheringState = (state) {
      _log(
        'iceGatheringState=$state localCandidates=${localCandidates.length}',
      );
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        final completer = _iceGatheringCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.complete();
        }
      }
      _iceState = _describeGatheringState(state);
      notifyListeners();
    };
    peer.onIceCandidate = (candidate) {
      localCandidates.add(candidate);
      _log('localCandidate ${_describeCandidate(candidate)}');
    };
    peer.onTrack = (event) {
      if (event.track.kind != 'video') return;
      _log(
        'remoteTrack kind=${event.track.kind} streams=${event.streams.length}',
      );
      unawaited(_attachRemoteVideo(event));
    };
    peer.onDataChannel = (channel) {
      _log('dataChannel label=${channel.label}');
      _controlChannel = channel;
      channel.onDataChannelState = (state) {
        _log('dataChannelState=$state');
        _controlReady = state == RTCDataChannelState.RTCDataChannelOpen;
        notifyListeners();
      };
      channel.onMessage = (message) {
        if (!message.isBinary) {
          _serverMessage = '眼镜控制通道：${message.text}';
          notifyListeners();
        }
      };
    };

    final acceptedRemoteCandidates = _filterCandidatesForPrefix(
      remoteCandidates,
      hotspotPrefix,
    );
    _log(
      'acceptedRemoteCandidates=${acceptedRemoteCandidates.length}/'
      '${remoteCandidates.length}',
    );
    await peer.setRemoteDescription(
      _filterDescriptionForPrefix(offer, hotspotPrefix),
    );
    for (final candidate in acceptedRemoteCandidates) {
      await peer.addCandidate(candidate);
      _log('remoteCandidate added ${_describeCandidate(candidate)}');
    }
    final answer = await peer.createAnswer({
      'offerToReceiveAudio': false,
      'offerToReceiveVideo': true,
    });
    _log('answerCreated sdpCandidates=${_countSdpCandidateLines(answer.sdp)}');
    await peer.setLocalDescription(answer);
    final descriptionAfterSetLocal = await peer.getLocalDescription();
    _log(
      'localDescriptionSet gathering=${peer.iceGatheringState} '
      'sdpCandidates=${_countSdpCandidateLines(descriptionAfterSetLocal?.sdp)}',
    );
    await _waitForIceGathering(peer);

    final localDescription = await peer.getLocalDescription();
    final filteredDescription = _filterDescriptionForPrefix(
      localDescription ?? answer,
      hotspotPrefix,
    );
    final filteredCandidates = _filterCandidatesForPrefix(
      localCandidates,
      hotspotPrefix,
    );
    _startStatsPolling();
    final remoteCandidateText =
        '${acceptedRemoteCandidates.length}/${remoteCandidates.length}';
    final localCandidateText =
        '${filteredCandidates.length}/${localCandidates.length}';
    final localSdpCandidateCount = _countSdpCandidateLines(
      filteredDescription.sdp,
    );
    _log(
      'answerReady localCandidates=$localCandidateText '
      'localSdpCandidates=$localSdpCandidateCount',
    );
    _serverMessage =
        'WebRTC answer 已返回，等待 ICE 连通；候选 远端 $remoteCandidateText / 本机 $localCandidateText / SDP $localSdpCandidateCount';
    _error = null;
    notifyListeners();
    return _WebRtcAnswer(filteredDescription, filteredCandidates);
  }

  Future<void> _attachRemoteVideo(RTCTrackEvent event) async {
    try {
      MediaStream stream;
      if (event.streams.isNotEmpty) {
        stream = event.streams.first;
        await _fallbackRemoteStream?.dispose();
        _fallbackRemoteStream = null;
      } else {
        final fallback = await createLocalMediaStream(
          'rv101-remote-${DateTime.now().millisecondsSinceEpoch}',
        );
        await fallback.addTrack(event.track, addToNative: false);
        await _fallbackRemoteStream?.dispose();
        _fallbackRemoteStream = fallback;
        stream = fallback;
      }
      _remoteVideoReady = true;
      _stopGlassesDiscoveryLoop();
      _remoteStreamController.add(stream);
      _serverMessage = '实时视频轨道已接入';
      _glassesMessage = _glassesIp == null
          ? '眼镜已接入实时视频。'
          : '眼镜 $_glassesIp 已接入实时视频。';
      notifyListeners();
    } catch (error) {
      _error = '远端视频轨道接入失败：$error';
      notifyListeners();
    }
  }

  void _markPreviewDisconnected(String message, {required bool clearStream}) {
    _remoteVideoReady = false;
    _controlReady = false;
    _serverMessage = message;
    _statsText = '等待视频统计';
    _statsTimer?.cancel();
    _statsTimer = null;
    if (clearStream) {
      _remoteStreamController.add(null);
    }
    _ensureGlassesDiscoveryLoop();
  }

  Future<void> _waitForIceGathering(RTCPeerConnection peer) async {
    if (peer.iceGatheringState ==
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return;
    }
    final completer = Completer<void>();
    _iceGatheringCompleter = completer;
    try {
      await completer.future.timeout(const Duration(seconds: 4));
    } on TimeoutException {
      _iceState = '候选地址收集超时，继续尝试连接';
      _log('iceGathering timed out state=${peer.iceGatheringState}');
    } finally {
      if (identical(_iceGatheringCompleter, completer)) {
        _iceGatheringCompleter = null;
      }
    }
  }

  List<RTCIceCandidate> _parseIceCandidates(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) {
          final candidate = item['candidate']?.toString();
          if (candidate == null || candidate.isEmpty) return null;
          final sdpMid = item['sdpMid']?.toString();
          if (sdpMid == null || sdpMid.isEmpty) return null;
          final mLineIndexValue = item['sdpMLineIndex'];
          final mLineIndex = mLineIndexValue is int
              ? mLineIndexValue
              : int.tryParse(mLineIndexValue?.toString() ?? '');
          if (mLineIndex == null || mLineIndex < 0) return null;
          return RTCIceCandidate(candidate, sdpMid, mLineIndex);
        })
        .whereType<RTCIceCandidate>()
        .toList(growable: false);
  }

  RTCSessionDescription _filterDescriptionForPrefix(
    RTCSessionDescription description,
    String? prefix,
  ) {
    final sdp = description.sdp;
    if (prefix == null || sdp == null || sdp.isEmpty) return description;
    final filtered = _filterSdpCandidateLines(sdp, prefix);
    return filtered == sdp
        ? description
        : RTCSessionDescription(filtered, description.type);
  }

  String _filterSdpCandidateLines(String sdp, String prefix) {
    final lines = sdp.split(RegExp(r'\r?\n'));
    final candidateLines = lines
        .where((line) => line.startsWith('a=candidate:'))
        .toList(growable: false);
    final matchingCandidateLines = candidateLines
        .where((line) => line.contains(' $prefix'))
        .toSet();
    if (candidateLines.isEmpty || matchingCandidateLines.isEmpty) {
      return sdp;
    }
    return lines
        .where(
          (line) =>
              !line.startsWith('a=candidate:') ||
              matchingCandidateLines.contains(line),
        )
        .join('\r\n');
  }

  List<RTCIceCandidate> _filterCandidatesForPrefix(
    List<RTCIceCandidate> candidates,
    String? prefix,
  ) {
    if (prefix == null) return candidates;
    final filtered = candidates
        .where(
          (candidate) => candidate.candidate?.contains(' $prefix') ?? false,
        )
        .toList(growable: false);
    return filtered.isEmpty ? candidates : filtered;
  }

  String? _ipv4Prefix(String? ip) {
    if (ip == null || ip.isEmpty) return null;
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) return null;
    }
    return '${parts[0]}.${parts[1]}.${parts[2]}.';
  }

  int _countSdpCandidateLines(String? sdp) {
    if (sdp == null || sdp.isEmpty) return 0;
    return sdp
        .split(RegExp(r'\r?\n'))
        .where((line) => line.startsWith('a=candidate:'))
        .length;
  }

  String _describeCandidate(RTCIceCandidate candidate) {
    final raw = candidate.candidate ?? '';
    final parts = raw.split(' ');
    final typeIndex = parts.indexOf('typ');
    final type = typeIndex >= 0 && typeIndex + 1 < parts.length
        ? parts[typeIndex + 1]
        : 'unknown';
    final ip = parts.length > 4 ? parts[4] : 'unknown';
    final port = parts.length > 5 ? parts[5] : 'unknown';
    return 'mid=${candidate.sdpMid} mline=${candidate.sdpMLineIndex} '
        'type=$type endpoint=$ip:$port';
  }

  List<Map<String, Object?>> _encodeIceCandidates(
    List<RTCIceCandidate> candidates,
  ) => candidates
      .where(
        (candidate) =>
            candidate.candidate != null &&
            candidate.candidate!.isNotEmpty &&
            candidate.sdpMid != null &&
            candidate.sdpMid!.isNotEmpty &&
            candidate.sdpMLineIndex != null &&
            candidate.sdpMLineIndex! >= 0,
      )
      .map(
        (candidate) => {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      )
      .toList(growable: false);

  void _startStatsPolling() {
    _statsTimer?.cancel();
    _lastBytesReceived = null;
    _lastStatsAt = null;
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_pollStats());
    });
  }

  Future<void> _pollStats() async {
    final peer = _peerConnection;
    if (peer == null) return;
    try {
      final reports = await peer.getStats();
      for (final report in reports) {
        final values = report.values;
        final type = report.type.toLowerCase();
        if (type != 'inbound-rtp' || !_isInboundVideoReport(values)) {
          continue;
        }

        final bytes = _asInt(values['bytesReceived']);
        final fps = _asDouble(values['framesPerSecond']);
        final framesDecoded = _asInt(values['framesDecoded']);
        final now = DateTime.now();
        double? kbps;
        if (bytes != null &&
            _lastBytesReceived != null &&
            _lastStatsAt != null) {
          final elapsedMs = now.difference(_lastStatsAt!).inMilliseconds;
          if (elapsedMs > 0) {
            kbps = (bytes - _lastBytesReceived!) * 8 / elapsedMs;
          }
        }
        if (bytes != null) {
          _lastBytesReceived = bytes;
          _lastStatsAt = now;
        }

        final fpsText = fps == null || fps <= 0 ? '--' : fps.toStringAsFixed(1);
        final bitrateText = kbps == null || kbps < 0
            ? '--'
            : kbps.toStringAsFixed(0);
        final frameText = framesDecoded == null ? '' : ' / $framesDecoded 帧';
        _statsText = '$fpsText FPS · $bitrateText kbps$frameText';
        notifyListeners();
        return;
      }
    } catch (_) {
      // Stats are best-effort and should not affect the preview connection.
    }
  }

  Future<void> _closePeerConnection() async {
    _statsTimer?.cancel();
    _statsTimer = null;
    final completer = _iceGatheringCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _iceGatheringCompleter = null;
    _controlReady = false;
    _remoteVideoReady = false;
    _remoteStreamController.add(null);
    await _fallbackRemoteStream?.dispose();
    _fallbackRemoteStream = null;
    await _controlChannel?.close();
    _controlChannel = null;
    await _peerConnection?.close();
    await _peerConnection?.dispose();
    _peerConnection = null;
    _peerState = '等待眼镜连接';
    _iceState = '未开始';
    _statsText = '等待视频统计';
  }

  Future<Uint8List> _readBody(HttpRequest request, {required int limit}) async {
    final builder = BytesBuilder(copy: false);
    var total = 0;
    await for (final chunk in request) {
      total += chunk.length;
      if (total > limit) {
        throw StateError('请求体过大');
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  Map<String, Uint8List> _parseMultipart(Uint8List body, String boundary) {
    final parts = <String, Uint8List>{};
    final delimiter = ascii.encode('--$boundary');
    final nextDelimiter = ascii.encode('\r\n--$boundary');
    final headerSeparator = ascii.encode('\r\n\r\n');
    var cursor = _indexOf(body, delimiter, 0);
    while (cursor >= 0) {
      var partStart = cursor + delimiter.length;
      if (partStart + 1 < body.length &&
          body[partStart] == 45 &&
          body[partStart + 1] == 45) {
        break;
      }
      if (partStart + 1 < body.length &&
          body[partStart] == 13 &&
          body[partStart + 1] == 10) {
        partStart += 2;
      }
      final headerEnd = _indexOf(body, headerSeparator, partStart);
      if (headerEnd < 0) break;

      final headers = ascii.decode(
        body.sublist(partStart, headerEnd),
        allowInvalid: true,
      );
      final nameMatch = RegExp(r'name="([^"]+)"').firstMatch(headers);
      final name = nameMatch?.group(1);
      final contentStart = headerEnd + headerSeparator.length;
      final next = _indexOf(body, nextDelimiter, contentStart);
      if (next < 0) break;
      if (name != null) {
        parts[name] = Uint8List.fromList(body.sublist(contentStart, next));
      }
      cursor = next + 2;
    }
    return parts;
  }

  int _indexOf(Uint8List haystack, List<int> needle, int start) {
    if (needle.isEmpty || haystack.length < needle.length) return -1;
    for (var index = start; index <= haystack.length - needle.length; index++) {
      var matched = true;
      for (var offset = 0; offset < needle.length; offset++) {
        if (haystack[index + offset] != needle[offset]) {
          matched = false;
          break;
        }
      }
      if (matched) return index;
    }
    return -1;
  }

  bool _isJpeg(Uint8List bytes) {
    return bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
  }

  Future<void> _json(
    HttpRequest request,
    int statusCode,
    Map<String, dynamic> body,
  ) async {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  String _describePeerState(RTCPeerConnectionState state) {
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateNew:
        return '正在建链';
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        return '正在连接';
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        return '实时预览已连接';
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        return '连接中断，等待眼镜重连';
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        return '连接失败，等待眼镜重试';
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        return '连接已关闭';
    }
  }

  String _describeIceState(RTCIceConnectionState state) {
    switch (state) {
      case RTCIceConnectionState.RTCIceConnectionStateNew:
        return 'ICE 初始化';
      case RTCIceConnectionState.RTCIceConnectionStateChecking:
        return '正在检查局域网路径';
      case RTCIceConnectionState.RTCIceConnectionStateConnected:
      case RTCIceConnectionState.RTCIceConnectionStateCompleted:
        return '局域网路径已连通';
      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        return '局域网路径断开';
      case RTCIceConnectionState.RTCIceConnectionStateFailed:
        return '局域网路径失败';
      case RTCIceConnectionState.RTCIceConnectionStateClosed:
        return 'ICE 已关闭';
      case RTCIceConnectionState.RTCIceConnectionStateCount:
        return 'ICE 状态未知';
    }
  }

  String _describeGatheringState(RTCIceGatheringState state) {
    switch (state) {
      case RTCIceGatheringState.RTCIceGatheringStateNew:
        return '等待收集候选地址';
      case RTCIceGatheringState.RTCIceGatheringStateGathering:
        return '正在收集局域网候选地址';
      case RTCIceGatheringState.RTCIceGatheringStateComplete:
        return '候选地址收集完成';
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  double? _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[GlassReceiver] $message');
    }
  }

  bool _isInboundVideoReport(Map<dynamic, dynamic> values) {
    final kind = values['kind']?.toString() ?? values['mediaType']?.toString();
    if (kind != null && kind.toLowerCase().contains('video')) return true;
    return values.containsKey('framesDecoded') ||
        values.containsKey('frameWidth') ||
        values.containsKey('frameHeight') ||
        values.containsKey('googFrameWidthReceived') ||
        values.containsKey('googFrameHeightReceived');
  }
}
