import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../kitchen_status_prefs.dart';
import '../models/dish_availability.dart';
import '../models/kitchen_open_days.dart';
import '../models/kitchen_upcoming_day.dart';
import '../seller_session_prefs.dart';
import '../services/optica2_api.dart';
import '../theme/app_colors.dart';
import '../widgets/app_toast.dart';
import '../widgets/kitchen_open_wizard.dart';

/// Weekly kitchen open/close days + live kitchen on/off toggle.
class KitchenScheduleScreen extends StatefulWidget {
  const KitchenScheduleScreen({super.key, required this.phoneE164});

  final String phoneE164;

  @override
  State<KitchenScheduleScreen> createState() => _KitchenScheduleScreenState();
}

class _KitchenScheduleScreenState extends State<KitchenScheduleScreen> {
  final _api = Optica2Api();
  bool _loading = true;
  bool _saving = false;
  bool _kitchenOpen = true;
  List<String> _kitchenOpenMeals = const [];
  List<KitchenUpcomingDayPlan> _upcomingKitchenDays = const [];
  late KitchenOpenDaysSchedule _schedule;
  final String _todayKey = kitchenTodayDayKey();

  @override
  void initState() {
    super.initState();
    _schedule = KitchenOpenDaysSchedule.defaults();
    _load();
  }

