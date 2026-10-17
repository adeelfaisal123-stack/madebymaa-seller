import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/seller_bank_details.dart';
import '../seller_session_prefs.dart';
import '../services/optica2_api.dart';
import '../theme/app_colors.dart';
import '../widgets/app_toast.dart';

class SellerBankDetailsScreen extends StatefulWidget {
  const SellerBankDetailsScreen({
    super.key,
    required this.phoneE164,
    this.initial,
  });

  final String phoneE164;
  final SellerBankDetails? initial;

  @override
  State<SellerBankDetailsScreen> createState() =>
      _SellerBankDetailsScreenState();
}

class _SellerBankDetailsScreenState extends State<SellerBankDetailsScreen> {
  final _api = Optica2Api();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _ibanController;
  late final TextEditingController _accountNumberController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _titleController = TextEditingController(text: i?.bankAccountTitle ?? '');
    _bankNameController = TextEditingController(text: i?.bankName ?? '');
    _ibanController = TextEditingController(text: i?.bankIban ?? '');
    _accountNumberController =
        TextEditingController(text: i?.bankAccountNumber ?? '');
  }

  @override
  void dispose() {
    _api.close();
    _titleController.dispose();
    _bankNameController.dispose();
    _ibanController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      await _api.updateBankDetails(
        phoneE164: widget.phoneE164,
        bankName: _bankNameController.text,
        bankIban: _ibanController.text,
        bankAccountNumber: _accountNumberController.text,
        bankAccountTitle: _titleController.text,
        sellerId: sellerId,
      );
      if (!mounted) return;
      AppToast.success(context, 'Bank details saved.');
      Navigator.of(context).pop(true);
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      AppToast.danger(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.danger(context, 'Could not save bank details.');
    } finally {
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
        iconTheme: const IconThemeData(color: AppColors.deepGreen),
        title: Text(
          'Bank details',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w800,
            color: AppColors.deepGreen,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text(
              'Payout account',
              style: GoogleFonts.exo2(
                fontSize: 14,
                height: 1.45,
                color: AppColors.deepGreen.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 20),
            _field(
              controller: _titleController,
              label: 'Account title',
              hint: 'Name on bank account',
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            _field(
              controller: _bankNameController,
              label: 'Bank name',
              hint: 'e.g. State Bank of India',
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            _field(
              controller: _ibanController,
              label: 'IBAN',
              hint: 'PK00XXXX0000000000000000',
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\s]')),
              ],
              validator: (v) {
                final raw = v?.replaceAll(RegExp(r'\s+'), '') ?? '';
                if (raw.isEmpty) return 'Required';
                if (raw.length < 15) return 'Enter a valid IBAN';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _field(
              controller: _accountNumberController,
              label: 'Account number',
              hint: 'Digits only',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final raw = v?.replaceAll(RegExp(r'\D'), '') ?? '';
                if (raw.isEmpty) return 'Required';
                if (raw.length < 6) return 'Enter a valid account number';
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
                        'Save bank details',
                        style: GoogleFonts.exo2(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.brandPurple.withValues(alpha: 0.2),
          ),
        ),
      ),
    );
  }
}
