
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'models.dart';
import 'packaging_models.dart';
import 'services/glass_capture_extensions.dart';
import 'services/glass_receiver_service.dart';
import 'services/packaging_analysis_service.dart';
import 'ui_kit.dart';

enum _PackagingPageStage { received, analyzing, needConfirmation, failed }

class PackagingAnalysisPage extends StatefulWidget {
  const PackagingAnalysisPage({
    super.key,
    required this.capture,
    required this.profile,
  });

  final GlassCapture capture;
  final AppUserProfile profile;

  @override
  State<PackagingAnalysisPage> createState() => _PackagingAnalysisPageState();
}

class _PackagingAnalysisPageState extends State<PackagingAnalysisPage> {
  static const _service = PackagingAnalysisService();

  _PackagingPageStage _stage = _PackagingPageStage.received;
  PackagingAnalysisResult? _result;
  String? _error;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAnalysis());
  }

  Future<void> _runAnalysis() async {
    if (_running) return;
    setState(() {
      _running = true;
      _stage = _PackagingPageStage.analyzing;
      _error = null;
      _result = null;
    });

    try {
      // The received file is the original JPEG. Do not pass it through
      // ImagePicker, resize, or imageQuality before OCR.
      final result = await _service.analyzeImage(
        image: XFile(widget.capture.imageFile.path),
        profile: widget.profile,
      );
      if (!mounted) return;
      setState(() {
        _running = false;
        _stage = _PackagingPageStage.needConfirmation;
        _result = result;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _stage = _PackagingPageStage.failed;
        _error = error.toString();
      });
    }
  }

  Future<void> _copyRawText() async {
    final rawText = _result?.rawOcrText;
    if (rawText == null) return;
    await Clipboard.setData(ClipboardData(text: rawText));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制 OCR 原文')));
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('包装食品分析')),
      body: MeshBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            PremiumCard(
              accent: scheme.primary,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      widget.capture.imageFile,
                      width: 92,
                      height: 92,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '包装图片已接收',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.capture.width ?? '--'} × ${widget.capture.height ?? '--'} · ${widget.capture.captureSource}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: appMutedText(context)),
                        ),
                        const SizedBox(height: 8),
                        _StageBadge(stage: _stage),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.capture.isLowResolutionFallback) ...[
              const SizedBox(height: 12),
              _WarningBox(message: '本次抓拍使用低清降级图，包装文字识别可能不完整，建议重新拍摄。'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              _WarningBox(message: _error!),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _running ? null : _runAnalysis,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重试 OCR'),
              ),
            ],
            if (result != null) ...[
              const SizedBox(height: 12),
              _NutritionCard(facts: result.nutrition),
              const SizedBox(height: 12),
              _FindingCard(
                title: '配料',
                icon: Icons.receipt_long_rounded,
                children: result.ingredients.isEmpty
                    ? [const Text('未能从 OCR 原文定位配料表，请展开原文核对。')]
                    : [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: result.ingredients
                              .map((item) => Chip(label: Text(item)))
                              .toList(),
                        ),
                      ],
              ),
              const SizedBox(height: 12),
              _FindingCard(
                title: '过敏原与风险',
                icon: Icons.warning_amber_rounded,
                children: [
                  if (result.risks.isEmpty)
                    const Text('暂未发现规则型风险；请结合完整标签和实际食用量判断。'),
                  ...result.risks.map((risk) => _RiskLine(risk: risk)),
                ],
              ),
              const SizedBox(height: 12),
              _FindingCard(
                title: '个性化提示',
                icon: Icons.person_search_rounded,
                children: result.suggestions.map(Text.new).toList(),
              ),
              const SizedBox(height: 12),
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'OCR 原文',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: '复制 OCR 原文',
                          onPressed: _copyRawText,
                          icon: const Icon(Icons.copy_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(result.rawOcrText),
                    const SizedBox(height: 12),
                    Text(
                      '包装分析仅供健康管理参考，不代表医疗诊断，也不会自动写入饮食记录。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _NutritionCard extends StatelessWidget {
  const _NutritionCard({required this.facts});

  final NutritionFacts facts;

  @override
  Widget build(BuildContext context) {
    final values = <String, NutritionValue?>{
      '能量': facts.energy,
      '蛋白质': facts.protein,
      '脂肪': facts.fat,
      '碳水化合物': facts.carbohydrate,
      '钠': facts.sodium,
      '糖': facts.sugar,
    };
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('结构化营养信息', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            '计量基准：${facts.basis.label} · 已解析 ${facts.parsedFieldCount} 项',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          ...values.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: Text(entry.key)),
                  Text(
                    entry.value == null
                        ? '未识别'
                        : '${entry.value!.displayValue} ${entry.value!.unit}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FindingCard extends StatelessWidget {
  const _FindingCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _RiskLine extends StatelessWidget {
  const _RiskLine({required this.risk});

  final PackagingRisk risk;

  @override
  Widget build(BuildContext context) {
    final color = switch (risk.level) {
      PackagingRiskLevel.high => const Color(0xFFD75B4A),
      PackagingRiskLevel.warning => const Color(0xFFD89032),
      PackagingRiskLevel.info => Theme.of(context).colorScheme.primary,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.report_gmailerrorred_rounded, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  risk.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  risk.reason,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StageBadge extends StatelessWidget {
  const _StageBadge({required this.stage});

  final _PackagingPageStage stage;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (stage) {
      _PackagingPageStage.received => ('RECEIVED', Icons.inbox_rounded),
      _PackagingPageStage.analyzing => ('ANALYZING', Icons.sync_rounded),
      _PackagingPageStage.needConfirmation => (
        'NEED_CONFIRMATION',
        Icons.fact_check_rounded,
      ),
      _PackagingPageStage.failed => ('FAILED', Icons.error_outline_rounded),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 16), const SizedBox(width: 5), Text(label)],
    );
  }
}

class _WarningBox extends StatelessWidget {
  const _WarningBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEE9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x33E57E67)),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFFC2553F))),
    );
  }
}
