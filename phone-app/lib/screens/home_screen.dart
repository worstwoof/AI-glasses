import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/common_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.isConnected,
    required this.profile,
    required this.meals,
    required this.remainingCalories,
    required this.eatenCalories,
    required this.macroSummary,
    required this.syncText,
  });

  final bool isConnected;
  final AppUserProfile profile;
  final List<MealRecord> meals;
  final int remainingCalories;
  final int eatenCalories;
  final MacroSummary macroSummary;
  final String syncText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latestMeals = meals.take(3).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
      children: [
        Row(
          children: [
            Expanded(
              child: StatusChip(
                icon: isConnected ? Icons.wifi_tethering_rounded : Icons.link_off,
                label: isConnected ? '已连接 AI 眼镜' : 'AI 眼镜未连接',
                color: isConnected
                    ? const Color(0xFF6EF7C8)
                    : const Color(0xFFFF9E7D),
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0x1FD9FFF4),
              child: Icon(
                Icons.notifications_none_rounded,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '今日饮食',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF9BC0B9),
                ),
              ),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  style: theme.textTheme.headlineLarge,
                  children: [
                    TextSpan(text: '$remainingCalories'),
                    const TextSpan(
                      text: ' kcal',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFC6D9D3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '预计推荐 ${profile.dailyTargetCalories} kcal',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF8EA39F),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: MacroLegend(summary: macroSummary)),
                  SizedBox(
                    width: 132,
                    height: 132,
                    child: MacroDonutChart(
                      carbs: macroSummary.carbs,
                      protein: macroSummary.protein,
                      fat: macroSummary.fat,
                      centerLabel: '$eatenCalories\n已摄入',
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
              SectionHeader(
                title: '饮食记录',
                trailing: Text(
                  syncText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF7BECC7),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              for (final meal in latestMeals) ...[
                MealTile(meal: meal),
                if (meal != latestMeals.last) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(18),
          accent: const Color(0xFF6EF7C8),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0x2E6EF7C8),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.restaurant_menu_rounded,
                  color: Color(0xFFB9FFEA),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI 智能推荐', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      '晚餐建议清蒸鱼、时蔬和糙米饭，补足蛋白质并保持热量余量。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFAFC4BE),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

