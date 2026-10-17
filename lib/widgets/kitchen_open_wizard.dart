import 'package:flutter/material.dart';

import '../models/kitchen_upcoming_day.dart';
import 'kitchen_open_meal_dialog.dart';
import 'kitchen_upcoming_day_dialog.dart';

/// Today’s meals, then tomorrow and day-after schedule, before opening the kitchen.
Future<KitchenOpenWizardResult?> runKitchenOpenWizard(
  BuildContext context, {
  List<String> initialTodayMeals = const ['lunch'],
  List<KitchenUpcomingDayPlan> initialUpcoming = const [],
}) async {
  final todayMeals = await showKitchenOpenMealDialog(
    context,
    initialSelection: initialTodayMeals,
  );
  if (todayMeals == null || todayMeals.isEmpty) return null;

  if (!context.mounted) return null;

  final tomorrowDate = KitchenUpcomingDates.tomorrow();
  final dayAfterDate = KitchenUpcomingDates.dayAfterTomorrow();
  final tomorrowKey = KitchenUpcomingDates.dateKey(tomorrowDate);
  final dayAfterKey = KitchenUpcomingDates.dateKey(dayAfterDate);

  final tomorrowInitial = KitchenUpcomingDates.planForSlot(
        initialUpcoming,
        'tomorrow',
      ) ??
      KitchenUpcomingDayPlan(
        slot: 'tomorrow',
        date: tomorrowKey,
        label: 'Tomorrow',
        open: true,
        meals: todayMeals,
      );

  final tomorrow = await showKitchenUpcomingDayDialog(
    context,
    title: 'Tomorrow',
    slot: 'tomorrow',
    date:
        KitchenUpcomingDates.parseDateKey(tomorrowInitial.date) ?? tomorrowDate,
    initial: tomorrowInitial,
  );
  if (tomorrow == null) return null;

  if (!context.mounted) return null;

  final dayAfterInitial = KitchenUpcomingDates.planForSlot(
        initialUpcoming,
        'day_after',
      ) ??
      KitchenUpcomingDayPlan(
        slot: 'day_after',
        date: dayAfterKey,
        label: 'Day after tomorrow',
        open: true,
        meals: todayMeals,
      );

  final dayAfter = await showKitchenUpcomingDayDialog(
    context,
    title: 'Day after tomorrow',
    slot: 'day_after',
    date: KitchenUpcomingDates.parseDateKey(dayAfterInitial.date) ??
        dayAfterDate,
    initial: dayAfterInitial,
  );
  if (dayAfter == null) return null;

  return KitchenOpenWizardResult(
    todayMeals: todayMeals,
    tomorrow: tomorrow,
    dayAfterTomorrow: dayAfter,
  );
}
