import 'dart:convert';

import 'dish_availability.dart';

/// Which days of the week the kitchen accepts orders (restaurant `open_days`).
class KitchenOpenDaysSchedule {
  KitchenOpenDaysSchedule._(this._days);

  factory KitchenOpenDaysSchedule.defaults({bool open = true}) {
    return KitchenOpenDaysSchedule._({
      for (final day in dishDayKeys) day: open,
    });
  }

  factory KitchenOpenDaysSchedule.fromApi(Object? raw) {
    final schedule = KitchenOpenDaysSchedule.defaults();
    if (raw is! Map) return schedule;

    for (final day in dishDayKeys) {
      if (raw.containsKey(day)) {
        schedule._days[day] = raw[day] == true;
      }
    }
    return schedule;
  }

  final Map<String, bool> _days;

  bool isOpen(String day) => _days[day] ?? true;

  void setDay(String day, bool open) => _days[day] = open;

  void setAll(bool open) {
    for (final day in dishDayKeys) {
      _days[day] = open;
    }
  }

  int get openCount => _days.values.where((v) => v).length;

  Map<String, dynamic> toApiJson() => Map<String, bool>.from(_days);

  String toApiJsonString() => jsonEncode(toApiJson());
}

String kitchenTodayDayKey() => dishDayKeys[DateTime.now().weekday - 1];
