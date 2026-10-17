import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/kitchen_open_meal.dart';
import '../models/kitchen_upcoming_day.dart';
import '../theme/app_colors.dart';

/// Schedule one future day: open/closed, meals, and pre-order discount %.
Future<KitchenUpcomingDayPlan?> showKitchenUpcomingDayDialog(
  BuildContext context, {
  required String title,
  required String slot,
  required DateTime date,
  KitchenUpcomingDayPlan? initial,
}) {
  return showDialog<KitchenUpcomingDayPlan>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _KitchenUpcomingDayDialog(
      title: title,
      slot: slot,
      date: date,
      initial: initial,
    ),
  );
}

class _KitchenUpcomingDayDialog extends StatefulWidget {
  const _KitchenUpcomingDayDialog({
    required this.title,
    required this.slot,
    required this.date,
    this.initial,
  });

  final String title;
  final String slot;
  final DateTime date;
  final KitchenUpcomingDayPlan? initial;

  @override
  State<_KitchenUpcomingDayDialog> createState() =>
      _KitchenUpcomingDayDialogState();
}

class _KitchenUpcomingDayDialogState extends State<_KitchenUpcomingDayDialog> {
  late bool _open;
  late Set<String> _selected;
  late TextEditingController _discountController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _open = initial?.open ?? true;
    _selected = Set<String>.from(
      (initial?.meals ?? const ['lunch'])
          .where(kitchenOpenMealKeys.contains),
    );
    if (_selected.isEmpty && _open) {
      _selected = {'lunch'};
    }
    _discountController = TextEditingController(
      text: initial != null && initial.open
          ? _formatDiscount(initial.preorderDiscountPercent)
          : '',
    );
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  String _formatDiscount(double value) {
    if (value <= 0) return '';
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  void _toggleMeal(String key, bool? checked) {
    setState(() {
      if (checked == true) {
        _selected.add(key);
      } else {
        _selected.remove(key);
      }
    });
  }

  void _selectAllMeals() {
    setState(() => _selected = Set<String>.from(kitchenOpenMealKeys));
  }

  void _clearMeals() {
    setState(() => _selected = {});
  }

  void _onContinue() {
    if (_open && _selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Select at least one meal, or turn the kitchen off for this day.',
            style: GoogleFonts.exo2(),
          ),
        ),
      );
      return;
    }

    double discount = 0;
    if (_open) {
      final raw = _discountController.text.trim();
      if (raw.isNotEmpty) {
        discount = double.tryParse(raw) ?? -1;
        if (discount < 0 || discount > 100) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Pre-order discount must be between 0 and 100.',
                style: GoogleFonts.exo2(),
              ),
            ),
          );
          return;
        }
      }
    }

    final meals = _selected.toList()
      ..sort(
        (a, b) => kitchenOpenMealKeys
            .indexOf(a)
            .compareTo(kitchenOpenMealKeys.indexOf(b)),
      );

    Navigator.pop(
      context,
      KitchenUpcomingDayPlan(
        slot: widget.slot,
        date: KitchenUpcomingDates.dateKey(widget.date),
        label: widget.title,
        open: _open,
        meals: _open ? meals : const [],
        preorderDiscountPercent: _open ? discount : 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allMealsSelected = _selected.length == kitchenOpenMealKeys.length;
    final dateHeading = KitchenUpcomingDates.formatHeading(widget.date);

    return AlertDialog(
      backgroundColor: AppColors.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w800,
              color: AppColors.deepGreen,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dateHeading,
            style: GoogleFonts.exo2(
              fontSize: 13,
              color: AppColors.deepGreen.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Kitchen open this day',
                style: GoogleFonts.exo2(
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepGreen,
                ),
              ),
              value: _open,
              activeTrackColor: AppColors.kitchenOpen.withValues(alpha: 0.45),
              activeThumbColor: AppColors.kitchenOpen,
              onChanged: (v) => setState(() => _open = v),
            ),
            if (_open) ...[
              Text(
                'Which meals will you serve?',
                style: GoogleFonts.exo2(
                  fontSize: 14,
                  color: AppColors.deepGreen.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: allMealsSelected ? _clearMeals : _selectAllMeals,
                  child: Text(
                    allMealsSelected ? 'Clear meals' : 'All meals',
                    style: GoogleFonts.exo2(
                      fontWeight: FontWeight.w700,
                      color: AppColors.kitchenOpen,
                    ),
                  ),
                ),
              ),
              ...kitchenOpenMealKeys.map(_mealOption),
              const SizedBox(height: 12),
              Text(
                'Pre-order discount',
                style: GoogleFonts.exo2(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.deepGreen,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'If a customer pre-orders for this day, how much discount (%) will they get?',
                style: GoogleFonts.exo2(
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.deepGreen.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _discountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d{0,2})?')),
                ],
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'e.g. 10',
                  suffixText: '%',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ] else
              Text(
                'Your kitchen will stay closed on this day.',
                style: GoogleFonts.exo2(
                  fontSize: 14,
                  color: AppColors.deepGreen.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.exo2(color: AppColors.deepGreen),
          ),
        ),
        FilledButton(
          onPressed: _onContinue,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.kitchenOpen,
          ),
          child: Text(
            'Continue',
            style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _mealOption(String key) {
    final checked = _selected.contains(key);
    final icon = kitchenOpenMealIcons[key] ?? Icons.restaurant_outlined;
    final label = kitchenOpenMealLabels[key] ?? key;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: checked
            ? AppColors.kitchenOpen.withValues(alpha: 0.12)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _toggleMeal(key, !checked),
          borderRadius: BorderRadius.circular(12),
          child: CheckboxListTile(
            value: checked,
            onChanged: (v) => _toggleMeal(key, v),
            activeColor: AppColors.kitchenOpen,
            controlAffinity: ListTileControlAffinity.leading,
            title: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: checked ? AppColors.kitchenOpen : AppColors.deepGreen,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: GoogleFonts.exo2(
                    fontWeight: checked ? FontWeight.w800 : FontWeight.w600,
                    color: AppColors.deepGreen,
                  ),
                ),
              ],
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ),
    );
  }
}
