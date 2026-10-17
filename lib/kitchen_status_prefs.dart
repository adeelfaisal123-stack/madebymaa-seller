import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/kitchen_upcoming_day.dart';

/// Persists whether the seller kitchen is accepting orders.
abstract final class KitchenStatusPrefs {
  static const openKey = 'seller_kitchen_open';
  static const mealsKey = 'seller_kitchen_open_meals';
  static const upcomingKey = 'seller_kitchen_upcoming_days';

  static Future<bool> isOpen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(openKey) ?? true;
  }

  static Future<void> setOpen(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(openKey, value);
  }

  static Future<void> cacheDetails({
    required bool open,
    List<String> meals = const [],
    List<KitchenUpcomingDayPlan> upcoming = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(openKey, open);
    await prefs.setString(mealsKey, jsonEncode(meals));
    await prefs.setString(
      upcomingKey,
      jsonEncode(upcoming.map((plan) => plan.toJson()).toList()),
    );
  }

  static Future<
      ({
        bool open,
        List<String> meals,
        List<KitchenUpcomingDayPlan> upcoming,
      })> loadCachedDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final open = prefs.getBool(openKey) ?? true;
    final mealsRaw = prefs.getString(mealsKey);
    final upcomingRaw = prefs.getString(upcomingKey);

    List<String> meals = const [];
    if (mealsRaw != null && mealsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(mealsRaw);
        if (decoded is List) {
          meals = decoded.whereType<String>().toList();
        }
      } catch (_) {}
    }

    return (
      open: open,
      meals: meals,
      upcoming: () {
        if (upcomingRaw == null || upcomingRaw.isEmpty) {
          return const <KitchenUpcomingDayPlan>[];
        }
        try {
          return parseUpcomingKitchenDays(jsonDecode(upcomingRaw));
        } catch (_) {
          return const <KitchenUpcomingDayPlan>[];
        }
      }(),
    );
  }
}
