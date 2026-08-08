import 'package:flutter/material.dart';

import '../helpers.dart';
import '../models.dart';
import '../widgets/common_widgets.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({
    super.key,
    required this.focusedMonth,
    required this.selectedDate,
    required this.meals,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDate,
  });

  final DateTime focusedMonth;
  final DateTime selectedDate;
  final List<MealRecord> meals;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final mealsOfDay = meals.where((meal) => sameDay(meal.eatenAt, selectedDate)).toList()
      ..sort((a, b) => a.eatenAt.compareTo(b.eatenAt));
    final totalCalories = mealsOfDay.fold<int>(0, (sum, meal) => sum + meal.calories);
    final totalCarbs = mealsOfDay.fold<double>(0, (sum, meal) => sum + meal.carbs).round();
    final totalProtein =
        mealsOfDay.fold<double>(0, (sum, meal) => sum + meal.protein).round();
    final totalFat = mealsOfDay.fold<double>(0, (sum, meal) => sum + meal.fat).round();
    final days = buildCalendarDays(focusedMonth);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
      children: [
        Center(
          child: Text(
            '日历',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 18),
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: onPreviousMonth,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      '${focusedMonth.year}年${focusedMonth.month}月',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: onNextMonth,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Row(
                children: [
                  Expanded(child: Center(child: Text('日'))),
                  Expanded(child: Center(child: Text('一'))),
                  Expanded(child: Center(child: Text('二'))),
                  Expanded(child: Center(child: Text('三'))),
                  Expanded(child: Center(child: Text('四'))),
                  Expanded(child: Center(child: Text('五'))),
                  Expanded(child: Center(child: Text('六'))),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: days.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final day = days[index];
                  final isCurrentMonth = day.month == focusedMonth.month;
                  final isSelected = sameDay(day, selectedDate);
                  final hasMeal = meals.any((meal) => sameDay(meal.eatenAt, day));
                  return GestureDetector(
                    onTap: () => onSelectDate(day),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? const Color(0x336EF7C8)
                            : hasMeal
                                ? const Color(0x1440B394)
                                : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF6EF7C8)
                              : Colors.white.withOpacity(0.06),
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF6EF7C8).withOpacity(0.28),
                                  blurRadius: 18,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isCurrentMonth
                                ? Colors.white
                                : const Color(0xFF64827C),
                          ),
                        ),
                      ),
                    ),
                  );
                },
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
              Text(
                '${selectedDate.month}月${selectedDate.day}日总结',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: MetricBlock(label: '总摄入', value: '$totalCalories kcal')),
                  Expanded(child: MetricBlock(label: '碳水', value: '${totalCarbs}g')),
                  Expanded(child: MetricBlock(label: '蛋白质', value: '${totalProtein}g')),
                  Expanded(child: MetricBlock(label: '脂肪', value: '${totalFat}g')),
                ],
              ),
              const SizedBox(height: 16),
              for (final meal in mealsOfDay) ...[
                TimelineMealTile(meal: meal),
                if (meal != mealsOfDay.last) const SizedBox(height: 10),
              ],
              if (mealsOfDay.isEmpty)
                Text(
                  '这一天还没有饮食记录，可以点击中间相机按钮模拟 AI 眼镜识别。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF95AAA6),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

