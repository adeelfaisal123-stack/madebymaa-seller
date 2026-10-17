import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/seller_kitchen_profile.dart';
import '../seller_session_prefs.dart';
import '../services/optica2_api.dart';
import '../theme/app_colors.dart';
import '../widgets/app_toast.dart';

/// Edit kitchen name, logo, and delivery time range.
class KitchenProfileScreen extends StatefulWidget {
  const KitchenProfileScreen({
    super.key,
    required this.phoneE164,
    this.initialProfile,
  });

  final String phoneE164;
  final SellerKitchenProfile? initialProfile;

  @override
  State<KitchenProfileScreen> createState() => _KitchenProfileScreenState();
}

class _KitchenProfileScreenState extends State<KitchenProfileScreen> {
  final _api = Optica2Api();
  final _nameController = TextEditingController();
  final _deliveryMinController = TextEditingController();
  final _deliveryMaxController = TextEditingController();
  final _picker = ImagePicker();

  bool _loading = true;
  bool _saving = false;
  bool _instantDeliveryEnabled = true;
  XFile? _newLogo;
  String? _existingLogoUrl;

  @override
  void initState() {
    super.initState();
    if (widget.initialProfile != null) {
      _applyProfile(widget.initialProfile!);
      _loading = false;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _deliveryMinController.dispose();
    _deliveryMaxController.dispose();
    _api.close();
    super.dispose();
  }

  void _applyProfile(SellerKitchenProfile profile) {
    _nameController.text = profile.name;
    _existingLogoUrl = profile.logoUrl;
    _deliveryMinController.text =
        (profile.deliveryMinutesMin ?? 25).toString();
    _deliveryMaxController.text =
        (profile.deliveryMinutesMax ?? 45).toString();
    _instantDeliveryEnabled = profile.instantDeliveryEnabled;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final profile = await _api.fetchKitchenProfile(
        phoneE164: widget.phoneE164,
        sellerId: sellerId,
      );
      if (!mounted) return;
      setState(() {
        _applyProfile(profile);
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

  Future<void> _pickLogo() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text('Camera', style: GoogleFonts.exo2()),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text('Gallery', style: GoogleFonts.exo2()),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;

    final file = await _picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (file == null || !mounted) return;
    setState(() => _newLogo = file);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      AppToast.warning(context, 'Enter your kitchen name.');
      return;
    }

    final min = int.tryParse(_deliveryMinController.text.trim());
    final max = int.tryParse(_deliveryMaxController.text.trim());
    if (min == null || max == null || min < 5 || max < 5) {
      AppToast.warning(context, 'Enter valid delivery times (minutes).');
      return;
    }
    if (max < min) {
      AppToast.warning(context, 'Max delivery time must be ≥ minimum.');
      return;
    }

    setState(() => _saving = true);
    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final updated = await _api.updateKitchenProfile(
        phoneE164: widget.phoneE164,
        name: name,
        deliveryMinutesMin: min,
        deliveryMinutesMax: max,
        instantDeliveryEnabled: _instantDeliveryEnabled,
        logo: _newLogo,
        sellerId: sellerId,
      );
      if (!mounted) return;
      AppToast.success(context, 'Kitchen profile updated.');
      Navigator.pop(context, updated);
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.danger(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.danger(context, 'Could not save. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.deepGreen),
        title: Text(
          'Kitchen Profile',
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
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Update how customers see your kitchen.',
                    style: GoogleFonts.exo2(
                      fontSize: 14,
                      color: AppColors.deepGreen.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: _saving ? null : _pickLogo,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: (_newLogo != null || _existingLogoUrl != null)
                                ? AppColors.brandPurple
                                : AppColors.deepGreen.withValues(alpha: 0.15),
                            width: (_newLogo != null || _existingLogoUrl != null)
                                ? 1.6
                                : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            _LogoPreview(
                              newLogo: _newLogo,
                              logoUrl: _existingLogoUrl,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _newLogo != null
                                  ? 'Change logo'
                                  : (_existingLogoUrl != null
                                      ? 'Change kitchen logo'
                                      : 'Upload kitchen logo'),
                              style: GoogleFonts.exo2(
                                fontWeight: FontWeight.w700,
                                color: AppColors.deepGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.words,
                    style: GoogleFonts.exo2(color: AppColors.deepGreen),
                    decoration: InputDecoration(
                      labelText: 'Kitchen name',
                      labelStyle: GoogleFonts.exo2(
                        color: AppColors.deepGreen.withValues(alpha: 0.6),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: AppColors.deepGreen.withValues(alpha: 0.15),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.brandPurple,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _deliveryMinController,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: GoogleFonts.exo2(color: AppColors.deepGreen),
                          decoration: InputDecoration(
                            labelText: 'Min delivery (min)',
                            labelStyle: GoogleFonts.exo2(
                              color: AppColors.deepGreen.withValues(alpha: 0.6),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: AppColors.deepGreen.withValues(alpha: 0.15),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppColors.brandPurple,
                                width: 1.6,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _deliveryMaxController,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: GoogleFonts.exo2(color: AppColors.deepGreen),
                          decoration: InputDecoration(
                            labelText: 'Max delivery (min)',
                            labelStyle: GoogleFonts.exo2(
                              color: AppColors.deepGreen.withValues(alpha: 0.6),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: AppColors.deepGreen.withValues(alpha: 0.15),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppColors.brandPurple,
                                width: 1.6,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    child: SwitchListTile(
                      value: _instantDeliveryEnabled,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _instantDeliveryEnabled = value),
                      activeThumbColor: AppColors.brandPurple,
                      title: Text(
                        'Instant delivery',
                        style: GoogleFonts.exo2(
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepGreen,
                        ),
                      ),
                      subtitle: Text(
                        _instantDeliveryEnabled
                            ? 'Customers can order for immediate delivery.'
                            : 'Customers must schedule a delivery slot.',
                        style: GoogleFonts.exo2(
                          fontSize: 12,
                          color: AppColors.deepGreen.withValues(alpha: 0.6),
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: AppColors.deepGreen.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Save changes',
                            style: GoogleFonts.exo2(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _LogoPreview extends StatelessWidget {
  const _LogoPreview({
    this.newLogo,
    this.logoUrl,
  });

  final XFile? newLogo;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    if (newLogo != null && !kIsWeb) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(newLogo!.path),
          height: 100,
          width: 100,
          fit: BoxFit.cover,
        ),
      );
    }

    if (logoUrl != null && logoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          logoUrl!,
          height: 100,
          width: 100,
          fit: BoxFit.cover,
          errorBuilder: (_, e, s) => const _LogoPlaceholder(),
        ),
      );
    }

    return const _LogoPlaceholder();
  }
}

class _LogoPlaceholder extends StatelessWidget {
  const _LogoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.storefront_rounded,
      size: 48,
      color: AppColors.brandPurple.withValues(alpha: 0.75),
    );
  }
}
