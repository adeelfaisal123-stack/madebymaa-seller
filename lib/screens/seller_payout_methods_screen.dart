import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/seller_payout_method.dart';
import '../seller_session_prefs.dart';
import '../services/optica2_api.dart';
import '../theme/app_colors.dart';
import '../utils/app_system_ui.dart';
import '../widgets/app_toast.dart';

class SellerPayoutMethodsScreen extends StatefulWidget {
  const SellerPayoutMethodsScreen({
    super.key,
    required this.phoneE164,
    this.initialMethods = const [],
  });

  final String phoneE164;
  final List<SellerPayoutMethod> initialMethods;

  @override
  State<SellerPayoutMethodsScreen> createState() =>
      _SellerPayoutMethodsScreenState();
}

class _SellerPayoutMethodsScreenState extends State<SellerPayoutMethodsScreen> {
  final _api = Optica2Api();
  bool _loading = true;
  List<SellerPayoutMethod> _methods = [];
  final Set<int> _busyIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialMethods.isNotEmpty) {
      _methods = widget.initialMethods;
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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final methods = await _api.fetchPayoutMethods(
        phoneE164: widget.phoneE164,
        sellerId: sellerId,
      );
      if (!mounted) return;
      setState(() {
        _methods = methods;
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

  Future<void> _openAddForm(SellerPayoutMethodType type) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddPayoutMethodSheet(
        phoneE164: widget.phoneE164,
        type: type,
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _deleteMethod(SellerPayoutMethod method) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove payout method?', style: GoogleFonts.exo2(fontWeight: FontWeight.w800)),
        content: Text('“${method.label}” will be removed.', style: GoogleFonts.exo2()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.exo2())),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.kitchenOff),
            child: Text('Remove', style: GoogleFonts.exo2()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyIds.add(method.id));
    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      await _api.deletePayoutMethod(
        phoneE164: widget.phoneE164,
        payoutMethodId: method.id,
        sellerId: sellerId,
      );
      if (!mounted) return;
      setState(() => _methods.removeWhere((m) => m.id == method.id));
      AppToast.success(context, 'Payout method removed.');
    } on Optica2ApiException catch (e) {
      if (mounted) AppToast.danger(context, e.message);
    } catch (_) {
      if (mounted) AppToast.danger(context, 'Could not remove payout method.');
    } finally {
      if (mounted) setState(() => _busyIds.remove(method.id));
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
          'Payout methods',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w800,
            color: AppColors.deepGreen,
          ),
        ),
      ),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _AddMethodButton(
                        icon: Icons.qr_code_rounded,
                        label: 'Add UPI',
                        onTap: () => _openAddForm(SellerPayoutMethodType.upi),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AddMethodButton(
                        icon: Icons.account_balance_outlined,
                        label: 'Add bank',
                        filled: true,
                        onTap: () => _openAddForm(SellerPayoutMethodType.bank),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brandPurple))
          : RefreshIndicator(
              color: AppColors.brandPurple,
              onRefresh: _load,
              child: _methods.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        32,
                        32,
                        32,
                        AppSystemUi.bottomInset(context, 32),
                      ),
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 56,
                          color: AppColors.brandPurple.withValues(alpha: 0.55),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No payout methods yet',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.exo2(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.deepGreen,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add a bank account or UPI ID to receive withdrawals.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.exo2(
                            fontSize: 14,
                            height: 1.45,
                            color: AppColors.deepGreen.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      itemCount: _methods.length,
                      itemBuilder: (context, index) {
                        final method = _methods[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PayoutMethodCard(
                            method: method,
                            busy: _busyIds.contains(method.id),
                            onDelete: () => _deleteMethod(method),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class _AddMethodButton extends StatelessWidget {
  const _AddMethodButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.brandPurple : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: filled ? Colors.white : AppColors.brandPurple,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.exo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: filled ? Colors.white : AppColors.deepGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayoutMethodCard extends StatelessWidget {
  const _PayoutMethodCard({
    required this.method,
    required this.busy,
    required this.onDelete,
  });

  final SellerPayoutMethod method;
  final bool busy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isUpi = method.isUpi;
    final color = isUpi ? AppColors.sage : AppColors.brandPurple;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isUpi ? Icons.qr_code_2_rounded : Icons.account_balance_outlined,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.label,
                    style: GoogleFonts.exo2(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepGreen,
                    ),
                  ),
                  Text(
                    method.typeLabel,
                    style: GoogleFonts.exo2(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    method.subtitle,
                    style: GoogleFonts.exo2(
                      fontSize: 12,
                      color: AppColors.deepGreen.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandPurple),
              )
            else
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, color: AppColors.kitchenOff.withValues(alpha: 0.85)),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddPayoutMethodSheet extends StatefulWidget {
  const _AddPayoutMethodSheet({
    required this.phoneE164,
    required this.type,
  });

  final String phoneE164;
  final SellerPayoutMethodType type;

  @override
  State<_AddPayoutMethodSheet> createState() => _AddPayoutMethodSheetState();
}

class _AddPayoutMethodSheetState extends State<_AddPayoutMethodSheet> {
  final _api = Optica2Api();
  final _labelController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _titleController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _upiController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _api.close();
    _labelController.dispose();
    _bankNameController.dispose();
    _titleController.dispose();
    _accountController.dispose();
    _ifscController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _submitting = true);
    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      await _api.createPayoutMethod(
        phoneE164: widget.phoneE164,
        sellerId: sellerId,
        type: widget.type,
        label: _labelController.text,
        bankName: _bankNameController.text,
        bankAccountTitle: _titleController.text,
        bankAccountNumber: _accountController.text,
        bankIfsc: _ifscController.text,
        upiId: _upiController.text,
      );
      if (!mounted) return;
      AppToast.success(context, 'Payout method added.');
      Navigator.pop(context, true);
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      AppToast.danger(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.danger(context, 'Could not save payout method.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBank = widget.type == SellerPayoutMethodType.bank;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      duration: const Duration(milliseconds: 120),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: SingleChildScrollView(
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
                    isBank ? 'Add bank account' : 'Add UPI ID',
                    style: GoogleFonts.exo2(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepGreen,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _field(_labelController, 'Nickname (optional)', hint: isBank ? 'Primary SBI' : 'PhonePe'),
                  const SizedBox(height: 12),
                  if (isBank) ...[
                    _field(_titleController, 'Account title', hint: 'Name on account'),
                    const SizedBox(height: 12),
                    _field(_bankNameController, 'Bank name', hint: 'State Bank of India'),
                    const SizedBox(height: 12),
                    _field(
                      _accountController,
                      'Account number',
                      hint: 'Digits only',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 12),
                    _field(
                      _ifscController,
                      'IFSC code',
                      hint: 'SBIN0001234',
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ] else
                    _field(
                      _upiController,
                      'UPI ID',
                      hint: 'name@upi',
                      keyboardType: TextInputType.emailAddress,
                    ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _submitting ? null : _save,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.brandPurple),
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Save',
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

  Widget _field(
    TextEditingController controller,
    String label, {
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.cream,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
