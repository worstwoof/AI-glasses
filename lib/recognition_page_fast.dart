import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'models.dart';
import 'services/vivo_food_vision_service_v3.dart';
import 'ui_kit.dart';

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

class _RecognitionPageFastState extends State<RecognitionPageFast> {
  final ImagePicker _picker = ImagePicker();

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
        return '先拍一张完整餐食图，系统会自动完成菜品识别、热量估算和建议生成。';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先拍照或从相册选择一张餐食图片')),
      );
      return;
    }

    setState(() {
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('AI 拍照识别')),
      body: MeshBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            PremiumCard(
              accent: widget.isConnected ? scheme.primary : const Color(0xFFE57E67),
              child: Row(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          (widget.isConnected ? scheme.primary : const Color(0xFFE57E67))
                              .withOpacity(0.9),
                          (widget.isConnected ? scheme.primary : const Color(0xFFE57E67))
                              .withOpacity(0.2),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.wifi_tethering_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isConnected ? '已连接 AI 眼镜' : '当前未连接 AI 眼镜',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _stageText,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: appMutedText(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    title: '识别流程',
                    subtitle: '从拍照到营养建议，一次完成',
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
                            ? const [
                                Color(0xFFFFFFFF),
                                Color(0xFFEAFBF6),
                              ]
                            : const [
                                Color(0xFF0D191C),
                                Color(0xFF112529),
                              ],
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
                                        '建议拍全锅底与主要食材',
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
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: const Color(0xFFFFEEE9),
                        border: Border.all(color: const Color(0x33E57E67)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFE57E67),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: const Color(0xFFC2553F),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _running ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('拍照'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _running ? null : () => _pickImage(ImageSource.gallery),
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
        ),
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
                  colors: [
                    scheme.primary,
                    scheme.primary.withOpacity(0.28),
                  ],
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
              '拍一张餐食照片，或从相册选择一张图',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              '建议把餐盘、锅底和主要食材都拍进去，这样热量和营养估算会更稳。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: appMutedText(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
