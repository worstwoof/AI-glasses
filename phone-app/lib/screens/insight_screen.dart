import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/common_widgets.dart';

class InsightScreen extends StatelessWidget {
  const InsightScreen({
    super.key,
    required this.profile,
    required this.isConnected,
    required this.macroSummary,
    required this.eatenCalories,
    required this.remainingCalories,
    required this.lastAnalysis,
  });

  final AppUserProfile profile;
  final bool isConnected;
  final MacroSummary macroSummary;
  final int eatenCalories;
  final int remainingCalories;
  final AnalysisResult lastAnalysis;

  @override
  Widget build(BuildContext context) {
    final weeklyCalories = <double>[
      1320,
      1480,
      1540,
      1610,
      1390,
      1720,
      eatenCalories.toDouble(),
    ];
    final peak = weeklyCalories.reduce(math.max);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
      children: [
        Center(
          child: Text(
            '健康分析',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 18),
        GlassCard(
          padding: const EdgeInsets.all(18),
          accent: const Color(0xFF74FFD2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: '闭环状态'),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: MetricBlock(
                      label: '眼镜连接',
                      value: isConnected ? '在线' : '离线',
                      highlight: isConnected,
                    ),
                  ),
                  Expanded(
                    child: MetricBlock(
                      label: '今日热量',
                      value: '$eatenCalories kcal',
                      highlight: true,
                    ),
                  ),
                  Expanded(
                    child: MetricBlock(
                      label: '剩余额度',
                      value: '$remainingCalories kcal',
                    ),
                  ),
                ],
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
              const SectionHeader(title: '近 7 日热量趋势'),
              const SizedBox(height: 18),
              SizedBox(
                height: 160,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(weeklyCalories.length, (index) {
                    final value = weeklyCalories[index];
                    final ratio = value / peak;
                    final label = ['一', '二', '三', '四', '五', '六', '今'][index];
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              value.round().toString(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF8CA09D),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 110 * ratio.clamp(0.2, 1.0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Color(0xFF5FF4C8),
                                    Color(0x665FF4C8),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(label),
                          ],
                        ),
                      ),
                    );
                  }),
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
              const SectionHeader(title: '最近识别结果'),
              const SizedBox(height: 14),
              MealInsightCard(result: lastAnalysis),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SuggestionChip(label: '目标：${profile.goal}'),
                  SuggestionChip(label: '偏好：${profile.preference}'),
                  SuggestionChip(label: '过敏源：${profile.allergies.join('、')}'),
                  SuggestionChip(
                    label: '三营养素：${macroSummary.carbs.round()}/${macroSummary.protein.round()}/${macroSummary.fat.round()}g',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...lastAnalysis.recommendations.map(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          size: 16,
                          color: Color(0xFF6EF7C8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tip,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFC8D8D3),
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
      ],
    );
  }
}

