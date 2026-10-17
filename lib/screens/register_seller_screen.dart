import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/phone_number.dart';

import '../models/seller_cuisine.dart';
import '../seller_auth_prefs.dart';
import '../seller_session_prefs.dart';
import '../services/optica2_api.dart';
import '../theme/app_colors.dart';
import '../utils/app_system_ui.dart';
import '../utils/country_names.dart';
import '../utils/device_country.dart';
import '../widgets/app_toast.dart';
import '../widgets/locale_phone_field.dart';
import '../services/seller_auth_navigation.dart';
import 'seller_kyc_screen.dart';

class RegisterSellerScreen extends StatefulWidget {
  const RegisterSellerScreen({
    super.key,
    this.phoneE164,
    this.phoneVerified = false,
    this.kitchenSetupOnly = false,
    this.sellerId,
  });

  final String? phoneE164;
  final bool phoneVerified;
  /// After admin approval — kitchen profile step only.
  final bool kitchenSetupOnly;
  final int? sellerId;

  @override
  State<RegisterSellerScreen> createState() => _RegisterSellerScreenState();
}

class _RegisterSellerScreenState extends State<RegisterSellerScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();

  final _kitchenNameController = TextEditingController();
  final _deliveryMinController = TextEditingController(text: '25');
  final _deliveryMaxController = TextEditingController(text: '45');

  final _optica2 = Optica2Api();
  final _picker = ImagePicker();

  int _step = 0;
  String _countryCode = DeviceCountry.fromDeviceLocale();
  bool _detectingLocale = true;

  PhoneNumber? _phone;
  XFile? _logo;
  List<SellerCuisine> _cuisines = [];
  final Set<int> _selectedCuisineIds = {};
  bool _cuisinesLoading = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _step = widget.kitchenSetupOnly ? 1 : 0;
    if (widget.kitchenSetupOnly) {
      _loadCuisines();
    }
    if (widget.phoneE164 != null && widget.phoneE164!.isNotEmpty) {
      _phone = PhoneNumber(
        countryISOCode: widget.phoneE164!.startsWith('+91') ? 'IN' : _countryCode,
        countryCode: widget.phoneE164!.startsWith('+91') ? '+91' : '',
        number: widget.phoneE164!.replaceFirst(RegExp(r'^\+\d+'), ''),
      );
    }
    _detectCountry();
  }

  @override
  void dispose() {
    _optica2.close();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _kitchenNameController.dispose();
    _deliveryMinController.dispose();
    _deliveryMaxController.dispose();
    super.dispose();
  }

  Future<void> _detectCountry() async {
    final iso = await DeviceCountry.resolveFromLocation();
    if (!mounted) return;
    setState(() {
      _countryCode = iso;
      _detectingLocale = false;
    });
  }

  String _e164(PhoneNumber phone) {
    final raw = phone.completeNumber;
    if (raw.startsWith('+')) return raw;
    return '+$raw';
  }

  String get _resolvedPhoneE164 {
    if (widget.phoneVerified && widget.phoneE164 != null) {
      return widget.phoneE164!;
    }
    final phone = _phone;
    if (phone != null) return _e164(phone);
    return '';
  }

  InputDecoration _fieldDecoration(String hint, Color border, Color focused) {
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
        borderSide: BorderSide(color: focused, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    );
  }

  Future<void> _loadCuisines() async {
    if (_cuisines.isNotEmpty || _cuisinesLoading) return;
    setState(() => _cuisinesLoading = true);
    try {
      final list = await _optica2.fetchCuisines();
      if (!mounted) return;
      setState(() {
        _cuisines = list;
        _cuisinesLoading = false;
      });
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      setState(() => _cuisinesLoading = false);
      AppToast.danger(context, e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _cuisinesLoading = false);
      AppToast.danger(context, '$e');
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
    setState(() => _logo = file);
  }

  bool _validateStep0() {
    if (_nameController.text.trim().length < 2) {
      AppToast.warning(context, 'Enter your full name.');
      return false;
    }
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      AppToast.warning(context, 'Enter a valid email.');
      return false;
    }
    if (_resolvedPhoneE164.isEmpty) {
      AppToast.warning(context, 'Enter a valid phone number.');
      return false;
    }
    if (_addressController.text.trim().length < 5) {
      AppToast.warning(context, 'Enter your address.');
      return false;
    }
    if (_cityController.text.trim().isEmpty) {
      AppToast.warning(context, 'Enter your city.');
      return false;
    }
    if (_stateController.text.trim().isEmpty) {
      AppToast.warning(context, 'Enter your state.');
      return false;
    }
    return true;
  }

  bool _validateStep1() {
    if (_kitchenNameController.text.trim().length < 2) {
      AppToast.warning(context, 'Enter your kitchen name.');
      return false;
    }
    if (_selectedCuisineIds.isEmpty) {
      AppToast.warning(context, 'Select at least one cuisine.');
      return false;
    }
    final min = int.tryParse(_deliveryMinController.text.trim());
    final max = int.tryParse(_deliveryMaxController.text.trim());
    if (min == null || max == null || min < 5 || max < 5) {
      AppToast.warning(context, 'Enter valid delivery times (minutes).');
      return false;
    }
    if (min > max) {
      AppToast.warning(context, 'Max delivery time must be ≥ minimum.');
      return false;
    }
    if (_logo == null) {
      AppToast.warning(context, 'Upload your kitchen logo.');
      return false;
    }
    return true;
  }

  void _nextStep() {
    if (widget.kitchenSetupOnly) {
      _submit();
      return;
    }

    if (_step == 0) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      if (!_validateStep0()) return;
      _submit();
    }
  }

  void _backStep() {
    if (widget.kitchenSetupOnly || _step == 0) {
      Navigator.of(context).pop();
      return;
    }
  }

  Future<void> _submit() async {
    if (widget.kitchenSetupOnly) {
      await _submitKitchenSetup();
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_validateStep0()) return;

    final phoneE164 = _resolvedPhoneE164;

    setState(() => _submitting = true);
    try {
      final result = await _optica2.registerSellerMinimal(
        phoneE164: phoneE164,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        country: _countryCode,
      );
      await SellerAuthPrefs.markOtpVerified(phoneE164: phoneE164);
      await SellerSessionPrefs.saveSellerId(result.sellerId);
      if (!mounted) return;
      SellerAuthNavigation.openKycPending(
        context,
        sellerId: result.sellerId,
        phoneE164: result.phoneE164,
        message: result.message,
      );
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      AppToast.danger(context, e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitKitchenSetup() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_validateStep1()) return;

    final phoneE164 = _resolvedPhoneE164;
    final min = int.parse(_deliveryMinController.text.trim());
    final max = int.parse(_deliveryMaxController.text.trim());

    setState(() => _submitting = true);
    try {
      final result = await _optica2.setupSellerKitchen(
        phoneE164: phoneE164,
        businessName: _kitchenNameController.text.trim(),
        cuisineIds: _selectedCuisineIds.toList()..sort(),
        deliveryMinutesMin: min,
        deliveryMinutesMax: max,
        logo: _logo!,
        sellerId: widget.sellerId,
      );
      await SellerSessionPrefs.saveSellerId(result.sellerId);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SellerKycScreen(
            sellerId: result.sellerId,
            phoneE164: result.phoneE164,
            resumeToHomeOnComplete: true,
          ),
        ),
      );
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      AppToast.danger(context, e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _personalStep(Color border, Color focused, bool verifiedPhone) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: _fieldDecoration('Full name', border, focused),
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w600,
              color: AppColors.deepGreen,
            ),
            validator: (v) =>
                v == null || v.trim().length < 2 ? 'Enter your full name' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _fieldDecoration('Email', border, focused),
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w600,
              color: AppColors.deepGreen,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty || !v.contains('@')) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          if (verifiedPhone)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.kitchenOpen),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: AppColors.kitchenOpen),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.phoneE164!,
                      style: GoogleFonts.exo2(
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepGreen,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            LocalePhoneField(
              controller: _phoneController,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              onSaved: (phone) => _phone = phone,
              onChanged: (phone) => _phone = phone,
              decoration: _fieldDecoration('Phone number', border, focused),
              style: GoogleFonts.exo2(
                fontWeight: FontWeight.w600,
                color: AppColors.deepGreen,
              ),
              dropdownTextStyle: GoogleFonts.exo2(
                fontWeight: FontWeight.w600,
                color: AppColors.deepGreen,
              ),
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressController,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: _fieldDecoration('Address', border, focused),
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w600,
              color: AppColors.deepGreen,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _cityController,
            textCapitalization: TextCapitalization.words,
            decoration: _fieldDecoration('City', border, focused),
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w600,
              color: AppColors.deepGreen,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _stateController,
            textCapitalization: TextCapitalization.words,
            decoration: _fieldDecoration('State', border, focused),
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w600,
              color: AppColors.deepGreen,
            ),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: _fieldDecoration('Country', border, focused).copyWith(
              fillColor: AppColors.brandPurple.withValues(alpha: 0.06),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.public_rounded,
                  color: AppColors.brandPurple.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _detectingLocale
                        ? 'Detecting country…'
                        : CountryNames.label(_countryCode),
                    style: GoogleFonts.exo2(
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepGreen,
                    ),
                  ),
                ),
                Text(
                  _countryCode,
                  style: GoogleFonts.exo2(
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandPurple,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _selectedCuisinesLabel() {
    if (_selectedCuisineIds.isEmpty) {
      return _cuisines.isEmpty ? 'No cuisines available' : 'Select cuisines';
    }

    final names = _cuisines
        .where((c) => _selectedCuisineIds.contains(c.id))
        .map((c) => c.name)
        .toList();
    if (names.length <= 2) return names.join(', ');
    return '${names.take(2).join(', ')} +${names.length - 2}';
  }

  Future<void> _openCuisinePicker() async {
    if (_cuisines.isEmpty || _submitting) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void toggle(int id) {
              setState(() {
                if (_selectedCuisineIds.contains(id)) {
                  if (_selectedCuisineIds.length > 1) {
                    _selectedCuisineIds.remove(id);
                  }
                } else {
                  _selectedCuisineIds.add(id);
                }
              });
              setSheetState(() {});
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.75,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Select cuisines',
                              style: GoogleFonts.exo2(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.deepGreen,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close_rounded),
                            color: AppColors.deepGreen,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      child: Text(
                        'Choose all that describe your kitchen.',
                        style: GoogleFonts.exo2(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.deepGreen.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                    Flexible(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        itemCount: _cuisines.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final cuisine = _cuisines[index];
                          final selected =
                              _selectedCuisineIds.contains(cuisine.id);
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: () => toggle(cuisine.id),
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    _CuisineAvatar(cuisine: cuisine),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        cuisine.name,
                                        style: GoogleFonts.exo2(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.deepGreen,
                                        ),
                                      ),
                                    ),
                                    Checkbox(
                                      value: selected,
                                      onChanged: (_) => toggle(cuisine.id),
                                      activeColor: AppColors.brandPurple,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: FilledButton(
                        onPressed: _selectedCuisineIds.isEmpty
                            ? null
                            : () => Navigator.pop(sheetContext),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brandPurple,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Done',
                          style: GoogleFonts.exo2(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            );
          },
        );
      },
    );
  }

  Widget _cuisineSelectField(Color border, Color focused) {
    final enabled = _cuisines.isNotEmpty && !_submitting;
    final label = _selectedCuisinesLabel();

    return InputDecorator(
      decoration: _fieldDecoration('Cuisines', border, focused),
      child: InkWell(
        onTap: enabled ? _openCuisinePicker : null,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.exo2(
                  fontWeight: FontWeight.w600,
                  color: _selectedCuisineIds.isEmpty
                      ? AppColors.deepGreen.withValues(alpha: 0.45)
                      : AppColors.deepGreen,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: enabled
                  ? AppColors.brandPurple
                  : AppColors.deepGreen.withValues(alpha: 0.25),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kitchenStep(Color border, Color focused) {
    if (_cuisinesLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandPurple),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: _pickLogo,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _logo != null
                        ? AppColors.brandPurple
                        : border,
                    width: _logo != null ? 1.6 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    if (_logo != null && !kIsWeb)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_logo!.path),
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Icon(
                        Icons.storefront_rounded,
                        size: 48,
                        color: AppColors.brandPurple.withValues(alpha: 0.75),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      _logo != null ? 'Change kitchen logo' : 'Upload kitchen logo',
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
          const SizedBox(height: 12),
          TextFormField(
            controller: _kitchenNameController,
            textCapitalization: TextCapitalization.words,
            decoration: _fieldDecoration('Kitchen name', border, focused),
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w600,
              color: AppColors.deepGreen,
            ),
          ),
          const SizedBox(height: 12),
          _cuisineSelectField(border, focused),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _deliveryMinController,
                  keyboardType: TextInputType.number,
                  decoration: _fieldDecoration('Min delivery (min)', border, focused),
                  style: GoogleFonts.exo2(
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepGreen,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _deliveryMaxController,
                  keyboardType: TextInputType.number,
                  decoration: _fieldDecoration('Max delivery (min)', border, focused),
                  style: GoogleFonts.exo2(
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepGreen,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final border = AppColors.brandPurple.withValues(alpha: 0.28);
    final focused = AppColors.brandPurple;
    final top = AppSystemUi.topInset(context);
    final verifiedPhone = widget.phoneVerified && widget.phoneE164 != null;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: top + 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 24, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  color: AppColors.deepGreen,
                  onPressed: _submitting ? null : _backStep,
                ),
                Expanded(
                  child: Text(
                    widget.kitchenSetupOnly
                        ? 'Your kitchen'
                        : 'Your details',
                    style: GoogleFonts.exo2(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: AppColors.deepGreen,
                    ),
                  ),
                ),
                if (!widget.kitchenSetupOnly)
                  Text(
                    '1/1',
                    style: GoogleFonts.exo2(
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepGreen.withValues(alpha: 0.55),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text(
              widget.kitchenSetupOnly
                  ? 'Set up your kitchen profile'
                  : 'Tell us about yourself',
              style: GoogleFonts.exo2(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.deepGreen,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Form(
              key: _formKey,
              child: widget.kitchenSetupOnly
                  ? _kitchenStep(border, focused)
                  : _personalStep(border, focused, verifiedPhone),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              AppSystemUi.bottomInset(context, 24),
            ),
            child: FilledButton(
              onPressed: _submitting ? null : _nextStep,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.kitchenSetupOnly
                          ? 'Save kitchen profile'
                          : 'Submit for review',
                      style: GoogleFonts.exo2(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CuisineAvatar extends StatelessWidget {
  const _CuisineAvatar({required this.cuisine});

  final SellerCuisine cuisine;

  @override
  Widget build(BuildContext context) {
    final imageUrl = cuisine.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallback(),
        ),
      );
    }

    return _fallback();
  }

  Widget _fallback() {
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.brandPurple.withValues(alpha: 0.1),
      child: Icon(
        Icons.restaurant_rounded,
        color: AppColors.brandPurple.withValues(alpha: 0.7),
      ),
    );
  }
}
