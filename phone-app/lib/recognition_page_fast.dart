import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:image_picker/image_picker.dart';

import 'models.dart';
import 'services/glass_receiver_service.dart';
import 'services/phone_scene_classifier.dart';
import 'services/vivo_food_vision_service_v3.dart';
import 'ui_kit.dart';

enum _RecognitionMode { live, single }

class RecognitionPageFast extends StatefulWidget {
  const RecognitionPageFast({
    super.key,
    required this.isConnected,
    required this.profile,
    required this.aiConfigured,
  });

  final bool isConnected;
  final AppUserProfile profile;
  final bool aiConfigured;

  @override
  State<RecognitionPageFast> createState() => _RecognitionPageFastState();
}

class _RecognitionPageFastState extends State<RecognitionPageFast>
    with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  final GlassReceiverService _receiver = GlassReceiverService.instance;

  late final RTCVideoRenderer _remoteRenderer;
  late final Future<void> _rendererReady;
  StreamSubscription<GlassCapture>? _captureSubscription;
  StreamSubscription<MediaStream?>? _remoteStreamSubscription;

  _RecognitionMode _mode = _RecognitionMode.live;
  GlassReceiverSnapshot _receiverState = GlassReceiverService.instance.snapshot;
  ScanStage _stage = ScanStage.idle;
  XFile? _selectedImage;
  AnalysisResult? _result;
  bool _running = false;
  String? _error;

  int get _stageIndex {
    switch (_stage) {
      case ScanStage.idle:
        return 0;
      case ScanStage.capturing:
        return 1;
      case ScanStage.recognizing:
        return 2;
      case ScanStage.analyzing:
        return 3;
      case ScanStage.completed:
        return 4;
    }
  }

  String get _stageText {
    switch (_stage) {
      case ScanStage.idle:
        return '打开实时预览后，眼镜会把同一路 Camera2 预览帧推到手机；需要入库时再抓拍高清图。';
      case ScanStage.capturing:
        return '图片已准备完成，可以开始 AI 识图。';
      case ScanStage.recognizing:
        return '正在识别菜品和主要食材，请稍候。';
      case ScanStage.analyzing:
        return '正在估算营养成分并生成饮食建议。';
      case ScanStage.completed:
        return '识别完成，可以把结果写回今天的饮食记录。';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _remoteRenderer = RTCVideoRenderer();
    _rendererReady = _remoteRenderer.initialize();
    _receiver.addListener(_handleReceiverChanged);
    _captureSubscription = _receiver.captures.listen(_handleGlassCapture);
    _remoteStreamSubscription = _receiver.remoteStreams.listen((stream) {
      unawaited(_attachRemoteStream(stream));
    });
    unawaited(_receiver.start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _receiver.removeListener(_handleReceiverChanged);
    unawaited(_captureSubscription?.cancel());
    unawaited(_remoteStreamSubscription?.cancel());
    _remoteRenderer.srcObject = null;
    unawaited(_remoteRenderer.dispose());
    unawaited(_receiver.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_receiver.start());
      unawaited(_receiver.refreshNetworkAddresses());
    }
  }

  void _handleReceiverChanged() {
    if (!mounted) return;
    setState(() {
      _receiverState = _receiver.snapshot;
    });
  }

  void _handleGlassCapture(GlassCapture capture) {
    if (!mounted) return;
    setState(() {
      _selectedImage = XFile(capture.imageFile.path);
      _result = null;
      _error = null;
      _stage = ScanStage.capturing;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已收到眼镜抓拍图片，可以进入单张识图分析')));
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 72,
        maxWidth: 1280,
      );
      if (image == null) {
        return;
      }

      setState(() {
        _mode = _RecognitionMode.single;
        _selectedImage = image;
        _result = null;
        _error = null;
        _stage = ScanStage.capturing;
      });
    } catch (error) {
      setState(() {
        _error = '获取图片失败：$error';
      });
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先拍照、从相册选择，或等待眼镜上传一张抓拍图片')));
      return;
    }

    setState(() {
      _mode = _RecognitionMode.single;
      _running = true;
      _error = null;
      _result = null;
      _stage = ScanStage.recognizing;
    });

    if (!mounted) {
      return;
    }

    setState(() {
      _stage = ScanStage.analyzing;
    });

    try {
      final result = await VivoFoodVisionServiceV3.analyzeImage(
        image: _selectedImage!,
        profile: widget.profile,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
        _running = false;
        _stage = ScanStage.completed;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _running = false;
        _stage = ScanStage.capturing;
        _error = error.toString();
      });
    }
  }

  Future<void> _copyText(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已复制$label')));
  }

  Future<void> _requestGlassCapture() async {
    final sent = await _receiver.sendCaptureCommand();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(sent ? '已请求眼镜抓拍' : '实时控制通道还没连上')));
  }

  Future<void> _connectGlass() async {
    await _receiver.refreshNetworkAddresses();
    await _receiver.connectToGlasses(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('AI 眼镜识别')),
      body: MeshBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            PremiumCard(
              accent: _receiverState.remoteVideoReady
                  ? scheme.primary
                  : const Color(0xFFE57E67),
              child: Row(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          (_receiverState.remoteVideoReady
                                  ? scheme.primary
                                  : const Color(0xFFE57E67))
                              .withOpacity(0.9),
                          (_receiverState.remoteVideoReady
                                  ? scheme.primary
                                  : const Color(0xFFE57E67))
                              .withOpacity(0.2),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.video_camera_front_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _receiverState.remoteVideoReady
                              ? 'AI 眼镜实时预览中'
                              : '等待 AI 眼镜实时连接',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _stageText,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: appMutedText(context)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PremiumCard(
              padding: const EdgeInsets.all(10),
              child: SegmentedButton<_RecognitionMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment<_RecognitionMode>(
                    value: _RecognitionMode.live,
                    icon: Icon(Icons.videocam_outlined),
                    label: Text('实时预览'),
                  ),
                  ButtonSegment<_RecognitionMode>(
                    value: _RecognitionMode.single,
                    icon: Icon(Icons.image_search_outlined),
                    label: Text('单张识图'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) {
                  setState(() {
                    _mode = selection.first;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _mode == _RecognitionMode.live
                  ? _LivePreviewPane(
                      key: const ValueKey('live'),
                      rendererReady: _rendererReady,
                      renderer: _remoteRenderer,
                      snapshot: _receiverState,
                      hasSelectedImage: _selectedImage != null,
                      onCopyUploadEndpoint: () =>
                          _copyText(_receiverState.uploadEndpoint, '上传地址'),
                      onCopySignalingEndpoint: () =>
                          _copyText(_receiverState.signalingEndpoint, '信令地址'),
                      onCopyToken: () =>
                          _copyText(_receiverState.token, '配对令牌'),
                      onConnectGlass: () => unawaited(_connectGlass()),
                      onResetToken: () => unawaited(_receiver.resetToken()),
                      onRequestCapture: _requestGlassCapture,
                      onAnalyzeLatest: _analyzeImage,
                      onOpenSingleMode: () {
                        setState(() {
                          _mode = _RecognitionMode.single;
                        });
                      },
                    )
                  : _buildSingleImageFlow(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _attachRemoteStream(MediaStream? stream) async {
    await _rendererReady;
    if (!mounted) return;
    _remoteRenderer.srcObject = stream;
    setState(() {});
  }

  Widget _buildSingleImageFlow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      key: const ValueKey('single'),
      children: [
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: '识别流程',
                subtitle: '手机补拍、相册导入和眼镜抓拍都走同一个 AI 分析入口',
                trailing: PillBadge(
                  label: widget.aiConfigured ? '已配置 AI API' : '当前为演示模式',
                  icon: widget.aiConfigured
                      ? Icons.cloud_done_rounded
                      : Icons.science_rounded,
                  color: widget.aiConfigured
                      ? scheme.primary
                      : const Color(0xFFE39B64),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  StageChip(
                    label: '1. 拍照/选图',
                    active: _stageIndex == 1,
                    completed: _stageIndex > 1,
                  ),
                  StageChip(
                    label: '2. 菜品识别',
                    active: _stageIndex == 2,
                    completed: _stageIndex > 2,
                  ),
                  StageChip(
                    label: '3. 营养分析',
                    active: _stageIndex == 3,
                    completed: _stageIndex > 3,
                  ),
                  StageChip(
                    label: '4. 建议输出',
                    active: _stageIndex == 4,
                    completed: _stageIndex > 4,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                height: 288,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: _selectedImage == null
                        ? appSoftBorder(context)
                        : scheme.primary.withOpacity(0.16),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isLightTheme(context)
                        ? const [Color(0xFFFFFFFF), Color(0xFFEAFBF6)]
                        : const [Color(0xFF0D191C), Color(0xFF112529)],
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _selectedImage == null
                        ? const _EmptyPreview(key: ValueKey('empty'))
                        : Stack(
                            key: const ValueKey('image'),
                            fit: StackFit.expand,
                            children: [
                              Image.file(
                                File(_selectedImage!.path),
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                left: 14,
                                top: 14,
                                child: PillBadge(
                                  label: _running ? 'AI 分析中' : '已选中餐食图片',
                                  icon: _running
                                      ? Icons.auto_awesome_rounded
                                      : Icons.image_rounded,
                                  color: Colors.white,
                                  soft: true,
                                ),
                              ),
                              Positioned(
                                right: 14,
                                bottom: 14,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: Colors.black.withOpacity(0.32),
                                  ),
                                  child: const Text(
                                    '建议拍全餐盘与主要食材',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _ErrorPanel(message: _error!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _running
                    ? null
                    : () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('拍照'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _running
                    ? null
                    : () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('相册'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _running ? null : _analyzeImage,
          icon: _running
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome_rounded),
          label: Text(_running ? '识别中...' : '开始 AI 识图'),
        ),
        if (_result != null) ...[
          const SizedBox(height: 16),
          AnalysisSnapshotCard(result: _result!),
          const SizedBox(height: 16),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '给 ${widget.profile.name} 的建议',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                ..._result!.recommendations.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.primary.withOpacity(0.12),
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            line,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).pop(_result!),
            icon: const Icon(Icons.add_chart_rounded),
            label: const Text('写入今日饮食记录'),
          ),
        ],
      ],
    );
  }
}

class _LivePreviewPane extends StatelessWidget {
  const _LivePreviewPane({
    super.key,
    required this.rendererReady,
    required this.renderer,
    required this.snapshot,
    required this.hasSelectedImage,
    required this.onCopyUploadEndpoint,
    required this.onCopySignalingEndpoint,
    required this.onCopyToken,
    required this.onConnectGlass,
    required this.onResetToken,
    required this.onRequestCapture,
    required this.onAnalyzeLatest,
    required this.onOpenSingleMode,
  });

  final Future<void> rendererReady;
  final RTCVideoRenderer renderer;
  final GlassReceiverSnapshot snapshot;
  final bool hasSelectedImage;
  final VoidCallback onCopyUploadEndpoint;
  final VoidCallback onCopySignalingEndpoint;
  final VoidCallback onCopyToken;
  final VoidCallback onConnectGlass;
  final VoidCallback onResetToken;
  final VoidCallback onRequestCapture;
  final VoidCallback onAnalyzeLatest;
  final VoidCallback onOpenSingleMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        PremiumCard(
          accent: scheme.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: '实时预览',
                subtitle: snapshot.remoteVideoReady
                    ? snapshot.serverMessage
                    : snapshot.glassesMessage,
                trailing: PillBadge(
                  label: snapshot.remoteVideoReady ? '视频已连接' : '等待建链',
                  icon: snapshot.remoteVideoReady
                      ? Icons.connected_tv_rounded
                      : Icons.wifi_tethering_rounded,
                  color: snapshot.remoteVideoReady
                      ? scheme.primary
                      : const Color(0xFFE39B64),
                ),
              ),
              const SizedBox(height: 14),
              _SceneModeBanner(snapshot: snapshot),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Container(
                    color: const Color(0xFF071114),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        FutureBuilder<void>(
                          future: rendererReady,
                          builder: (context, ready) {
                            if (ready.connectionState != ConnectionState.done ||
                                renderer.srcObject == null) {
                              return _LiveEmptyOverlay(snapshot: snapshot);
                            }
                            return RTCVideoView(
                              renderer,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
                            );
                          },
                        ),
                        Positioned(
                          left: 12,
                          top: 12,
                          child: PillBadge(
                            label: snapshot.peerState,
                            icon: Icons.radio_button_checked_rounded,
                            color: Colors.white,
                            soft: true,
                          ),
                        ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _DarkMetric(
                                label: 'ICE',
                                value: snapshot.iceState,
                              ),
                              _DarkMetric(
                                label: '视频',
                                value: snapshot.statsText,
                              ),
                              _DarkMetric(
                                label: '控制',
                                value: snapshot.controlReady ? '可抓拍' : '未就绪',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: snapshot.controlReady
                          ? onRequestCapture
                          : null,
                      icon: const Icon(Icons.camera_rounded),
                      label: const Text('眼镜抓拍'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: hasSelectedImage ? onAnalyzeLatest : null,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('分析最新图'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: snapshot.connectingGlasses
                          ? null
                          : onConnectGlass,
                      icon: snapshot.connectingGlasses
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_find_rounded),
                      label: Text(snapshot.connectingGlasses ? '连接中' : '连接眼镜'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onOpenSingleMode,
                      icon: const Icon(Icons.image_search_rounded),
                      label: const Text('单张模式'),
                    ),
                  ),
                ],
              ),
              if (snapshot.error != null) ...[
                const SizedBox(height: 14),
                _ErrorPanel(message: snapshot.error!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: '配对信息',
                subtitle: snapshot.localIps.isEmpty
                    ? '未读取到局域网 IPv4，确认手机已连接 Wi-Fi 或热点'
                    : '眼镜端会自动接收手机连接指令；这些地址用于调试和手动排查',
              ),
              const SizedBox(height: 14),
              _EndpointRow(
                label: '上传地址',
                value: snapshot.uploadEndpoint,
                icon: Icons.cloud_upload_outlined,
                onCopy: onCopyUploadEndpoint,
              ),
              const SizedBox(height: 10),
              _EndpointRow(
                label: '信令地址',
                value: snapshot.signalingEndpoint,
                icon: Icons.hub_outlined,
                onCopy: onCopySignalingEndpoint,
              ),
              const SizedBox(height: 10),
              _EndpointRow(
                label: '配对令牌',
                value: snapshot.token.isEmpty ? '生成中...' : snapshot.token,
                icon: Icons.key_rounded,
                onCopy: onCopyToken,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onResetToken,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重置令牌'),
              ),
            ],
          ),
        ),
        if (snapshot.lastCapture != null) ...[
          const SizedBox(height: 16),
          _LastCaptureCard(capture: snapshot.lastCapture!),
        ],
      ],
    );
  }
}

class _SceneModeBanner extends StatelessWidget {
  const _SceneModeBanner({required this.snapshot});

  final GlassReceiverSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final scene = snapshot.sceneClassification;
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, description) = switch (scene.mode) {
      PhoneSceneMode.ingredientLabel => (
        Icons.document_scanner_outlined,
        const Color(0xFF3377D6),
        'OK 手势已确认，下一步接配料表 OCR 与成分风险分析。',
      ),
      PhoneSceneMode.eating => (
        Icons.restaurant_rounded,
        const Color(0xFF2A9D76),
        '张开手掌已确认，下一步接食物识别、热量计算与无感记录。',
      ),
      PhoneSceneMode.error => (
        Icons.error_outline_rounded,
        const Color(0xFFE57E67),
        scene.message,
      ),
      _ => (
        Icons.back_hand_outlined,
        scheme.primary,
        '手机端本地模型：OK 进入配料表模式，张开手掌进入进餐环境。',
      ),
    };
    final confidence = scene.confidence <= 0
        ? '--'
        : '${(scene.confidence * 100).round()}%';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scene.label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: appMutedText(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$confidence\n${snapshot.sceneFrameCount} 帧',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveEmptyOverlay extends StatelessWidget {
  const _LiveEmptyOverlay({required this.snapshot});

  final GlassReceiverSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_outlined,
              size: 46,
              color: Colors.white70,
            ),
            const SizedBox(height: 14),
            Text(
              snapshot.connectingGlasses
                  ? '正在连接 RV101 眼镜'
                  : snapshot.running
                  ? '等待 RV101 推送实时画面'
                  : '本机接收服务未启动',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              snapshot.running ? snapshot.glassesMessage : '点击连接眼镜后会重新监听局域网端口。',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.onCopy,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: scheme.primary.withOpacity(0.07),
        border: Border.all(color: scheme.primary.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: appMutedText(context),
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  value,
                  maxLines: 3,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '复制$label',
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
    );
  }
}

class _DarkMetric extends StatelessWidget {
  const _DarkMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withOpacity(0.34),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        '$label  $value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LastCaptureCard extends StatelessWidget {
  const _LastCaptureCard({required this.capture});

  final GlassCapture capture;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PremiumCard(
      accent: scheme.primary,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.file(
              capture.imageFile,
              width: 88,
              height: 88,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('最新眼镜抓拍', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  '${capture.trigger} · ${capture.scene}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: appMutedText(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${capture.receivedAt.hour.toString().padLeft(2, '0')}:'
                  '${capture.receivedAt.minute.toString().padLeft(2, '0')} 收到',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFFFFEEE9),
        border: Border.all(color: const Color(0x33E57E67)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFE57E67)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: const Color(0xFFC2553F)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.primary.withOpacity(0.28)],
                ),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 34,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '拍一张餐食照片，或等待眼镜上传抓拍图',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              '实时预览只负责看画面；饮食记录仍以抓拍后的单张 AI 分析结果为准。',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: appMutedText(context)),
            ),
          ],
        ),
      ),
    );
  }
}
