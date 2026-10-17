import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/seller_dish.dart';
import '../../seller_auth_prefs.dart';
import '../../seller_session_prefs.dart';
import '../../services/optica2_api.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_system_ui.dart';
import '../../widgets/app_toast.dart';
import '../add_dish_screen.dart';

class SellerMenuTab extends StatefulWidget {
  const SellerMenuTab({super.key});

  @override
  State<SellerMenuTab> createState() => SellerMenuTabState();
}

class SellerMenuTabState extends State<SellerMenuTab> {
  /// Reload dishes (e.g. after adding from Kitchen tab).
  void reload() => _loadDishes();
  final _api = Optica2Api();
  bool _loading = true;
  List<SellerDish> _dishes = [];
  final Set<int> _busyDishIds = {};

  @override
  void initState() {
    super.initState();
    _loadDishes();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<String?> _phoneE164() async {
    return FirebaseAuth.instance.currentUser?.phoneNumber ??
        await SellerAuthPrefs.phoneE164();
  }

  Future<void> _loadDishes() async {
    final phone = await _phoneE164();
    if (phone == null || phone.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final dishes = await _api.fetchDishes(
        phoneE164: phone,
        sellerId: sellerId,
      );
      if (!mounted) return;
      setState(() {
        _dishes = dishes;
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

  Future<void> _openAddDish({SellerDish? editDish, int initialStep = 0}) async {
    final phone = await _phoneE164();
    if (phone == null || phone.isEmpty) return;
    if (!mounted) return;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddDishScreen(
          phoneE164: phone,
          editDish: editDish,
          initialStep: initialStep,
        ),
      ),
    );

    if (!mounted) return;
    if (saved == true) {
      await _loadDishes();
    }
  }

  void _setDishBusy(int dishId, bool busy) {
    setState(() {
      if (busy) {
        _busyDishIds.add(dishId);
      } else {
        _busyDishIds.remove(dishId);
      }
    });
  }

  void _replaceDish(SellerDish updated) {
    setState(() {
      final index = _dishes.indexWhere((d) => d.id == updated.id);
      if (index >= 0) {
        _dishes = List<SellerDish>.from(_dishes)..[index] = updated;
      }
    });
  }

  Future<void> _toggleAvailability(SellerDish dish, bool available) async {
    if (_busyDishIds.contains(dish.id)) return;

    final phone = await _phoneE164();
    if (phone == null) return;

    final previous = dish;
    _replaceDish(dish.copyWith(isAvailable: available));
    _setDishBusy(dish.id, true);

    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final updated = await _api.setDishAvailability(
        phoneE164: phone,
        dishId: dish.id,
        isAvailable: available,
        sellerId: sellerId,
      );
      if (!mounted) return;
      _replaceDish(updated);
      AppToast.success(
        context,
        available ? 'Dish is now available.' : 'Dish is now unavailable.',
      );
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      _replaceDish(previous);
      AppToast.danger(context, e.message);
    } catch (_) {
      if (!mounted) return;
      _replaceDish(previous);
      AppToast.danger(context, 'Could not update availability.');
    } finally {
      if (mounted) _setDishBusy(dish.id, false);
    }
  }

  Future<void> _confirmDelete(SellerDish dish) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete dish?',
          style: GoogleFonts.exo2(fontWeight: FontWeight.w800),
        ),
        content: Text(
          '“${dish.name}” will be removed from your menu. This cannot be undone.',
          style: GoogleFonts.exo2(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.exo2()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.terracotta,
            ),
            child: Text('Delete', style: GoogleFonts.exo2()),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final phone = await _phoneE164();
    if (phone == null) return;

    _setDishBusy(dish.id, true);
    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      await _api.deleteDish(
        phoneE164: phone,
        dishId: dish.id,
        sellerId: sellerId,
      );
      if (!mounted) return;
      setState(() => _dishes.removeWhere((d) => d.id == dish.id));
      AppToast.success(context, 'Dish deleted.');
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      AppToast.danger(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.danger(context, 'Could not delete dish.');
    } finally {
      if (mounted) _setDishBusy(dish.id, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.brandPurple,
      onRefresh: _loadDishes,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                AppSystemUi.topInset(context, 8),
                24,
                16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Menu',
                      style: GoogleFonts.exo2(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.deepGreen,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openAddDish(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: Text(
                      'Add dish',
                      style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.brandPurple),
              ),
            )
          else if (_dishes.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.menu_book_rounded,
                        size: 56,
                        color: AppColors.terracotta.withValues(alpha: 0.65),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Build your menu',
                        style: GoogleFonts.exo2(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add photos, prices, and veg / non-veg for each dish.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.exo2(
                          fontSize: 14,
                          height: 1.45,
                          color: AppColors.deepGreen.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => _openAddDish(),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brandPurple,
                        ),
                        child: Text(
                          'Add your first dish',
                          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final dish = _dishes[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _DishCard(
                        dish: dish,
                        busy: _busyDishIds.contains(dish.id),
                        onEdit: () => _openAddDish(editDish: dish),
                        onAvailability: () =>
                            _openAddDish(editDish: dish, initialStep: 1),
                        onDelete: () => _confirmDelete(dish),
                        onAvailabilityChanged: (available) =>
                            _toggleAvailability(dish, available),
                      ),
                    );
                  },
                  childCount: _dishes.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 130)),
        ],
      ),
    );
  }
}

