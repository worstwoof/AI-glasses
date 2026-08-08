import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../helpers.dart';
import '../models.dart';

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF071114),
                Color(0xFF0D1E21),
                Color(0xFF061012),
              ],
            ),
          ),
        ),
        const Positioned(
          top: -60,
          left: -20,
          child: GlowOrb(
            size: 230,
            colors: [
              Color(0x5C7AFFD7),
              Color(0x007AFFD7),
            ],
          ),
        ),
        const Positioned(
          right: -70,
          top: 110,
          child: GlowOrb(
            size: 260,
            colors: [
              Color(0x3B76B0FF),
              Color(0x0076B0FF),
            ],
          ),
        ),
        const Positioned(
          left: 40,
          bottom: -60,
          child: GlowOrb(
            size: 300,
            colors: [
              Color(0x2D6EF7C8),
              Color(0x006EF7C8),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class GlowOrb extends StatelessWidget {
  const GlowOrb({super.key, required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accent,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: alpha(accent ?? Colors.white, 0.12),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xCC122226),
            Color(0xAA0B171A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: alpha(accent ?? const Color(0xFF4BC9A7), 0.12),
            blurRadius: 24,
          ),
        ],
      ),
      child: child,
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 7 : 10,
      ),
      decoration: BoxDecoration(
        color: alpha(color, 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: alpha(color, 0.24)),
      ),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Icon(icon, size: compact ? 16 : 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class MetricBlock extends StatelessWidget {
  const MetricBlock({
    super.key,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF8FA39F),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: highlight ? const Color(0xFF79FFD5) : Colors.white,
          ),
        ),
      ],
    );
  }
}

class SuggestionChip extends StatelessWidget {
  const SuggestionChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFFD0DFDB),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class FlowBadge extends StatelessWidget {
  const FlowBadge({
    super.key,
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active
            ? const Color(0x246EF7C8)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? const Color(0x806EF7C8)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: active ? const Color(0xFF9CFFE2) : const Color(0xFF94A7A3),
        ),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                line,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFFB8CBC6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MealInsightCard extends StatelessWidget {
  const MealInsightCard({super.key, required this.result});

  final AnalysisResult result;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      accent: result.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [result.accent, const Color(0xFF0B171A)],
                  ),
                ),
                child: Icon(result.icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.foodName, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      '识别置信度 ${(result.confidence * 100).round()}%',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF8FD6BC),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${result.calories} kcal',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF7AFFD8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: MetricBlock(label: '碳水', value: '${result.carbs.round()}g')),
              Expanded(child: MetricBlock(label: '蛋白质', value: '${result.protein.round()}g')),
              Expanded(child: MetricBlock(label: '脂肪', value: '${result.fat.round()}g')),
              Expanded(child: MetricBlock(label: '纤维', value: '${result.fiber.round()}g')),
            ],
          ),
        ],
      ),
    );
  }
}

class MealTile extends StatelessWidget {
  const MealTile({super.key, required this.meal});

  final MealRecord meal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${meal.mealType} · ${meal.name}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  '${meal.calories} kcal',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '识别置信度 ${(meal.confidence * 100).round()}%',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF8FD6BC),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  alpha(meal.accent, 0.9),
                  const Color(0xFF112529),
                ],
              ),
            ),
            child: Icon(meal.icon, size: 36, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class TimelineMealTile extends StatelessWidget {
  const TimelineMealTile({super.key, required this.meal});

  final MealRecord meal;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: meal.accent,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 2,
              height: 46,
              color: Colors.white.withOpacity(0.08),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${formatTime(meal.eatenAt)}  ${meal.mealType} · ${meal.name}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              Text(
                '${meal.calories} kcal',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFB1C5BF),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MacroLegend extends StatelessWidget {
  const MacroLegend({super.key, required this.summary});

  final MacroSummary summary;

  @override
  Widget build(BuildContext context) {
    final total = math.max(summary.total, 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LegendRow(
          color: const Color(0xFF62F4C6),
          label: '碳水',
          value: '${(summary.carbs / total * 100).round()}%',
        ),
        const SizedBox(height: 10),
        LegendRow(
          color: const Color(0xFFFFB37B),
          label: '脂肪',
          value: '${(summary.fat / total * 100).round()}%',
        ),
        const SizedBox(height: 10),
        LegendRow(
          color: const Color(0xFF7FC0FF),
          label: '蛋白质',
          value: '${(summary.protein / total * 100).round()}%',
        ),
      ],
    );
  }
}

class LegendRow extends StatelessWidget {
  const LegendRow({
    super.key,
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFABC1BB),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class MacroDonutChart extends StatelessWidget {
  const MacroDonutChart({
    super.key,
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.centerLabel,
  });

  final double carbs;
  final double protein;
  final double fat;
  final String centerLabel;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MacroDonutPainter(
        carbs: carbs,
        protein: protein,
        fat: fat,
      ),
      child: Center(
        child: Text(
          centerLabel,
          textAlign: TextAlign.center,
          style: const TextStyle(
            height: 1.35,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _MacroDonutPainter extends CustomPainter {
  _MacroDonutPainter({
    required this.carbs,
    required this.protein,
    required this.fat,
  });

  final double carbs;
  final double protein;
  final double fat;

  @override
  void paint(Canvas canvas, Size size) {
    final total = math.max(carbs + protein + fat, 1);
    final rect = Offset.zero & size;
    const strokeWidth = 18.0;
    final paints = [
      Paint()
        ..color = const Color(0xFF62F4C6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
      Paint()
        ..color = const Color(0xFF7FC0FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
      Paint()
        ..color = const Color(0xFFFFB37B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    ];
    final values = [carbs / total, protein / total, fat / total];
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] * math.pi * 2 - 0.08;
      canvas.drawArc(rect.deflate(10), start, sweep, false, paints[i]);
      start += values[i] * math.pi * 2;
    }
  }

  @override
  bool shouldRepaint(covariant _MacroDonutPainter oldDelegate) {
    return oldDelegate.carbs != carbs ||
        oldDelegate.protein != protein ||
        oldDelegate.fat != fat;
  }
}

