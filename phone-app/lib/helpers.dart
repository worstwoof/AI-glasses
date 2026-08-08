import 'package:flutter/material.dart';

bool sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

List<DateTime> buildCalendarDays(DateTime month) {
  final firstDay = DateTime(month.year, month.month, 1);
  final startOffset = firstDay.weekday % 7;
  final gridStart = firstDay.subtract(Duration(days: startOffset));
  return List<DateTime>.generate(
    42,
    (index) => gridStart.add(Duration(days: index)),
  );
}

String formatTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

Color alpha(Color color, double opacity) {
  return color.withOpacity(opacity);
}

