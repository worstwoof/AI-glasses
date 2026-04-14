import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'helpers.dart';
import 'models.dart';

bool lightMode(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light;

Color elevatedSurface(BuildContext context) => lightMode(context)
    ? Colors.white.withOpacity(0.78)
    : const Color(0xEE091619);

Color mutedText(BuildContext context) => lightMode(context)
    ? const Color(0xFF668680)
    : const Color(0xFF9FB3AE);

Color softBorder(BuildContext context) => lightMode(context)
    ? const Color(0x260C6555)
    : Colors.white.withOpacity(0.08);

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isLight = lightMode(context);
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isLight
                  ? const [
                      Color(0xFFF8FFFC),
                      Color(0xFFE6FAF4),
                      Color(0xFFF2FFFB),
                    ]
                  : const [
                      Color(0xFF071114),
                      Color(0xFF0D1E21),
                      Color(0xFF061012),
                    ],
            ),
          ),
        ),
        Positioned(
          top: -60,
          left: -20,
          child: GlowOrb(
            size: 230,
            colors: isLight
                ? const [Color(0x66A9F8DD), Color(0x00A9F8DD)]
                : const [Color(0x5C7AFFD7), Color(0x007AFFD7)],
          ),
        ),
        Positioned(
          right: -70,
          top: 110,
          child: GlowOrb(
            size: 260,
            colors: isLight
                ? const [Color(0x4084BBFF), Color(0x0084BBFF)]
                : const [Color(0x3B76B0FF), Color(0x0076B0FF)],
          ),
        ),
        Positioned(
          left: 40,
          bottom: -60,
          child: GlowOrb(
            size: 300,
            colors: isLight
                ? const [Color(0x3B6EF7C8), Color(0x006EF7C8)]
                : const [Color(0x2D6EF7C8), Color(0x006EF7C8)],
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
    final isLight = lightMode(context);
    final baseAccent = accent ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: baseAccent.withOpacity(isLight ? 0.18 : 0.12),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isLight
              ? [
                  const Color(0xF8FFFFFF),
                  const Color(0xDFF3FFFA),
                ]
              : [
                  const Color(0xCC122226),
                  const Color(0xAA0B171A),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: baseAccent.withOpacity(isLight ? 0.15 : 0.12),
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
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.24)),
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
  const SectionHeader({super.key, required this.title, this.trailing});

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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: mutedText(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: highlight ? scheme.primary : scheme.onSurface,
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.primary.withOpacity(0.14)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: scheme.onSurface,
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active
            ? scheme.primary.withOpacity(0.12)
            : Theme.of(context).colorScheme.surface.withOpacity(0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? scheme.primary.withOpacity(0.35)
              : softBorder(context),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: active ? scheme.primary : mutedText(context),
        ),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.title, required this.lines, this.child});

  final String title;
  final List<String> lines;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (lines.isNotEmpty) const SizedBox(height: 12),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                line,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          if (child != null) ...[
            if (lines.isNotEmpty) const SizedBox(height: 6),
            child!,
          ],
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
    final scheme = Theme.of(context).colorScheme;
    final isLight = lightMode(context);
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
                    colors: [
                      result.accent,
                      isLight ? Colors.white : const Color(0xFF0B171A),
                    ],
                  ),
                ),
                child: Icon(result.icon, color: isLight ? result.accent : Colors.white),
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
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${result.calories} kcal',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: scheme.primary,
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
    final isLight = lightMode(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isLight ? const Color(0x66FFFFFF) : Colors.white.withOpacity(0.04),
        border: Border.all(color: softBorder(context)),
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
                    color: Theme.of(context).colorScheme.primary,
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
                  meal.accent.withOpacity(0.9),
                  isLight ? Colors.white : const Color(0xFF112529),
                ],
              ),
            ),
            child: Icon(
              meal.icon,
              size: 36,
              color: isLight ? meal.accent : Colors.white,
            ),
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
              color: softBorder(context),
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
                  color: mutedText(context),
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
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: mutedText(context),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
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
          style: TextStyle(
            height: 1.35,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
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