  Future<void> _applyStatusResult(KitchenStatusResult result) async {
    await KitchenStatusPrefs.cacheDetails(
      open: result.kitchenOpen,
      meals: result.kitchenOpenMeals,
      upcoming: result.upcomingKitchenDays,
    );
    if (!mounted) return;
    setState(() {
      _kitchenOpen = result.kitchenOpen;
      _kitchenOpenMeals = result.kitchenOpenMeals;
      _upcomingKitchenDays = result.upcomingKitchenDays;
    });
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final cached = await KitchenStatusPrefs.loadCachedDetails();
    if (mounted) {
      setState(() {
        _kitchenOpen = cached.open;
        _kitchenOpenMeals = cached.meals;
        _upcomingKitchenDays = cached.upcoming;
      });
    }

    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final result = await _api.fetchKitchenStatus(
        phoneE164: widget.phoneE164,
        sellerId: sellerId,
      );
      if (!mounted) return;
      await KitchenStatusPrefs.cacheDetails(
        open: result.kitchenOpen,
        meals: result.kitchenOpenMeals,
        upcoming: result.upcomingKitchenDays,
      );
      setState(() {
        _kitchenOpen = result.kitchenOpen;
        _kitchenOpenMeals = result.kitchenOpenMeals;
        _upcomingKitchenDays = result.upcomingKitchenDays;
        _schedule = result.openDays.isEmpty
            ? KitchenOpenDaysSchedule.defaults()
            : KitchenOpenDaysSchedule.fromApi(result.openDays);
        _loading = false;
      });
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.danger(context, e.message);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSchedule() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      await _api.updateKitchenOpenDays(
        phoneE164: widget.phoneE164,
        openDaysJson: _schedule.toApiJsonString(),
        sellerId: sellerId,
      );
      if (!mounted) return;
      AppToast.success(context, 'Weekly hours saved.');
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      AppToast.danger(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.danger(context, 'Could not save schedule.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setKitchenOpen(bool open) async {
    if (_saving) return;

    KitchenOpenWizardResult? wizard;
    if (open) {
      if (!mounted) return;
      wizard = await runKitchenOpenWizard(
        context,
        initialTodayMeals: _kitchenOpenMeals.isNotEmpty
            ? _kitchenOpenMeals
            : const ['lunch'],
        initialUpcoming: _upcomingKitchenDays,
      );
      if (wizard == null || !mounted) return;
    }

    final previous = _kitchenOpen;
    setState(() {
      _kitchenOpen = open;
      _saving = true;
    });

    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final result = await _api.updateKitchenStatus(
        phoneE164: widget.phoneE164,
        kitchenOpen: open,
        kitchenOpenMeals: open ? wizard!.todayMeals : null,
        upcomingDaysJson: open ? wizard!.upcomingDaysJson : null,
        sellerId: sellerId,
      );
      await _applyStatusResult(result);
      if (!mounted) return;
      AppToast.success(context, result.message);
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      setState(() => _kitchenOpen = previous);
      AppToast.danger(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _kitchenOpen = previous);
      AppToast.danger(context, 'Could not update kitchen status.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleDay(String day, bool open) async {
    setState(() => _schedule.setDay(day, open));
    await _saveSchedule();
  }

  bool _effectiveWeekdayOpen(String dayKey) {
    return effectiveWeekdayOpen(
      dayKey: dayKey,
      todayKey: _todayKey,
      kitchenOpenToday: _kitchenOpen,
      upcoming: _upcomingKitchenDays,
      weeklySchedule: _schedule,
    );
  }

  Future<void> _setUpcomingSlotOpen(String slot, bool open) async {
    final existing = KitchenUpcomingDates.planForSlot(_upcomingKitchenDays, slot);
    final date = slot == 'tomorrow'
        ? KitchenUpcomingDates.dateKey(KitchenUpcomingDates.tomorrow())
        : KitchenUpcomingDates.dateKey(KitchenUpcomingDates.dayAfterTomorrow());
    final label = slot == 'tomorrow' ? 'Tomorrow' : 'Day after tomorrow';

    final updated = open
        ? KitchenUpcomingDayPlan(
            slot: slot,
            date: date,
            label: label,
            open: true,
            meals: existing != null && existing.meals.isNotEmpty
                ? existing.meals
                : (_kitchenOpenMeals.isNotEmpty
                    ? _kitchenOpenMeals
                    : const ['lunch']),
            preorderDiscountPercent: existing?.preorderDiscountPercent ?? 0,
          )
        : KitchenUpcomingDayPlan.closed(
            slot: slot,
            date: date,
            label: label,
          );

    final tomorrow = slot == 'tomorrow'
        ? updated
        : (KitchenUpcomingDates.planForSlot(_upcomingKitchenDays, 'tomorrow') ??
            KitchenUpcomingDayPlan(
              slot: 'tomorrow',
              date: KitchenUpcomingDates.dateKey(KitchenUpcomingDates.tomorrow()),
              label: 'Tomorrow',
              open: true,
              meals: _kitchenOpenMeals.isNotEmpty
                  ? _kitchenOpenMeals
                  : const ['lunch'],
            ));
    final dayAfter = slot == 'day_after'
        ? updated
        : (KitchenUpcomingDates.planForSlot(_upcomingKitchenDays, 'day_after') ??
            KitchenUpcomingDayPlan(
              slot: 'day_after',
              date: KitchenUpcomingDates.dateKey(
                KitchenUpcomingDates.dayAfterTomorrow(),
              ),
              label: 'Day after tomorrow',
              open: true,
              meals: _kitchenOpenMeals.isNotEmpty
                  ? _kitchenOpenMeals
                  : const ['lunch'],
            ));

    setState(() => _saving = true);
    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final plans = [tomorrow, dayAfter];
      final result = await _api.updateKitchenUpcomingDays(
        phoneE164: widget.phoneE164,
        upcomingDaysJson: jsonEncode(plans.map((p) => p.toJson()).toList()),
        sellerId: sellerId,
      );
      if (!mounted) return;
      await _applyStatusResult(result);
      if (!mounted) return;
      AppToast.success(context, result.message);
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      AppToast.danger(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.danger(context, 'Could not save upcoming schedule.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleWeekday(String dayKey, bool open) async {
    if (dayKey == _todayKey) {
      await _setKitchenOpen(open);
      return;
    }

    final tomorrowKey = weekdayKeyForDate(KitchenUpcomingDates.tomorrow());
    if (dayKey == tomorrowKey) {
      await _setUpcomingSlotOpen('tomorrow', open);
      return;
    }

    final dayAfterKey = weekdayKeyForDate(KitchenUpcomingDates.dayAfterTomorrow());
    if (dayKey == dayAfterKey) {
      await _setUpcomingSlotOpen('day_after', open);
      return;
    }

    await _toggleDay(dayKey, open);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.deepGreen),
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        title: Text(
          'Kitchen hours',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w800,
            color: AppColors.deepGreen,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brandPurple),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    children: [
                      _LiveKitchenCard(
                        isOpen: _kitchenOpen,
                        busy: _saving,
                        onChanged: _setKitchenOpen,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Weekly schedule',
                              style: GoogleFonts.exo2(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.deepGreen,
                              ),
                            ),
                          ),
                          Text(
                            '${effectiveWeekdayOpenCount(todayKey: _todayKey, kitchenOpenToday: _kitchenOpen, upcoming: _upcomingKitchenDays, weeklySchedule: _schedule)}/7 days open',
                            style: GoogleFonts.exo2(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandPurple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose which days your kitchen accepts orders.',
                        style: GoogleFonts.exo2(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.deepGreen.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: _saving
                                ? null
                                : () async {
                                    setState(() => _schedule.setAll(true));
                                    await _saveSchedule();
                                  },
                            icon: const Icon(Icons.done_all_rounded, size: 18),
                            label: Text(
                              'Open all',
                              style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _saving
                                ? null
                                : () async {
                                    setState(() => _schedule.setAll(false));
                                    await _saveSchedule();
                                  },
                            icon: const Icon(Icons.block_rounded, size: 18),
                            label: Text(
                              'Close all',
                              style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      ...dishDayKeys.map(
                        (day) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DayScheduleCard(
                            dayKey: day,
                            label: dishDayLabels[day] ?? day,
                            badge: nearTermBadgeForWeekday(
                              dayKey: day,
                              todayKey: _todayKey,
                            ),
                            isOpen: _effectiveWeekdayOpen(day),
                            statusNote: nearTermNoteForWeekday(
                              dayKey: day,
                              todayKey: _todayKey,
                              kitchenOpenToday: _kitchenOpen,
                              upcoming: _upcomingKitchenDays,
                            ),
                            busy: _saving,
                            onChanged: (open) => _toggleWeekday(day, open),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _LiveKitchenCard extends StatelessWidget {
  const _LiveKitchenCard({
    required this.isOpen,
    required this.busy,
    required this.onChanged,
  });

  final bool isOpen;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isOpen
              ? [
                  AppColors.kitchenOpen.withValues(alpha: 0.9),
                  AppColors.kitchenOpenDeep,
                ]
              : [
                  AppColors.kitchenOff.withValues(alpha: 0.85),
                  AppColors.kitchenOffDeep,
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isOpen ? AppColors.kitchenOpen : AppColors.kitchenOff)
                .withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOpen ? Icons.soup_kitchen_rounded : Icons.nightlight_round,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOpen ? 'Kitchen is live' : 'Kitchen is paused',
                      style: GoogleFonts.exo2(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      isOpen
                          ? 'Buyers can place orders right now'
                          : 'Orders are paused until you turn it on',
                      style: GoogleFonts.exo2(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Switch.adaptive(
                  value: isOpen,
                  activeThumbColor: Colors.white,
                  activeTrackColor: Colors.white.withValues(alpha: 0.45),
                  onChanged: onChanged,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'This is separate from your weekly days — use it when you need a quick break today.',
              style: GoogleFonts.exo2(
                fontSize: 11,
                height: 1.35,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayScheduleCard extends StatelessWidget {
  const _DayScheduleCard({
    required this.dayKey,
    required this.label,
    required this.isOpen,
    required this.busy,
    required this.onChanged,
    this.badge,
    this.statusNote,
  });

  final String dayKey;
  final String label;
  final bool isOpen;
  final bool busy;
  final ValueChanged<bool> onChanged;
  final String? badge;
  final String? statusNote;

  @override
  Widget build(BuildContext context) {
    final accent = isOpen ? AppColors.sage : AppColors.kitchenOff;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOpen
              ? AppColors.sage.withValues(alpha: 0.4)
              : AppColors.kitchenOff.withValues(alpha: 0.45),
          width: isOpen ? 1.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isOpen ? 0.1 : 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: ColoredBox(
                color: isOpen ? AppColors.sage : AppColors.kitchenOff,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOpen
                          ? AppColors.sage.withValues(alpha: 0.15)
                          : AppColors.kitchenOff.withValues(alpha: 0.1),
                      border: Border.all(
                        color: isOpen
                            ? AppColors.sage
                            : AppColors.kitchenOff.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Icon(
                      _dayIcon(dayKey),
                      color: isOpen
                          ? AppColors.sage
                          : AppColors.kitchenOff,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              label,
                              style: GoogleFonts.exo2(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.deepGreen,
                              ),
                            ),
                            if (badge != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.brandPurple.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  badge!,
                                  style: GoogleFonts.exo2(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.brandPurple,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isOpen ? 'Accepting orders' : 'Kitchen closed',
                          style: GoogleFonts.exo2(
                            fontSize: 12,
                            fontWeight:
                                isOpen ? FontWeight.w500 : FontWeight.w700,
                            color: isOpen
                                ? AppColors.sage
                                : AppColors.kitchenOff,
                          ),
                        ),
                        if (statusNote != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            statusNote!,
                            style: GoogleFonts.exo2(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandPurple,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _DayToggle(
                    isOpen: isOpen,
                    busy: busy,
                    onChanged: onChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _dayIcon(String day) {
    return switch (day) {
      'sat' || 'sun' => Icons.weekend_rounded,
      'fri' => Icons.celebration_outlined,
      _ => Icons.calendar_today_rounded,
    };
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({
    required this.isOpen,
    required this.busy,
    required this.onChanged,
  });

  final bool isOpen;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.brandPurple.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleChip(
            label: 'Open',
            selected: isOpen,
            color: AppColors.sage,
            onTap: busy || isOpen ? null : () => onChanged(true),
          ),
          const SizedBox(height: 4),
          _ToggleChip(
            label: 'Closed',
            selected: !isOpen,
            color: AppColors.kitchenOff,
            onTap: busy || !isOpen ? null : () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.2) : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: GoogleFonts.exo2(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected
                  ? color
                  : AppColors.deepGreen.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}
