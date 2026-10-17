import 'dart:convert';

/// Weekly meal-slot availability for a dish (matches Optica2 JSON shape).
class DishAvailabilitySchedule {
  DishAvailabilitySchedule._(this._byMeal);

  factory DishAvailabilitySchedule.defaults({bool enabled = true}) {
    final byMeal = <String, Map<String, bool>>{};
    for (final meal in dishMealKeys) {
      byMeal[meal] = {
        for (final day in dishDayKeys) day: enabled,
      };
    }
    return DishAvailabilitySchedule._(byMeal);
  }

  factory DishAvailabilitySchedule.fromApi(Object? raw) {
    final schedule = DishAvailabilitySchedule.defaults();
    if (raw is! Map) return schedule;

    for (final meal in dishMealKeys) {
      final days = raw[meal];
      if (days is! Map) continue;
      for (final day in dishDayKeys) {
        if (days.containsKey(day)) {
          schedule._byMeal[meal]![day] = days[day] == true;
        }
      }
    }
    return schedule;
  }

  final Map<String, Map<String, bool>> _byMeal;

  bool slot(String meal, String day) =>
      _byMeal[meal]?[day] ?? true;

  void setSlot(String meal, String day, bool value) {
    _byMeal.putIfAbsent(meal, () => {for (final d in dishDayKeys) d: true});
    _byMeal[meal]![day] = value;
  }

  /// Master day toggle: true if any meal is on for that day.
  bool isDayAvailable(String day) {
    for (final meal in dishMealKeys) {
      if (slot(meal, day)) return true;
    }
    return false;
  }

  void setDayAvailable(String day, bool available) {
    for (final meal in dishMealKeys) {
      setSlot(meal, day, available);
    }
  }

  bool get hasAnySlotEnabled {
    for (final meal in dishMealKeys) {
      for (final day in dishDayKeys) {
        if (slot(meal, day)) return true;
      }
    }
    return false;
  }

  Map<String, dynamic> toApiJson() => {
        for (final meal in dishMealKeys)
          meal: Map<String, bool>.from(_byMeal[meal] ?? {}),
      };

  String toApiJsonString() => jsonEncode(toApiJson());
}

const dishDayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

const dishMealKeys = ['breakfast', 'lunch', 'evening', 'dinner'];

const dishDayLabels = {
  'mon': 'Monday',
  'tue': 'Tuesday',
  'wed': 'Wednesday',
  'thu': 'Thursday',
  'fri': 'Friday',
  'sat': 'Saturday',
  'sun': 'Sunday',
};

const dishMealLabels = {
  'breakfast': 'breakfast',
  'lunch': 'lunch',
  'evening': 'evening',
  'dinner': 'dinner',
};

/// Grid order matching the reference UI (2×2 per day card).
const dishMealGridOrder = [
  'dinner',
  'evening',
  'lunch',
  'breakfast',
];
