import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/seller_kitchen_cuisines.dart';
import '../seller_session_prefs.dart';
import '../services/optica2_api.dart';
import '../theme/app_colors.dart';
import '../widgets/app_toast.dart';

/// Multi-select cuisines for the seller kitchen.
class KitchenCuisinesScreen extends StatefulWidget {
  const KitchenCuisinesScreen({
    super.key,
    required this.phoneE164,
    this.initial,
  });

  final String phoneE164;
  final SellerKitchenCuisines? initial;

  @override
  State<KitchenCuisinesScreen> createState() => _KitchenCuisinesScreenState();
}

class _KitchenCuisinesScreenState extends State<KitchenCuisinesScreen> {
  final _api = Optica2Api();
  bool _loading = true;
  bool _saving = false;
  List<SellerCuisineOption> _cuisines = const [];
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _apply(widget.initial!);
      _loading = false;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  void _apply(SellerKitchenCuisines data) {
    _cuisines = data.cuisines;
    _selectedIds
      ..clear()
      ..addAll(data.selectedIds);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final data = await _api.fetchKitchenCuisines(
        phoneE164: widget.phoneE164,
        sellerId: sellerId,
      );
      if (!mounted) return;
      setState(() {
        _apply(data);
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

  void _toggle(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        if (_selectedIds.length > 1) {
          _selectedIds.remove(id);
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _save() async {
    if (_selectedIds.isEmpty) {
      AppToast.warning(context, 'Select at least one cuisine.');
      return;
    }

    setState(() => _saving = true);
    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final data = await _api.updateKitchenCuisines(
        phoneE164: widget.phoneE164,
        cuisineIds: _selectedIds.toList()..sort(),
        sellerId: sellerId,
      );
      if (!mounted) return;
      AppToast.success(context, 'Cuisines updated.');
      Navigator.of(context).pop(data);
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.danger(context, e.message);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        foregroundColor: AppColors.deepGreen,
        title: Text(
          'Cuisines',
          style: GoogleFonts.exo2(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brandPurple),
            )
          : _cuisines.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No cuisines available. Ask admin to add them.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.exo2(
                        color: AppColors.terracotta,
                        fontSize: 15,
                      ),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
                  children: [
                    Text(
                      'Select all cuisines that describe your kitchen. Customers use these to find you.',
                      style: GoogleFonts.exo2(
                        fontSize: 14,
                        height: 1.45,
                        color: AppColors.deepGreen.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _cuisines.map((cuisine) {
                        final selected = _selectedIds.contains(cuisine.id);
                        return FilterChip(
                          label: Text(cuisine.name),
                          avatar: cuisine.imageUrl != null
                              ? CircleAvatar(
                                  backgroundImage:
                                      NetworkImage(cuisine.imageUrl!),
                                  backgroundColor:
                                      AppColors.brandPurple.withValues(
                                    alpha: 0.12,
                                  ),
                                )
                              : Icon(
                                  Icons.restaurant_outlined,
                                  size: 18,
                                  color: selected
                                      ? AppColors.brandPurple
                                      : AppColors.deepGreen.withValues(
                                          alpha: 0.5,
                                        ),
                                ),
                          selected: selected,
                          showCheckmark: true,
                          selectedColor:
                              AppColors.brandPurple.withValues(alpha: 0.14),
                          checkmarkColor: AppColors.brandPurple,
                          labelStyle: GoogleFonts.exo2(
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? AppColors.brandPurple
                                : AppColors.deepGreen,
                          ),
                          side: BorderSide(
                            color: selected
                                ? AppColors.brandPurple
                                : AppColors.brandPurple.withValues(alpha: 0.2),
                          ),
                          onSelected: _saving ? null : (_) => _toggle(cuisine.id),
                        );
                      }).toList(),
                    ),
                  ],
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: FilledButton(
            onPressed: _loading || _saving || _cuisines.isEmpty ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandPurple,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Save cuisines',
                    style: GoogleFonts.exo2(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