class _DishCard extends StatelessWidget {
  const _DishCard({
    required this.dish,
    required this.busy,
    required this.onEdit,
    required this.onAvailability,
    required this.onDelete,
    required this.onAvailabilityChanged,
  });

  final SellerDish dish;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onAvailability;
  final VoidCallback onDelete;
  final ValueChanged<bool> onAvailabilityChanged;

  @override
  Widget build(BuildContext context) {
    final imageUrl = dish.imageUrls.isNotEmpty ? dish.imageUrls.first : null;
    final available = dish.isAvailable;
    final accent = available ? AppColors.sage : AppColors.deepGreen;

    return Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: available
                  ? AppColors.sage.withValues(alpha: 0.35)
                  : AppColors.deepGreen.withValues(alpha: 0.12),
              width: available ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: available ? 0.12 : 0.05),
                blurRadius: 14,
                offset: const Offset(0, 5),
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
                  width: 5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: available
                            ? [
                                AppColors.sage,
                                AppColors.brandPurple.withValues(alpha: 0.7),
                              ]
                            : [
                                AppColors.deepGreen.withValues(alpha: 0.25),
                                AppColors.deepGreen.withValues(alpha: 0.1),
                              ],
                      ),
                    ),
                  ),
                ),
                if (!available)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: 0.42),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 72,
                              height: 72,
                              child: imageUrl != null
                                  ? Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          _imagePlaceholder(),
                                    )
                                  : _imagePlaceholder(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 52),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        dish.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.exo2(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          height: 1.15,
                                          color: AppColors.deepGreen,
                                        ),
                                      ),
                                      Text(
                                        dish.description?.trim().isNotEmpty ==
                                                true
                                            ? dish.description!
                                            : 'No description yet',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.exo2(
                                          fontSize: 12,
                                          height: 1.2,
                                          color: AppColors.deepGreen
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        dish.priceLabel,
                                        style: GoogleFonts.exo2(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          height: 1.2,
                                          color: AppColors.brandPurple,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _DietBadge(isVeg: dish.isVeg),
                                      const SizedBox(height: 4),
                                      _DeleteIconButton(
                                        onPressed: busy ? null : onDelete,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _AvailabilityToggle(
                        available: available,
                        busy: busy,
                        onChanged: onAvailabilityChanged,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              label: 'Availability',
                              icon: Icons.schedule_rounded,
                              color: AppColors.sage,
                              onPressed: busy ? null : onAvailability,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ActionButton(
                              label: 'Edit',
                              icon: Icons.edit_rounded,
                              color: AppColors.brandPurple,
                              onPressed: busy ? null : onEdit,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (busy)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x66FFFFFF),
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.brandPurple,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _imagePlaceholder() {
    return ColoredBox(
      color: AppColors.cream,
      child: Icon(
        Icons.restaurant_rounded,
        color: AppColors.terracotta.withValues(alpha: 0.5),
      ),
    );
  }
}

class _AvailabilityToggle extends StatelessWidget {
  const _AvailabilityToggle({
    required this.available,
    required this.busy,
    required this.onChanged,
  });

  final bool available;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.brandPurple.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AvailChip(
              label: 'Available',
              icon: Icons.check_circle_outline_rounded,
              selected: available,
              activeColor: AppColors.sage,
              onTap: busy || available ? null : () => onChanged(true),
            ),
          ),
          Expanded(
            child: _AvailChip(
              label: 'Unavailable',
              icon: Icons.pause_circle_outline_rounded,
              selected: !available,
              activeColor: AppColors.deepGreen,
              onTap: busy || !available ? null : () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailChip extends StatelessWidget {
  const _AvailChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color activeColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? activeColor.withValues(alpha: 0.18) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? activeColor
                    : AppColors.deepGreen.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.exo2(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected
                        ? activeColor
                        : AppColors.deepGreen.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.45)),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: GoogleFonts.exo2(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

class _DeleteIconButton extends StatelessWidget {
  const _DeleteIconButton({required this.onPressed});

  final VoidCallback? onPressed;

  static const _danger = AppColors.kitchenOff;
  static const _dangerDeep = AppColors.kitchenOffDeep;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Material(
      color: enabled
          ? _danger.withValues(alpha: 0.12)
          : _danger.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        splashColor: _danger.withValues(alpha: 0.18),
        highlightColor: _danger.withValues(alpha: 0.1),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: enabled
                  ? _danger.withValues(alpha: 0.55)
                  : _danger.withValues(alpha: 0.2),
              width: 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              Icons.delete_rounded,
              size: 18,
              color: enabled ? _dangerDeep : _danger.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}

class _DietBadge extends StatelessWidget {
  const _DietBadge({required this.isVeg});

  final bool isVeg;

  @override
  Widget build(BuildContext context) {
    final color = isVeg ? AppColors.sage : AppColors.terracotta;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        isVeg ? 'Veg' : 'Non-veg',
        style: GoogleFonts.exo2(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
