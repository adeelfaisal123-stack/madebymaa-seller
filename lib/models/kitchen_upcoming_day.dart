import 'dart:convert';

import 'dish_availability.dart';
import 'kitchen_open_days.dart';
import 'kitchen_open_meal.dart';

/// Planned kitchen availability for a specific calendar day.
class KitchenUpcomingDayPlan {
  const KitchenUpcomingDayPlan({
    required this.slot,
    required this.date,
    required this.open,
    required this.meals,
    this.preorderDiscountPercent = 0,
    this.label,
  });

  /// `tomorrow` or `day_after` — sent to the API so dates match server timezone.
  final String slot;
  final String date;
  final String? label;
  final bool open;
  final List<String> meals;
  final double preorderDiscountPercent;

  factory KitchenUpcomingDayPlan.closed({
    required String slot,
    required String date,
    String? label,
  }) {
    return KitchenUpcomingDayPlan(
      slot: slot,
      date: date,
      label: label,
      open: false,
      meals: const [],
      preorderDiscountPercent: 0,
    );
  }

  factory KitchenUpcomingDayPlan.fromJson(Map<String, dynamic> json) {
    final date = json['date'] as String? ?? '';
    final slot = json['slot'] as String? ??
        (date.isNotEmpty ? _slotFromLegacyDate(date) : 'tomorrow');

    return KitchenUpcomingDayPlan(
      slot: slot,
      date: date,
      label: json['label'] as String?,
      open: json['open'] == true,
      meals: parseKitchenOpenMeals(json['meals']),
      preorderDiscountPercent: _parseDiscount(json['preorder_discount_percent']),
    );
  }

  Map<String, dynamic> toJson() => {
        'slot': slot,
        'open': open,
        'meals': open ? meals : <String>[],
        'preorder_discount_percent': open ? preorderDiscountPercent : 0,
      };

  static String _slotFromLegacyDate(String date) {
    final tomorrow = KitchenUpcomingDates.dateKey(KitchenUpcomingDates.tomorrow());
    if (date == tomorrow) return 'tomorrow';
    return 'day_after';
  }

  static double _parseDiscount(Object? raw) {
    if (raw == null) return 0;
    if (raw is num) {
      return raw.toDouble().clamp(0.0, 100.0).toDouble();
    }
    final parsed = double.tryParse(raw.toString());
    if (parsed == null) return 0;
    return parsed.clamp(0.0, 100.0).toDouble();
  }
}

/// Tomorrow and day-after date keys in local time.
abstract final class KitchenUpcomingDates {
  static DateTime startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime tomorrow() => startOfToday().add(const Duration(days: 1));

  static DateTime dayAfterTomorrow() =>
      startOfToday().add(const Duration(days: 2));

  static String dateKey(DateTime date) {
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String formatHeading(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    return '$weekday, $month ${date.day}';
  }

  static KitchenUpcomingDayPlan? planForSlot(
    List<KitchenUpcomingDayPlan> plans,
    String slot,
  ) {
    for (final plan in plans) {
      if (plan.slot == slot) return plan;
    }
    return null;
  }

  /// Parse `YYYY-MM-DD` from the API for calendar display.
  static DateTime? parseDateKey(String? key) {
    if (key == null || key.length < 10) return null;
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }
}

class KitchenOpenWizardResult {
  const KitchenOpenWizardResult({
    required this.todayMeals,
    required this.tomorrow,
    required this.dayAfterTomorrow,
  });

  final List<String> todayMeals;
  final KitchenUpcomingDayPlan tomorrow;
  final KitchenUpcomingDayPlan dayAfterTomorrow;

  List<KitchenUpcomingDayPlan> get upcomingPlans => [
        tomorrow,
        dayAfterTomorrow,
      ];

  String get upcomingDaysJson => jsonEncode(
        upcomingPlans.map((p) => p.toJson()).toList(),
      );
}

List<KitchenUpcomingDayPlan> parseUpcomingKitchenDays(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(KitchenUpcomingDayPlan.fromJson)
      .toList();
}

String weekdayKeyForDate(DateTime date) => dishDayKeys[date.weekday - 1];

/// Near-term open/closed state from live toggle + upcoming day plans.
class KitchenNearTermDay {
  const KitchenNearTermDay({
    required this.title,
    required this.date,
    required this.open,
    this.meals = const [],
    this.preorderDiscountPercent = 0,
    this.slot,
    this.isToday = false,
  });

