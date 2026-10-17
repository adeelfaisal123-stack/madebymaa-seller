import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/seller_account_profile.dart';
import '../seller_session_prefs.dart';
import '../services/optica2_api.dart';
import '../theme/app_colors.dart';
import '../utils/msg91_phone.dart';
import '../widgets/app_toast.dart';

class SellerEditProfileScreen extends StatefulWidget {
  const SellerEditProfileScreen({
    super.key,
    required this.phoneE164,
    this.initialProfile,
  });

  final String phoneE164;
  final SellerAccountProfile? initialProfile;

  @override
  State<SellerEditProfileScreen> createState() =>
      _SellerEditProfileScreenState();
}

class _SellerEditProfileScreenState extends State<SellerEditProfileScreen> {
  final _api = Optica2Api();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    _nameController = TextEditingController(text: profile?.name ?? '');
    _phoneController = TextEditingController(
      text: toDisplayE164(profile?.phoneE164 ?? widget.phoneE164),
    );
    _emailController = TextEditingController(text: profile?.email ?? '');

    if (profile != null && profile.name.isNotEmpty) {
      _loading = false;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _api.close();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _applyProfile(SellerAccountProfile profile) {
    _nameController.text = profile.name;
    _phoneController.text = toDisplayE164(
      profile.phoneE164.isNotEmpty ? profile.phoneE164 : widget.phoneE164,
    );
    _emailController.text = profile.email;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final profile = await _api.fetchSellerProfile(
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final updated = await _api.updateSellerProfile(
        phoneE164: widget.phoneE164,
        sellerId: sellerId,
        name: _nameController.text,
        email: _emailController.text,
      );
      if (!mounted) return;
      AppToast.success(context, 'Profile updated.');
      Navigator.pop(context, updated);
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.danger(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.danger(context, 'Could not save profile.');
    }
  }

  InputDecoration _fieldDecoration(String hint) {
    final border = AppColors.brandPurple.withValues(alpha: 0.28);
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.exo2(
        color: AppColors.deepGreen.withValues(alpha: 0.35),
      ),
      filled: true,
      fillColor: Colors.white,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    bool readOnly = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w700,
            color: AppColors.deepGreen.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          validator: validator,
          keyboardType: keyboardType,
          style: GoogleFonts.exo2(
            color: readOnly
                ? AppColors.deepGreen.withValues(alpha: 0.55)
                : AppColors.deepGreen,
          ),
          decoration: _fieldDecoration(hint).copyWith(
            filled: true,
            fillColor: readOnly ? AppColors.cream : Colors.white,
          ),
        ),
      ],
    );
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
          'Edit profile',
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Update your name and email. Manage your address from the Address option in profile.',
                      style: GoogleFonts.exo2(
                        fontSize: 14,
                        height: 1.45,
                        color: AppColors.deepGreen.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _field(
                      controller: _nameController,
                      label: 'Full name',
                      hint: 'Your name',
                      validator: (v) =>
                          v == null || v.trim().length < 2 ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _phoneController,
                      label: 'Phone number',
                      hint: '+91XXXXXXXXXX',
                      readOnly: true,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Required';
                        if (!value.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brandPurple,
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
                                'Save changes',
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
    );
  }
}
