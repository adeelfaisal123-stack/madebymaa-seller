import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/kitchen_open_meal.dart';
import '../theme/app_colors.dart';

/// Asks which meal periods the kitchen is opening for. Returns selected keys or null if cancelled.
Future<List<String>?> showKitchenOpenMealDialog(
  BuildContext context, {
  List<String> initialSelection = const ['lunch'],
}) {
  return showDialog<List<String>>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _KitchenOpenMealDialog(
      initialSelection: Set<String>.from(initialSelection),
    ),
  );
}

class _KitchenOpenMealDialog extends StatefulWidget {
  const _KitchenOpenMealDialog({required this.initialSelection});

  final Set<String> initialSelection;

  @override
  State<_KitchenOpenMealDialog> createState() => _KitchenOpenMealDialogState();
}

class _KitchenOpenMealDialogState extends State<_KitchenOpenMealDialog> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(
      widget.initialSelection.where(kitchenOpenMealKeys.contains),
    );
    if (_selected.isEmpty) {
      _selected = {'lunch'};
    }
  }

  void _toggle(String key, bool? checked) {
    setState(() {
      if (checked == true) {
        _selected.add(key);
      } else {
        _selected.remove(key);
      }
    });
  }

  void _selectAll() {
    setState(() => _selected = Set<String>.from(kitchenOpenMealKeys));
  }

  void _clearAll() {
    setState(() => _selected = {});
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _selected.length == kitchenOpenMealKeys.length;

    return AlertDialog(
      backgroundColor: AppColors.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Open kitchen for',
        style: GoogleFonts.exo2(
          fontWeight: FontWeight.w800,
          color: AppColors.deepGreen,
          fontSize: 20,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Select one or more meals you are taking orders for.',
            style: GoogleFonts.exo2(
              fontSize: 14,
              height: 1.4,
              color: AppColors.deepGreen.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: allSelected ? _clearAll : _selectAll,
              child: Text(
                allSelected ? 'Clear all' : 'Select all',
                style: GoogleFonts.exo2(
                  fontWeight: FontWeight.w700,
                  color: AppColors.kitchenOpen,
                ),
              ),
            ),
          ),
          ...kitchenOpenMealKeys.map(_mealOption),
        ],
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
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, _selected.toList()..sort(
                    (a, b) => kitchenOpenMealKeys
                        .indexOf(a)
                        .compareTo(kitchenOpenMealKeys.indexOf(b)),
                  )),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.kitchenOpen,
          ),
          child: Text(
            'Open kitchen',
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
          onTap: () => _toggle(key, !checked),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: checked
                    ? AppColors.kitchenOpen
                    : AppColors.deepGreen.withValues(alpha: 0.12),
                width: checked ? 2 : 1,
              ),
            ),
            child: CheckboxListTile(
              value: checked,
              onChanged: (v) => _toggle(key, v),
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
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
      ),
    );
  }
}