  final String title;
  final DateTime date;
  final bool open;
  final List<String> meals;
  final double preorderDiscountPercent;
  final String? slot;
  final bool isToday;
}

List<KitchenNearTermDay> buildNearTermDays({
  required bool kitchenOpenToday,
  required List<String> kitchenOpenMeals,
  required List<KitchenUpcomingDayPlan> upcoming,
}) {
  final today = KitchenUpcomingDates.startOfToday();
  final tomorrow = KitchenUpcomingDates.tomorrow();
  final dayAfter = KitchenUpcomingDates.dayAfterTomorrow();
  final tomorrowPlan = KitchenUpcomingDates.planForSlot(upcoming, 'tomorrow');
  final dayAfterPlan = KitchenUpcomingDates.planForSlot(upcoming, 'day_after');

  return [
    KitchenNearTermDay(
      title: 'Today',
      date: today,
      open: kitchenOpenToday,
      meals: kitchenOpenToday ? kitchenOpenMeals : const [],
      isToday: true,
    ),
    KitchenNearTermDay(
      title: 'Tomorrow',
      date: tomorrow,
      open: tomorrowPlan?.open ?? true,
      meals: tomorrowPlan?.open == true ? (tomorrowPlan?.meals ?? const []) : const [],
      preorderDiscountPercent: tomorrowPlan?.preorderDiscountPercent ?? 0,
      slot: 'tomorrow',
    ),
    KitchenNearTermDay(
      title: 'Day after tomorrow',
      date: dayAfter,
      open: dayAfterPlan?.open ?? true,
      meals: dayAfterPlan?.open == true ? (dayAfterPlan?.meals ?? const []) : const [],
      preorderDiscountPercent: dayAfterPlan?.preorderDiscountPercent ?? 0,
      slot: 'day_after',
    ),
  ];
}

String? nearTermNoteForWeekday({
  required String dayKey,
  required String todayKey,
  required bool kitchenOpenToday,
  required List<KitchenUpcomingDayPlan> upcoming,
}) {
  if (dayKey == todayKey && !kitchenOpenToday) {
    return 'Paused for today';
  }

  final tomorrowKey = weekdayKeyForDate(KitchenUpcomingDates.tomorrow());
  if (dayKey == tomorrowKey) {
    final plan = KitchenUpcomingDates.planForSlot(upcoming, 'tomorrow');
    if (plan != null && !plan.open) {
      return 'Closed tomorrow';
    }
  }

  final dayAfterKey = weekdayKeyForDate(KitchenUpcomingDates.dayAfterTomorrow());
  if (dayKey == dayAfterKey) {
    final plan = KitchenUpcomingDates.planForSlot(upcoming, 'day_after');
    if (plan != null && !plan.open) {
      return 'Closed day after';
    }
  }

  return null;
}

String? nearTermBadgeForWeekday({
  required String dayKey,
  required String todayKey,
}) {
  if (dayKey == todayKey) {
    return 'Today';
  }
  if (dayKey == weekdayKeyForDate(KitchenUpcomingDates.tomorrow())) {
    return 'Tomorrow';
  }
  if (dayKey == weekdayKeyForDate(KitchenUpcomingDates.dayAfterTomorrow())) {
    return 'Day after';
  }
  return null;
}

bool effectiveWeekdayOpen({
  required String dayKey,
  required String todayKey,
  required bool kitchenOpenToday,
  required List<KitchenUpcomingDayPlan> upcoming,
  required KitchenOpenDaysSchedule weeklySchedule,
}) {
  if (dayKey == todayKey) {
    return kitchenOpenToday;
  }

  final tomorrowKey = weekdayKeyForDate(KitchenUpcomingDates.tomorrow());
  if (dayKey == tomorrowKey) {
    final plan = KitchenUpcomingDates.planForSlot(upcoming, 'tomorrow');
    if (plan != null) {
      return plan.open;
    }
  }

  final dayAfterKey = weekdayKeyForDate(KitchenUpcomingDates.dayAfterTomorrow());
  if (dayKey == dayAfterKey) {
    final plan = KitchenUpcomingDates.planForSlot(upcoming, 'day_after');
    if (plan != null) {
      return plan.open;
    }
  }

  return weeklySchedule.isOpen(dayKey);
}

int effectiveWeekdayOpenCount({
  required String todayKey,
  required bool kitchenOpenToday,
  required List<KitchenUpcomingDayPlan> upcoming,
  required KitchenOpenDaysSchedule weeklySchedule,
}) {
  return dishDayKeys
      .where(
        (day) => effectiveWeekdayOpen(
          dayKey: day,
          todayKey: todayKey,
          kitchenOpenToday: kitchenOpenToday,
          upcoming: upcoming,
          weeklySchedule: weeklySchedule,
        ),
      )
      .length;
}
