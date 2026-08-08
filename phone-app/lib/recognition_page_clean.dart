import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'app_widgets.dart';
import 'models.dart';
import 'services/vivo_food_vision_service_v3.dart';

class RecognitionPageClean extends StatefulWidget {
  const RecognitionPageClean({
    super.key,
    required this.isConnected,
    required this.profile,
    required this.initialResult,
    required this.aiConfigured,
  });

  final bool isConnected;
  final AppUserProfile profile;
  final AnalysisResult initialResult;
  final bool aiConfigured;

  @override
  State<RecognitionPageClean> createState() => _RecognitionPageCleanState();
}

class _RecognitionPageCleanState extends State<RecognitionPageClean> {
  final ImagePicker _picker = ImagePicker();
  ScanStage _stage = ScanStage.idle;
  late AnalysisResult _result;
  XFile? _selectedImage;
  bool _running = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _result = widget.initialResult;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (image == null) {
        return;
      }
      setState(() {
        _selectedImage = image;
        _error = null;
        _stage = ScanStage.capturing;
      });
    } catch (e) {
      setState(() {
        _error = '获取图片失败：$e';
      });
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先拍照或从相册选择一张图片')),
      );
      return;
    }

    setState(() {
      _running = true;
      _error = null;
      _stage = ScanStage.recognizing;
    });

    await Future<void>.delayed(const Duration(milliseconds: 300));
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
        _stage = ScanStage.completed;
        _running = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _running = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stageLabels = <ScanStage, String>{
      ScanStage.idle: '准备开始识别',
      ScanStage.capturing: '图片已就绪，等待识别',
      ScanStage.recognizing: '正在识别菜品与份量...',
      ScanStage.analyzing: '正在估算营养值并生成建议...',
      ScanStage.completed: '识别完成，可以写入今日记录',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('AI 拍照识别')),
      body: AppBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            GlassCard(
              padding: const EdgeInsets.all(18),
              accent: widget.isConnected ? scheme.primary : const Color(0xFFFFA384),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: widget.isConnected
                          ? scheme.primary.withOpacity(0.12)
                          : const Color(0x22FF9A82),
                    ),
                    child: Icon(
                      widget.isConnected
                          ? Icons.wifi_tethering_rounded
                          : Icons.link_off_rounded,
                      color: widget.isConnected ? scheme.primary : const Color(0xFFFFA384),
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
                        const SizedBox(height: 4),
                        Text(
                          stageLabels[_stage]!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: mutedText(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: '识别流程',
                    trailing: StatusChip(
                      icon: widget.aiConfigured
                          ? Icons.cloud_done_rounded
                          : Icons.science_rounded,
                      label: widget.aiConfigured ? '已配置 AI API' : '当前为演示识别',
                      color: scheme.primary,
                      compact: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FlowBadge(label: '1. 拍照/选图', active: true),
                      FlowBadge(label: '2. 菜品识别', active: true),
                      FlowBadge(label: '3. 营养分析', active: true),
                      FlowBadge(label: '4. 建议输出', active: true),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 230,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: softBorder(context)),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: lightMode(context)
                            ? const [
                                Color(0xFFF6FFFC),
                                Color(0xFFDFF7F0),
                              ]
                            : const [
                                Color(0xFF0A1E22),
                                Color(0xFF14343B),
                              ],
                      ),
                    ),
                    child: _selectedImage == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt_rounded,
                                size: 52,
                                color: scheme.primary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '拍一张餐食照片，或从相册选择一张图',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.file(
                              File(_selectedImage!.path),
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.red.shade400,
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
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('拍照'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
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
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            MealInsightCard(result: _result),
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '针对 ${widget.profile.name} 的建议',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  ..._result.recommendations.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: scheme.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              line,
                              style: Theme.of(context).textTheme.bodyMedium,
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
            OutlinedButton(
              onPressed: _stage == ScanStage.completed
                  ? () => Navigator.of(context).pop(_result)
                  : null,
              child: const Text('写入今日饮食记录'),
            ),
          ],
        ),
      ),
    );
  }
}
