import 'package:flutter/material.dart';

import '../demo_data.dart';
import '../helpers.dart';
import '../models.dart';
import '../widgets/common_widgets.dart';

class RecognitionFlowPage extends StatefulWidget {
  const RecognitionFlowPage({
    super.key,
    required this.isConnected,
    required this.profile,
    required this.initialResult,
  });

  final bool isConnected;
  final AppUserProfile profile;
  final AnalysisResult initialResult;

  @override
  State<RecognitionFlowPage> createState() => _RecognitionFlowPageState();
}

class _RecognitionFlowPageState extends State<RecognitionFlowPage> {
  ScanStage _stage = ScanStage.idle;
  late AnalysisResult _result;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _result = widget.initialResult;
  }

  Future<void> _runDemo() async {
    if (_running) {
      return;
    }
    setState(() {
      _running = true;
      _stage = ScanStage.capturing;
    });

    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) {
      return;
    }
    setState(() {
      _stage = ScanStage.recognizing;
    });

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) {
      return;
    }
    setState(() {
      _stage = ScanStage.analyzing;
      _result = DemoData.analysisCandidates[
          DateTime.now().millisecond % DemoData.analysisCandidates.length];
    });

    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (!mounted) {
      return;
    }
    setState(() {
      _stage = ScanStage.completed;
      _running = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final stageLabels = <ScanStage, String>{
      ScanStage.idle: '准备连接识别流',
      ScanStage.capturing: '正在从 AI 眼镜抓取图像...',
      ScanStage.recognizing: '正在识别菜品与份量...',
      ScanStage.analyzing: '正在估算营养与生成建议...',
      ScanStage.completed: '闭环分析完成，可写入今日记录',
    };

    return Scaffold(
      backgroundColor: const Color(0xFF051012),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('AI 识别闭环'),
      ),
      body: AppBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            GlassCard(
              padding: const EdgeInsets.all(18),
              accent: widget.isConnected
                  ? const Color(0xFF74FFD2)
                  : const Color(0xFFFFA384),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: widget.isConnected
                          ? const Color(0x226EF7C8)
                          : const Color(0x22FF9A82),
                    ),
                    child: Icon(
                      widget.isConnected
                          ? Icons.wifi_tethering_rounded
                          : Icons.link_off_rounded,
                      color: widget.isConnected
                          ? const Color(0xFF74FFD2)
                          : const Color(0xFFFFA384),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isConnected ? '已连接 AI 眼镜' : '未检测到 AI 眼镜',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          stageLabels[_stage]!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF9EB2AE),
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
                  const SectionHeader(title: '识别流程'),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FlowBadge(
                        label: '1. 图像采集',
                        active: _stage.index >= ScanStage.capturing.index,
                      ),
                      FlowBadge(
                        label: '2. 菜品识别',
                        active: _stage.index >= ScanStage.recognizing.index,
                      ),
                      FlowBadge(
                        label: '3. 营养估算',
                        active: _stage.index >= ScanStage.analyzing.index,
                      ),
                      FlowBadge(
                        label: '4. 建议输出',
                        active: _stage.index >= ScanStage.completed.index,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 190,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF0A1E22),
                          Color(0xFF14343B),
                          Color(0xFF0A181C),
                        ],
                      ),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: RadialGradient(
                                center: const Alignment(0.6, -0.3),
                                radius: 1,
                                colors: [
                                  alpha(const Color(0xFF74FFD2), 0.27),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Positioned(
                          top: 18,
                          left: 18,
                          child: Icon(
                            Icons.visibility_rounded,
                            color: Color(0xFF7EF9D8),
                            size: 30,
                          ),
                        ),
                        Positioned(
                          right: 18,
                          top: 16,
                          child: StatusChip(
                            icon: Icons.auto_awesome_rounded,
                            label: widget.isConnected ? '实时视频流' : '模拟模式',
                            color: const Color(0xFF74FFD2),
                            compact: true,
                          ),
                        ),
                        const Center(
                          child: Icon(
                            Icons.ramen_dining_rounded,
                            size: 82,
                            color: Color(0xFF9CFBDF),
                          ),
                        ),
                        Positioned(
                          left: 22,
                          right: 22,
                          bottom: 20,
                          child: Text(
                            '识别对象将来自眼镜实时画面，当前用本地演示数据模拟。',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFFB2C6C1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                  Text('针对 ${widget.profile.name} 的建议', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  ..._result.recommendations.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF74FFD2),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              line,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFFC9D9D4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: widget.isConnected ? _runDemo : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF74FFD2),
                foregroundColor: const Color(0xFF081416),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(_running ? '分析中...' : '模拟一次识别'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _stage == ScanStage.completed
                  ? () => Navigator.of(context).pop(_result)
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0x556EF7C8)),
              ),
              child: const Text('写入今日饮食记录'),
            ),
          ],
        ),
      ),
    );
  }
}
