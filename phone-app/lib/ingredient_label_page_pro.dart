import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'models.dart';
import 'services/ingredient_label_service_v2.dart';
import 'ui_kit.dart';

class IngredientLabelPagePro extends StatefulWidget {
  const IngredientLabelPagePro({super.key, required this.profile});

  final AppUserProfile profile;

  @override
  State<IngredientLabelPagePro> createState() => _IngredientLabelPageProState();
}

class _IngredientLabelPageProState extends State<IngredientLabelPagePro> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _running = false;
  String? _error;
  IngredientLabelAnalysisResult? _result;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 1800,
      );
      if (image == null) {
        return;
      }

      setState(() {
        _selectedImage = image;
        _error = null;
      });
    } catch (error) {
      setState(() {
        _error = '获取配料表图片失败：$error';
      });
    }
  }

  Future<void> _runOcr() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先拍照或选择一张配料表图片')));
      return;
    }

    setState(() {
      _running = true;
      _error = null;
    });

    try {
      final result = await IngredientLabelServiceV2.analyzeLabel(
        image: _selectedImage!,
        profile: widget.profile,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
        _running = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _running = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('配料表 OCR')),
      body: MeshBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            PremiumCard(
              accent: const Color(0xFF4A97FF),
              child: Row(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4A97FF), Color(0x334A97FF)],
                      ),
                    ),
                    child: const Icon(
                      Icons.document_scanner_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI OCR 配料分析',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '拍摄包装背面的配料表，系统会识别文字并提示过敏原、争议较高成分和购买建议。',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    title: '拍摄提示',
                    subtitle: '尽量拍全整张标签，避免反光和倾斜',
                    trailing: PillBadge(
                      label: '千问视觉 OCR',
                      icon: Icons.cloud_sync_rounded,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    height: 280,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: appSoftBorder(context)),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isLightTheme(context)
                            ? const [Color(0xFFFFFFFF), Color(0xFFEAF5FF)]
                            : const [Color(0xFF0D191C), Color(0xFF112529)],
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: _selectedImage == null
                          ? const _IngredientPlaceholder()
                          : Image.file(
                              File(_selectedImage!.path),
                              fit: BoxFit.cover,
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
                      child: Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFFC2553F),
                        ),
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
              onPressed: _running ? null : _runOcr,
              icon: _running
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.text_snippet_rounded),
              label: Text(_running ? '识别中...' : '开始 OCR 识别'),
            ),
            if (_result != null) ...[
              const SizedBox(height: 16),
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PageHeader(
                      title: '配料分析结果',
                      subtitle: _result!.usedAi ? 'AI 结构化分析' : '规则兜底分析',
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _result!.summary,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _result!.ingredients
                          .take(12)
                          .map(
                            (item) => PillBadge(
                              label: item,
                              icon: Icons.label_rounded,
                              color: const Color(0xFF4A97FF),
                              soft: true,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '过敏原提醒',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    if (_result!.allergens.isEmpty)
                      Text(
                        '当前未识别到明显的常见过敏原提示词。',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: appMutedText(context),
                        ),
                      )
                    else
                      ..._result!.allergens.map(
                        (item) => _RiskLine(
                          color: const Color(0xFFE57E67),
                          icon: Icons.warning_amber_rounded,
                          title: item.name,
                          description: item.reason,
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
                    Text(
                      '需留意成分',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    if (_result!.cautionIngredients.isEmpty)
                      Text(
                        '暂未识别到明显的高风险提示词，但仍建议结合营养成分表一起判断。',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: appMutedText(context),
                        ),
                      )
                    else
                      ..._result!.cautionIngredients.map(
                        (item) => _RiskLine(
                          color: const Color(0xFFF0A85C),
                          icon: Icons.report_gmailerrorred_rounded,
                          title: item.name,
                          description: item.reason,
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
                    Text('建议', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 14),
                    ..._result!.suggestions.map(
                      (item) => Padding(
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
                                Icons.auto_awesome_rounded,
                                size: 14,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item,
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
              const SizedBox(height: 16),
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OCR 原文',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _result!.rawText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: appMutedText(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IngredientPlaceholder extends StatelessWidget {
  const _IngredientPlaceholder();

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
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.primary.withOpacity(0.28)],
                ),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '对准包装背面的配料表拍照',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              '建议包含“配料表 / 成分表”整块区域，文字越完整，风险分析越准确。',
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

class _RiskLine extends StatelessWidget {
  const _RiskLine({
    required this.color,
    required this.icon,
    required this.title,
    required this.description,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.14),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: appMutedText(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
