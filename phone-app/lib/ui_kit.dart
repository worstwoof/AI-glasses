import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'helpers.dart';
import 'models.dart';

bool isLightTheme(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light;

Color appMutedText(BuildContext context) => isLightTheme(context)
    ? const Color(0xFF58726C)
    : const Color(0xFF9CB3AD);

Color appSoftBorder(BuildContext context) => isLightTheme(context)
    ? const Color(0x190B5148)
    : Colors.white.withOpacity(0.08);

Color appElevatedSurface(BuildContext context) => isLightTheme(context)
    ? const Color(0xDFFFFFFF)
    : const Color(0xD0131E22);

class MeshBackground extends StatelessWidget {
  const MeshBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final light = isLightTheme(context);

    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: light
                  ? const [
                      Color(0xFFF9FFFD),
                      Color(0xFFE8FAF5),
                      Color(0xFFF2FFFB),
                      Color(0xFFE4F2FF),
                    ]
                  : const [
                      Color(0xFF071114),
                      Color(0xFF0A171B),
                      Color(0xFF0C2023),
                    ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        Positioned(
          top: -80,
          left: -30,
          child: AmbientGlow(
            size: 260,
            colors: light
                ? const [Color(0x668CF2D1), Color(0x008CF2D1)]
                : const [Color(0x555EF6CD), Color(0x005EF6CD)],
          ),
        ),
        Positioned(
          right: -70,
          top: 80,
          child: AmbientGlow(
            size: 280,
            colors: light
                ? const [Color(0x4F86B8FF), Color(0x0086B8FF)]
                : const [Color(0x356BA7FF), Color(0x006BA7FF)],
          ),
        ),
        Positioned(
          left: 20,
          bottom: -90,
          child: AmbientGlow(
            size: 320,
            colors: light
                ? const [Color(0x4076F5CC), Color(0x0076F5CC)]
                : const [Color(0x2F76F5CC), Color(0x0076F5CC)],
          ),
        ),
        child,
      ],
    );
  }
}

class AmbientGlow extends StatelessWidget {
  const AmbientGlow({
    super.key,
    required this.size,
    required this.colors,
  });

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

class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.accent,
    this.radius = 30,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final light = isLightTheme(context);
    final base = accent ?? Theme.of(context).colorScheme.primary;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: base.withOpacity(light ? 0.16 : 0.12),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: light
              ? const [
                  Color(0xFCFFFFFF),
                  Color(0xEBF4FFFA),
                  Color(0xDDF3FFFB),
                ]
              : const [
                  Color(0xD9152428),
                  Color(0xC00D181B),
                  Color(0xB60A1417),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: base.withOpacity(light ? 0.12 : 0.08),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: appMutedText(context),
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class PillBadge extends StatelessWidget {
  const PillBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.soft = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: soft ? color.withOpacity(0.08) : color.withOpacity(0.14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class FloatingPulse extends StatelessWidget {
  const FloatingPulse({
    super.key,
    required this.child,
    required this.color,
  });

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.92, end: 1),
      duration: const Duration(milliseconds: 1800),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity((1 - value) * 0.36 + 0.12),
                blurRadius: 40 * value,
                spreadRadius: 3 * value,
              ),
            ],
          ),
          child: child,
        );
      },
      child: child,
      onEnd: () {},
    );
  }
}

