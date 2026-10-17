import 'package:flutter/material.dart';

import 'kitchen_open_meal.dart';

/// Meal window from admin super categories (Breakfast, Lunch, etc.).
class SellerSuperCategory {
  const SellerSuperCategory({
    required this.id,
    required this.name,
    required this.timeRange,
    this.slug,
  });

  final int id;
  final String name;
  final String timeRange;
  final String? slug;

  factory SellerSuperCategory.fromJson(Map<String, dynamic> json) {
    return SellerSuperCategory(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      timeRange: json['time_range'] as String? ?? '',
      slug: json['slug'] as String?,
    );
  }

  /// Matches admin slug/name to kitchen meal keys for icons.
  String get mealKey {
    final raw = (slug ?? name).toLowerCase().trim();
    if (kitchenOpenMealKeys.contains(raw)) return raw;
    for (final key in kitchenOpenMealKeys) {
      if (raw.contains(key)) return key;
    }
    return raw;
  }

  IconData get icon =>
      kitchenOpenMealIcons[mealKey] ?? Icons.restaurant_outlined;
}
