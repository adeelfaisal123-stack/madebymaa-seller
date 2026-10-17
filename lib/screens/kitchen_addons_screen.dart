import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/seller_addon.dart';
import '../seller_session_prefs.dart';
import '../services/optica2_api.dart';
import '../theme/app_colors.dart';
import '../widgets/app_toast.dart';

/// Manage optional add-ons (e.g. Cookie ₹50) for the kitchen.
class KitchenAddonsScreen extends StatefulWidget {
  const KitchenAddonsScreen({super.key, required this.phoneE164});

  final String phoneE164;

  @override
  State<KitchenAddonsScreen> createState() => _KitchenAddonsScreenState();
}

class _KitchenAddonsScreenState extends State<KitchenAddonsScreen> {
  final _api = Optica2Api();
  bool _loading = true;
  List<SellerAddon> _addons = [];

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
      final addons = await _api.fetchAddons(
        phoneE164: widget.phoneE164,
        sellerId: sellerId,
      );
      if (!mounted) return;
      setState(() {
        _addons = addons;
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

  Future<void> _openAddonForm({SellerAddon? edit}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddonFormSheet(
        phoneE164: widget.phoneE164,
        edit: edit,
      ),
    );

    if (saved == true) {
      await _load();
    }
  }

  Future<void> _confirmDelete(SellerAddon addon) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Remove add-on?',
          style: GoogleFonts.exo2(fontWeight: FontWeight.w800),
        ),
        content: Text(
          '“${addon.name}” will be removed from your kitchen.',
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

    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      await _api.deleteAddon(
        phoneE164: widget.phoneE164,
        addonId: addon.id,
        sellerId: sellerId,
      );
      if (!mounted) return;
      setState(() => _addons.removeWhere((a) => a.id == addon.id));
      AppToast.success(context, 'Add-on removed.');
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      AppToast.danger(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.danger(context, 'Could not delete add-on.');
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
          'Add-ons',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w800,
            color: AppColors.deepGreen,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddonForm(),
        backgroundColor: AppColors.brandPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Add add-on',
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
          : _addons.isEmpty
              ? _EmptyAddons(onAdd: () => _openAddonForm())
              : RefreshIndicator(
                  color: AppColors.brandPurple,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                    itemCount: _addons.length,
                    itemBuilder: (context, index) {
                      final addon = _addons[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AddonCard(
                          addon: addon,
                          onEdit: () => _openAddonForm(edit: addon),
                          onDelete: () => _confirmDelete(addon),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _EmptyAddons extends StatelessWidget {
  const _EmptyAddons({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.amberGlow.withValues(alpha: 0.35),
                border: Border.all(
                  color: AppColors.terracotta.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.add_box_outlined,
                size: 36,
                color: AppColors.terracotta,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No add-ons yet',
              style: GoogleFonts.exo2(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.deepGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Extras customers can add to orders — e.g. Cookie ₹50.',
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
                'Add your first add-on',
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

class _AddonCard extends StatelessWidget {
  const _AddonCard({
    required this.addon,
    required this.onEdit,
    required this.onDelete,
  });

  static const _cardHeight = 88.0;

  final SellerAddon addon;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _cardHeight,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.amberGlow.withValues(alpha: 0.6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.terracotta.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 4,
                  child: const ColoredBox(color: AppColors.terracotta),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.amberGlow.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.cookie_outlined,
                          color: AppColors.terracotta,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              addon.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.exo2(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.deepGreen,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              addon.priceLabel,
                              style: GoogleFonts.exo2(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.brandPurple,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: onEdit,
                        icon: Icon(
                          Icons.edit_outlined,
                          color: AppColors.brandPurple.withValues(alpha: 0.85),
                        ),
                      ),
                      IconButton(
                        onPressed: onDelete,
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.terracotta.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddonFormSheet extends StatefulWidget {
  const _AddonFormSheet({
    required this.phoneE164,
    this.edit,
  });

  final String phoneE164;
  final SellerAddon? edit;

  @override
  State<_AddonFormSheet> createState() => _AddonFormSheetState();
}

class _AddonFormSheetState extends State<_AddonFormSheet> {
  final _api = Optica2Api();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  bool _submitting = false;

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final edit = widget.edit;
    if (edit != null) {
      _nameController.text = edit.name;
      _priceController.text = edit.price.truncateToDouble() == edit.price
          ? edit.price.toStringAsFixed(0)
          : edit.price.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _api.close();
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim());

    if (name.isEmpty) {
      AppToast.warning(context, 'Enter the add-on name.');
      return;
    }
    if (price == null || price < 0) {
      AppToast.warning(context, 'Enter a valid price.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      if (_isEdit) {
        await _api.updateAddon(
          phoneE164: widget.phoneE164,
          addonId: widget.edit!.id,
          name: name,
          price: price,
          sellerId: sellerId,
        );
      } else {
        await _api.createAddon(
          phoneE164: widget.phoneE164,
          name: name,
          price: price,
          sellerId: sellerId,
        );
      }
      if (!mounted) return;
      AppToast.success(
        context,
        _isEdit ? 'Add-on updated.' : 'Add-on saved.',
      );
      Navigator.pop(context, true);
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      AppToast.danger(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.danger(context, 'Could not save add-on.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepGreen.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
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
              _isEdit ? 'Edit add-on' : 'New add-on',
              style: GoogleFonts.exo2(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.deepGreen,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'e.g. Cookie — ₹50',
              style: GoogleFonts.exo2(
                fontSize: 13,
                color: AppColors.deepGreen.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: _fieldDecoration('Name', hint: 'Cookie'),
              style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: _fieldDecoration('Price (₹)', hint: '50'),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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
                        _isEdit ? 'Save changes' : 'Add add-on',
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
    );
  }

  InputDecoration _fieldDecoration(String label, {required String hint}) {
    final border = AppColors.brandPurple.withValues(alpha: 0.28);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.exo2(
        color: AppColors.deepGreen.withValues(alpha: 0.7),
      ),
      hintStyle: GoogleFonts.exo2(
        color: AppColors.deepGreen.withValues(alpha: 0.35),
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
