import 'package:flutter/material.dart';

/// Meal period when the kitchen is opened for orders.
const kitchenOpenMealKeys = ['breakfast', 'lunch', 'dinner', 'evening'];

const kitchenOpenMealLabels = {
  'breakfast': 'Breakfast',
  'lunch': 'Lunch',
  'dinner': 'Dinner',
  'evening': 'Evening',
};

const kitchenOpenMealIcons = {
  'breakfast': Icons.free_breakfast_outlined,
  'lunch': Icons.lunch_dining_outlined,
  'dinner': Icons.dinner_dining_outlined,
  'evening': Icons.nightlight_round_outlined,
};

String kitchenOpenMealLabel(String? key) {
  if (key == null || key.isEmpty) return '';
  return kitchenOpenMealLabels[key] ?? key;
}

/// Human-readable list, e.g. "Breakfast, Lunch & Dinner".
String kitchenOpenMealsLabel(List<String> meals) {
  final labels = meals
      .map(kitchenOpenMealLabel)
      .where((l) => l.isNotEmpty)
      .toList();
  if (labels.isEmpty) return '';
  if (labels.length == 1) return labels.first;
  if (labels.length == 2) return '${labels[0]} & ${labels[1]}';
  return '${labels.sublist(0, labels.length - 1).join(', ')} & ${labels.last}';
}

List<String> parseKitchenOpenMeals(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<String>()
      .where((k) => kitchenOpenMealKeys.contains(k))
      .toList();
}
