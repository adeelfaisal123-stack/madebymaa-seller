import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/seller_coupon.dart';
import '../models/seller_dish.dart';
import '../seller_session_prefs.dart';
import '../services/optica2_api.dart';
import '../theme/app_colors.dart';
import '../widgets/app_toast.dart';

/// Manage kitchen coupons (percent or flat discount, enable/disable).
class KitchenCouponsScreen extends StatefulWidget {
  const KitchenCouponsScreen({super.key, required this.phoneE164});

  final String phoneE164;

  @override
  State<KitchenCouponsScreen> createState() => _KitchenCouponsScreenState();
}

class _KitchenCouponsScreenState extends State<KitchenCouponsScreen> {
  final _api = Optica2Api();
  bool _loading = true;
  List<SellerCoupon> _coupons = [];
  final Set<int> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final coupons = await _api.fetchCoupons(
        phoneE164: widget.phoneE164,
        sellerId: sellerId,
      );
      if (!mounted) return;
      setState(() {
        _coupons = coupons;
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

  Future<void> _openCouponForm({SellerCoupon? edit}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CouponFormSheet(
        phoneE164: widget.phoneE164,
        edit: edit,
      ),
    );

    if (saved == true) await _load();
  }

  void _setBusy(int id, bool busy) {
    setState(() {
      if (busy) {
        _busyIds.add(id);
      } else {
        _busyIds.remove(id);
      }
    });
  }

  void _replaceCoupon(SellerCoupon updated) {
    setState(() {
      final i = _coupons.indexWhere((c) => c.id == updated.id);
      if (i >= 0) _coupons[i] = updated;
    });
  }

  Future<void> _toggleActive(SellerCoupon coupon, bool active) async {
    if (_busyIds.contains(coupon.id)) return;

    final previous = coupon;
    _replaceCoupon(coupon.copyWith(isActive: active));
    _setBusy(coupon.id, true);

    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final updated = await _api.setCouponActive(
        phoneE164: widget.phoneE164,
        couponId: coupon.id,
        isActive: active,
        sellerId: sellerId,
      );
      if (!mounted) return;
      _replaceCoupon(updated);
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      _replaceCoupon(previous);
      AppToast.danger(context, e.message);
    } catch (_) {
      if (!mounted) return;
      _replaceCoupon(previous);
      AppToast.danger(context, 'Could not update coupon.');
    } finally {
      if (mounted) _setBusy(coupon.id, false);
    }
  }

