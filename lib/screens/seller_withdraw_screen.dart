import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/seller_payout_method.dart';
import '../models/seller_wallet.dart';
import '../seller_session_prefs.dart';
import '../services/optica2_api.dart';
import '../theme/app_colors.dart';
import '../utils/app_system_ui.dart';
import '../widgets/app_toast.dart';

class SellerWithdrawScreen extends StatefulWidget {
  const SellerWithdrawScreen({
    super.key,
    required this.phoneE164,
    required this.balance,
    required this.methods,
  });

  final String phoneE164;
  final double balance;
  final List<SellerPayoutMethod> methods;

  @override
  State<SellerWithdrawScreen> createState() => _SellerWithdrawScreenState();
}

class _SellerWithdrawScreenState extends State<SellerWithdrawScreen> {
  final _api = Optica2Api();
  final _amountController = TextEditingController();
  late SellerPayoutMethod _selectedMethod;
  String? _errorText;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.balance.round().toString();
    _selectedMethod = widget.methods.first;
  }

  @override
  void dispose() {
    _api.close();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _openWithdrawToSheet() async {
    final picked = await showModalBottomSheet<SellerPayoutMethod>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WithdrawToSheet(
        methods: widget.methods,
        selectedId: _selectedMethod.id,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedMethod = picked);
    }
  }

  Future<void> _submit() async {
    final value = double.tryParse(_amountController.text.trim());
    if (value == null || value < 1) {
      setState(() => _errorText = 'Enter a valid amount');
      return;
    }
    if (value > widget.balance) {
      setState(
        () => _errorText = 'Maximum ${formatWalletAmount(widget.balance)}',
      );
      return;
    }

    setState(() {
      _errorText = null;
      _submitting = true;
    });

    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      await _api.requestWalletWithdrawal(
        phoneE164: widget.phoneE164,
        amount: value,
        payoutMethodId: _selectedMethod.id,
        sellerId: sellerId,
      );
      if (!mounted) return;
      AppToast.success(
        context,
        'Withdrawal request submitted',
        bottomPadding: 24,
      );
      Navigator.pop(context, true);
    } on Optica2ApiException catch (e) {
      if (mounted) AppToast.danger(context, e.message);
    } catch (_) {
      if (mounted) {
        AppToast.danger(context, 'Could not request withdrawal.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _useMaxAmount() {
    _amountController.text = widget.balance.round().toString();
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Scaffold(
      backgroundColor: AppColors.cream,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.deepGreen),
        title: Text(
          'Withdraw',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w800,
            color: AppColors.deepGreen,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          24 + viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [AppColors.brandPurple, AppColors.brandPurpleDeep],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available balance',
                    style: GoogleFonts.exo2(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatWalletAmount(widget.balance),
                    style: GoogleFonts.exo2(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Amount',
              style: GoogleFonts.exo2(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.deepGreen.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.exo2(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.deepGreen,
              ),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: GoogleFonts.exo2(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepGreen.withValues(alpha: 0.45),
                ),
                hintText: '0',
                errorText: _errorText,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppColors.deepGreen.withValues(alpha: 0.08),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.brandPurple,
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _useMaxAmount,
                child: Text(
                  'Withdraw all',
                  style: GoogleFonts.exo2(
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandPurple,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Withdraw to',
              style: GoogleFonts.exo2(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.deepGreen.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 10),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: _openWithdrawToSheet,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.brandPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _selectedMethod.isUpi
                              ? Icons.qr_code_2_rounded
                              : Icons.account_balance_outlined,
                          color: AppColors.brandPurple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedMethod.label,
                              style: GoogleFonts.exo2(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.deepGreen,
                              ),
                            ),
                            Text(
                              _selectedMethod.subtitle,
                              style: GoogleFonts.exo2(
                                fontSize: 12,
                                color: AppColors.deepGreen.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.deepGreen.withValues(alpha: 0.45),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandPurple,
              disabledBackgroundColor:
                  AppColors.brandPurple.withValues(alpha: 0.45),
              minimumSize: const Size.fromHeight(52),
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
                    'Request withdrawal',
                    style: GoogleFonts.exo2(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _WithdrawToSheet extends StatefulWidget {
  const _WithdrawToSheet({
    required this.methods,
    required this.selectedId,
  });

  final List<SellerPayoutMethod> methods;
  final int selectedId;

  @override
  State<_WithdrawToSheet> createState() => _WithdrawToSheetState();
}

class _WithdrawToSheetState extends State<_WithdrawToSheet> {
  late int _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedId;
  }

  void _confirm() {
    final method = widget.methods.firstWhere((m) => m.id == _selectedId);
    Navigator.pop(context, method);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = AppSystemUi.bottomInset(context, 16);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Container(
            padding: EdgeInsets.fromLTRB(24, 12, 24, bottomInset),
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
                  'Withdraw to',
                  style: GoogleFonts.exo2(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepGreen,
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: widget.methods.map((method) {
                        final selected = method.id == _selectedId;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: selected
                                ? AppColors.brandPurple.withValues(alpha: 0.08)
                                : AppColors.cream,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _selectedId = method.id),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.brandPurple
                                        : AppColors.deepGreen
                                            .withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      method.isUpi
                                          ? Icons.qr_code_2_rounded
                                          : Icons.account_balance_outlined,
                                      color: AppColors.brandPurple,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            method.label,
                                            style: GoogleFonts.exo2(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.deepGreen,
                                            ),
                                          ),
                                          Text(
                                            method.subtitle,
                                            style: GoogleFonts.exo2(
                                              fontSize: 11,
                                              color: AppColors.deepGreen
                                                  .withValues(alpha: 0.55),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (selected)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: AppColors.brandPurple,
                                        size: 22,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _confirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPurple,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Confirm',
                    style: GoogleFonts.exo2(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
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