class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: color.withOpacity(0.16)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.14),
                Colors.white.withOpacity(isLightTheme(context) ? 0.8 : 0.04),
              ],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: color.withOpacity(0.14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: appMutedText(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MetricChip extends StatelessWidget {
  const MetricChip({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: accent.withOpacity(0.10),
        border: Border.all(color: accent.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: appMutedText(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class FoodRecordCard extends StatelessWidget {
  const FoodRecordCard({super.key, required this.meal});

  final MealRecord meal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isLightTheme(context)
            ? Colors.white.withOpacity(0.64)
            : Colors.white.withOpacity(0.04),
        border: Border.all(color: appSoftBorder(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.mealType,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: appMutedText(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  meal.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '${meal.calories} kcal',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '置信度 ${(meal.confidence * 100).round()}%',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: meal.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  meal.accent,
                  meal.accent.withOpacity(0.16),
                ],
              ),
            ),
            child: Icon(
              meal.icon,
              size: 38,
              color: isLightTheme(context) ? Colors.white : meal.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class MealTimelineRow extends StatelessWidget {
  const MealTimelineRow({super.key, required this.meal, this.last = false});

  final MealRecord meal;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: meal.accent,
                boxShadow: [
                  BoxShadow(
                    color: meal.accent.withOpacity(0.35),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
            if (!last)
              Container(
                width: 2,
                height: 52,
                color: appSoftBorder(context),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
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
                    color: appMutedText(context),
                  ),
                ),
              ],
            ),
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                height: 1.35,
                fontWeight: FontWeight.w800,
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
    final rect = Offset.zero & size;
    final total = math.max(carbs + protein + fat, 1);
    const strokeWidth = 18.0;

    final bgPaint = Paint()
      ..color = const Color(0x120B5148)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect.deflate(10), 0, math.pi * 2, false, bgPaint);

    final paints = [
      Paint()
        ..color = const Color(0xFF67EEC6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
      Paint()
        ..color = const Color(0xFF79BFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
      Paint()
        ..color = const Color(0xFFFFB878)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    ];
    final segments = [carbs / total, protein / total, fat / total];
    var start = -math.pi / 2;

    for (var i = 0; i < segments.length; i++) {
      final sweep = segments[i] * math.pi * 2 - 0.10;
      canvas.drawArc(rect.deflate(10), start, sweep, false, paints[i]);
      start += segments[i] * math.pi * 2;
    }
  }

  @override
  bool shouldRepaint(covariant _MacroDonutPainter oldDelegate) {
    return oldDelegate.carbs != carbs ||
        oldDelegate.protein != protein ||
        oldDelegate.fat != fat;
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
        _LegendRow(
          color: const Color(0xFF67EEC6),
          label: '碳水',
          value: '${(summary.carbs / total * 100).round()}%',
        ),
        const SizedBox(height: 12),
        _LegendRow(
          color: const Color(0xFF79BFFF),
          label: '蛋白质',
          value: '${(summary.protein / total * 100).round()}%',
        ),
        const SizedBox(height: 12),
        _LegendRow(
          color: const Color(0xFFFFB878),
          label: '脂肪',
          value: '${(summary.fat / total * 100).round()}%',
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
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
              color: appMutedText(context),
            ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class AnalysisSnapshotCard extends StatelessWidget {
  const AnalysisSnapshotCard({super.key, required this.result});

  final AnalysisResult result;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      accent: result.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      result.accent,
                      result.accent.withOpacity(0.18),
                    ],
                  ),
                ),
                child: Icon(result.icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.foodName, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      '识别置信度 ${(result.confidence * 100).round()}%',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: result.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${result.calories} kcal',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: result.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: MetricChip(label: '碳水', value: '${result.carbs.round()}g')),
              const SizedBox(width: 10),
              Expanded(child: MetricChip(label: '蛋白质', value: '${result.protein.round()}g')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: MetricChip(label: '脂肪', value: '${result.fat.round()}g')),
              const SizedBox(width: 10),
              Expanded(child: MetricChip(label: '纤维', value: '${result.fiber.round()}g')),
            ],
          ),
        ],
      ),
    );
  }
}

class StageChip extends StatelessWidget {
  const StageChip({
    super.key,
    required this.label,
    required this.active,
    required this.completed,
  });

  final String label;
  final bool active;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = completed || active ? scheme.primary : appMutedText(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: active
            ? scheme.primary.withOpacity(0.16)
            : completed
                ? scheme.primary.withOpacity(0.10)
                : Colors.transparent,
        border: Border.all(
          color: active || completed
              ? scheme.primary.withOpacity(0.22)
              : appSoftBorder(context),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            completed ? Icons.check_circle_rounded : Icons.brightness_1_rounded,
            size: completed ? 16 : 10,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