  Future<void> _confirmDelete(SellerCoupon coupon) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete coupon?',
          style: GoogleFonts.exo2(fontWeight: FontWeight.w800),
        ),
        content: Text(
          '“${coupon.code}” will be removed.',
          style: GoogleFonts.exo2(),
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

    _setBusy(coupon.id, true);
    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      await _api.deleteCoupon(
        phoneE164: widget.phoneE164,
        couponId: coupon.id,
        sellerId: sellerId,
      );
      if (!mounted) return;
      setState(() => _coupons.removeWhere((c) => c.id == coupon.id));
      AppToast.success(context, 'Coupon deleted.');
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      AppToast.danger(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.danger(context, 'Could not delete coupon.');
    } finally {
      if (mounted) _setBusy(coupon.id, false);
    }
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Coupons',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w800,
            color: AppColors.deepGreen,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCouponForm(),
        backgroundColor: AppColors.brandPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Add coupon',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brandPurple),
            )
          : _coupons.isEmpty
              ? _EmptyCoupons(onAdd: () => _openCouponForm())
              : RefreshIndicator(
                  color: AppColors.brandPurple,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                    itemCount: _coupons.length,
                    itemBuilder: (context, index) {
                      final coupon = _coupons[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CouponCard(
                          coupon: coupon,
                          busy: _busyIds.contains(coupon.id),
                          onEdit: () => _openCouponForm(edit: coupon),
                          onDelete: () => _confirmDelete(coupon),
                          onActiveChanged: (v) => _toggleActive(coupon, v),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _EmptyCoupons extends StatelessWidget {
  const _EmptyCoupons({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.confirmation_number_outlined,
              size: 56,
              color: AppColors.brandPurple.withValues(alpha: 0.65),
            ),
            const SizedBox(height: 16),
            Text(
              'No coupons yet',
              style: GoogleFonts.exo2(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.deepGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create codes like SAVE20 or FLAT50 for your customers.',
              textAlign: TextAlign.center,
              style: GoogleFonts.exo2(
                fontSize: 14,
                height: 1.45,
                color: AppColors.deepGreen.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPurple,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                'Create coupon',
                style: GoogleFonts.exo2(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({
    required this.coupon,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    required this.onActiveChanged,
  });

  final SellerCoupon coupon;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    final active = coupon.isActive;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active
                  ? AppColors.brandPurple.withValues(alpha: 0.4)
                  : AppColors.deepGreen.withValues(alpha: 0.1),
              width: active ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (active ? AppColors.brandPurple : AppColors.deepGreen)
                    .withValues(alpha: active ? 0.12 : 0.05),
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
                    color: active
                        ? AppColors.brandPurple
                        : AppColors.kitchenOff.withValues(alpha: 0.5),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  coupon.displayTitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.exo2(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.deepGreen,
                                  ),
                                ),
                                if (coupon.description != null &&
                                    coupon.description!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    coupon.description!.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.exo2(
                                      fontSize: 12,
                                      height: 1.35,
                                      color: AppColors.deepGreen
                                          .withValues(alpha: 0.62),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                coupon.discountLabel,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: GoogleFonts.exo2(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.brandPurple,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: active
                                  ? [
                                      AppColors.brandPurple
                                          .withValues(alpha: 0.12),
                                      AppColors.amberGlow
                                          .withValues(alpha: 0.4),
                                    ]
                                  : [AppColors.cream, AppColors.cream],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: active
                                  ? AppColors.brandPurple.withValues(alpha: 0.35)
                                  : AppColors.deepGreen.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            coupon.code,
                            style: GoogleFonts.exo2(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: AppColors.deepGreen,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _CouponStatusToggle(
                        active: active,
                        busy: busy,
                        onChanged: onActiveChanged,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _CouponActionButton(
                              label: 'Edit',
                              icon: Icons.edit_rounded,
                              color: AppColors.brandPurple,
                              onPressed: busy ? null : onEdit,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CouponActionButton(
                              label: 'Delete',
                              icon: Icons.delete_outline_rounded,
                              color: AppColors.kitchenOff,
                              onPressed: busy ? null : onDelete,
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
                      color: Color(0x55FFFFFF),
                      child: Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
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
}

class _CouponStatusToggle extends StatelessWidget {
  const _CouponStatusToggle({
    required this.active,
    required this.busy,
    required this.onChanged,
  });

  final bool active;
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
            child: _StatusChip(
              label: 'Enabled',
              icon: Icons.check_circle_outline_rounded,
              selected: active,
              color: AppColors.sage,
              onTap: busy || active ? null : () => onChanged(true),
            ),
          ),
          Expanded(
            child: _StatusChip(
              label: 'Disabled',
              icon: Icons.block_rounded,
              selected: !active,
              color: AppColors.kitchenOff,
              onTap: busy || !active ? null : () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected
                    ? color
                    : AppColors.deepGreen.withValues(alpha: 0.35),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.exo2(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? color
                      : AppColors.deepGreen.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CouponActionButton extends StatelessWidget {
  const _CouponActionButton({
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
    return SizedBox(
      height: 36,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.45)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: Size.zero,
          fixedSize: const Size.fromHeight(36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _CouponFormSheet extends StatefulWidget {
  const _CouponFormSheet({
    required this.phoneE164,
    this.edit,
  });

  final String phoneE164;
  final SellerCoupon? edit;

  @override
  State<_CouponFormSheet> createState() => _CouponFormSheetState();
}

class _CouponFormSheetState extends State<_CouponFormSheet> {
  final _api = Optica2Api();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _codeController = TextEditingController();
  final _valueController = TextEditingController();
  final _minPurchaseController = TextEditingController();
  final _maxDiscountableController = TextEditingController();
  DishDiscountType _discountType = DishDiscountType.percent;
  bool _submitting = false;

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final edit = widget.edit;
    if (edit != null) {
      _titleController.text = edit.title;
      _descriptionController.text = edit.description ?? '';
      _codeController.text = edit.code;
      _discountType = edit.discountType == DishDiscountType.amount
          ? DishDiscountType.amount
          : DishDiscountType.percent;
      _valueController.text = edit.discountValue.truncateToDouble() ==
              edit.discountValue
          ? edit.discountValue.toStringAsFixed(0)
          : edit.discountValue.toStringAsFixed(2);
      final minPurchase = edit.minPurchaseAmount;
      if (minPurchase != null && minPurchase > 0) {
        _minPurchaseController.text = minPurchase.truncateToDouble() ==
                minPurchase
            ? minPurchase.toStringAsFixed(0)
            : minPurchase.toStringAsFixed(2);
      }
      final maxDiscountable = edit.maxDiscountableAmount;
      if (maxDiscountable != null && maxDiscountable > 0) {
        _maxDiscountableController.text = maxDiscountable.truncateToDouble() ==
                maxDiscountable
            ? maxDiscountable.toStringAsFixed(0)
            : maxDiscountable.toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    _api.close();
    _titleController.dispose();
    _descriptionController.dispose();
    _codeController.dispose();
    _valueController.dispose();
    _minPurchaseController.dispose();
    _maxDiscountableController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final code = _codeController.text.trim();
    final value = double.tryParse(_valueController.text.trim());
    final minPurchaseRaw = _minPurchaseController.text.trim();
    final minPurchase = minPurchaseRaw.isEmpty
        ? null
        : double.tryParse(minPurchaseRaw);
    final maxDiscountableRaw = _maxDiscountableController.text.trim();
    final maxDiscountable = maxDiscountableRaw.isEmpty
        ? null
        : double.tryParse(maxDiscountableRaw);

    if (title.isEmpty) {
      AppToast.warning(context, 'Enter a coupon title.');
      return;
    }
    if (code.isEmpty) {
      AppToast.warning(context, 'Enter a coupon code.');
      return;
    }
    if (value == null || value <= 0) {
      AppToast.warning(context, 'Enter a valid discount.');
      return;
    }
    if (_discountType == DishDiscountType.percent && value > 100) {
      AppToast.warning(context, 'Percent cannot exceed 100.');
      return;
    }
    if (minPurchaseRaw.isNotEmpty && (minPurchase == null || minPurchase <= 0)) {
      AppToast.warning(context, 'Enter a valid minimum purchase amount.');
      return;
    }
    if (_discountType == DishDiscountType.percent &&
        maxDiscountableRaw.isNotEmpty &&
        (maxDiscountable == null || maxDiscountable <= 0)) {
      AppToast.warning(context, 'Enter a valid maximum purchase for discount.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      if (_isEdit) {
        await _api.updateCoupon(
          phoneE164: widget.phoneE164,
          couponId: widget.edit!.id,
          code: code,
          title: title,
          description: description.isEmpty ? null : description,
          discountType: _discountType,
          discountValue: value,
          minPurchaseAmount: minPurchase,
          maxDiscountableAmount:
              _discountType == DishDiscountType.percent ? maxDiscountable : null,
          sellerId: sellerId,
        );
      } else {
        await _api.createCoupon(
          phoneE164: widget.phoneE164,
          code: code,
          title: title,
          description: description.isEmpty ? null : description,
          discountType: _discountType,
          discountValue: value,
          minPurchaseAmount: minPurchase,
          maxDiscountableAmount:
              _discountType == DishDiscountType.percent ? maxDiscountable : null,
          sellerId: sellerId,
        );
      }
      if (!mounted) return;
      AppToast.success(context, _isEdit ? 'Coupon updated.' : 'Coupon created.');
      Navigator.pop(context, true);
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      AppToast.danger(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.danger(context, 'Could not save coupon.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _capPercentDiscount() {
    final raw = _valueController.text.trim();
    final value = double.tryParse(raw);
    if (value == null || value <= 100) return;

    const capped = '100';
    _valueController.value = const TextEditingValue(
      text: capped,
      selection: TextSelection.collapsed(offset: capped.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final maxHeight =
        MediaQuery.sizeOf(context).height * 0.92 - viewInsets.bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.deepGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isEdit ? 'Edit coupon' : 'New coupon',
              style: GoogleFonts.exo2(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.deepGreen,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: _fieldDecoration('Title', hint: 'Weekend special'),
              style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: _fieldDecoration(
                'Description',
                hint: 'Weekend lunch special',
              ),
              style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
              ],
              decoration: _fieldDecoration('Coupon code', hint: 'SAVE20'),
              style: GoogleFonts.exo2(fontWeight: FontWeight.w800, letterSpacing: 1),
            ),
            const SizedBox(height: 16),
            Text(
              'Discount type',
              style: GoogleFonts.exo2(
                fontWeight: FontWeight.w700,
                color: AppColors.deepGreen.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TypeChip(
                    label: 'Percent %',
                    selected: _discountType == DishDiscountType.percent,
                    onTap: () => setState(
                      () {
                        _discountType = DishDiscountType.percent;
                        _capPercentDiscount();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TypeChip(
                    label: 'Flat ₹',
                    selected: _discountType == DishDiscountType.amount,
                    onTap: () => setState(
                      () {
                        _discountType = DishDiscountType.amount;
                        _maxDiscountableController.clear();
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _valueController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) {
                if (_discountType == DishDiscountType.percent) {
                  _capPercentDiscount();
                }
              },
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: _fieldDecoration(
                _discountType == DishDiscountType.percent
                    ? 'Discount (%)'
                    : 'Discount (₹)',
                hint: _discountType == DishDiscountType.percent ? '20' : '50',
                helperText: _discountType == DishDiscountType.percent
                    ? 'Maximum 100%'
                    : null,
              ),
              style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
            ),
            if (_discountType == DishDiscountType.percent) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _maxDiscountableController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: _fieldDecoration(
                  'Maximum purchase for discount (₹)',
                  hint: '50',
                  helperText:
                      'Optional — e.g. 50% off applies on first ₹50 only',
                ),
                style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _minPurchaseController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: _fieldDecoration(
                'Minimum purchase (₹)',
                hint: '100',
                helperText: 'Optional — e.g. 20% off on ₹100 purchase',
              ),
              style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _submitting ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandPurple,
                  foregroundColor: Colors.white,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEdit ? 'Save changes' : 'Create coupon',
                        style: GoogleFonts.exo2(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(
    String label, {
    required String hint,
    String? helperText,
  }) {
    final border = AppColors.brandPurple.withValues(alpha: 0.28);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      helperStyle: GoogleFonts.exo2(
        fontSize: 12,
        color: AppColors.deepGreen.withValues(alpha: 0.55),
      ),
      labelStyle: GoogleFonts.exo2(
        color: AppColors.deepGreen.withValues(alpha: 0.7),
      ),
      filled: true,
      fillColor: AppColors.cream,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.brandPurple, width: 1.6),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.brandPurple.withValues(alpha: 0.15)
          : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.brandPurple
                  : AppColors.brandPurple.withValues(alpha: 0.2),
              width: selected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.exo2(
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.brandPurple : AppColors.deepGreen,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
