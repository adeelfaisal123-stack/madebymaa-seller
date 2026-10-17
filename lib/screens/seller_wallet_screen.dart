import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/seller_wallet.dart';
import '../utils/order_number.dart';
import '../seller_session_prefs.dart';
import '../services/optica2_api.dart';
import '../theme/app_colors.dart';
import '../utils/app_system_ui.dart';
import '../widgets/app_toast.dart';
import 'seller_payout_methods_screen.dart';
import 'seller_withdrawal_detail_screen.dart';
import 'seller_withdraw_screen.dart';

class SellerWalletScreen extends StatefulWidget {
  const SellerWalletScreen({super.key, required this.phoneE164});

  final String phoneE164;

  @override
  State<SellerWalletScreen> createState() => _SellerWalletScreenState();
}

class _SellerWalletScreenState extends State<SellerWalletScreen> {
  final _api = Optica2Api();
  bool _loading = true;
  SellerWalletSnapshot? _snapshot;

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
      final snapshot = await _api.fetchWallet(
        phoneE164: widget.phoneE164,
        sellerId: sellerId,
      );
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
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

  Future<void> _openPayoutMethods() async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SellerPayoutMethodsScreen(
          phoneE164: widget.phoneE164,
          initialMethods: _snapshot?.payoutMethods ?? const [],
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openWithdraw() async {
    final snapshot = _snapshot;
    if (snapshot == null) return;

    if (!snapshot.hasPayoutMethods) {
      AppToast.warning(context, 'Add a bank account or UPI ID before withdrawing.');
      await _openPayoutMethods();
      return;
    }

    if (snapshot.pendingWithdrawal > 0) {
      AppToast.warning(context, 'You already have a pending withdrawal.');
      return;
    }

    if (snapshot.balance < 1) {
      AppToast.warning(context, 'No balance available to withdraw.');
      return;
    }

    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SellerWithdrawScreen(
          phoneE164: widget.phoneE164,
          balance: snapshot.balance,
          methods: snapshot.payoutMethods,
        ),
      ),
    );

    if (submitted == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.deepGreen),
        title: Text(
          'Wallet',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w800,
            color: AppColors.deepGreen,
          ),
        ),
      ),
      body: _loading && snapshot == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brandPurple),
            )
          : RefreshIndicator(
              color: AppColors.brandPurple,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  24,
                  0,
                  24,
                  AppSystemUi.bottomInset(context, 24),
                ),
                children: [
                  _BalanceCard(snapshot: snapshot),
                  const SizedBox(height: 16),
                  if (snapshot != null && snapshot.pendingWithdrawal > 0)
                    _PendingBanner(amount: snapshot.pendingWithdrawal),
                  if (snapshot != null && snapshot.pendingWithdrawal > 0)
                    const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.payments_outlined,
                          label: 'Payout methods',
                          onTap: _openPayoutMethods,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.outbound_rounded,
                          label: 'Withdraw',
                          filled: true,
                          enabled: snapshot?.canWithdraw ?? false,
                          onTap: _openWithdraw,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Withdrawal history',
                    style: GoogleFonts.exo2(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepGreen,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (snapshot == null || snapshot.withdrawals.isEmpty)
                    _EmptyHistory(
                      icon: Icons.history_rounded,
                      message: 'No withdrawals yet',
                      hint: 'Request a payout when you have balance',
                    )
                  else
                    ...snapshot.withdrawals.map(
                      (w) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _WithdrawalTile(
                          withdrawal: w,
                          onTap: () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    SellerWithdrawalDetailScreen(withdrawal: w),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Earnings from orders',
                    style: GoogleFonts.exo2(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepGreen,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (snapshot == null || snapshot.credits.isEmpty)
                    _EmptyHistory(
                      icon: Icons.receipt_long_outlined,
                      message: 'No earnings yet',
                      hint: 'Delivered orders are credited automatically',
                    )
                  else
                    ...snapshot.credits.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CreditTile(credit: c),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({this.snapshot});

  final SellerWalletSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [AppColors.brandPurple, AppColors.brandPurpleDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPurple.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available balance',
            style: GoogleFonts.exo2(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            snapshot == null
                ? '…'
                : formatWalletAmount(snapshot!.balance),
            style: GoogleFonts.exo2(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _BalanceMetric(
                label: 'Total earned',
                value: snapshot == null
                    ? '…'
                    : formatWalletAmount(snapshot!.totalCredited),
              ),
              const SizedBox(width: 20),
              _BalanceMetric(
                label: 'Withdrawn',
                value: snapshot == null
                    ? '…'
                    : formatWalletAmount(snapshot!.totalWithdrawn),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceMetric extends StatelessWidget {
  const _BalanceMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.exo2(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.exo2(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bootstrapWarningBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bootstrapWarningBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            color: AppColors.orderPending,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${formatWalletAmount(amount)} withdrawal pending admin approval',
              style: GoogleFonts.exo2(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.bootstrapWarningText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled
          ? (enabled
              ? AppColors.brandPurple
              : AppColors.brandPurple.withValues(alpha: 0.4))
          : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
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

class _WithdrawalTile extends StatelessWidget {
  const _WithdrawalTile({
    required this.withdrawal,
    required this.onTap,
  });

  final SellerWalletWithdrawal withdrawal;
  final VoidCallback onTap;

  Color _statusColor() {
    return switch (withdrawal.status) {
      'pending' => AppColors.orderPending,
      'completed' => AppColors.kitchenOpen,
      'rejected' => AppColors.kitchenOff,
      _ => AppColors.deepGreen,
    };
  }

  Color _statusTextColor() {
    return withdrawal.status == 'pending'
        ? AppColors.bootstrapWarningText
        : _statusColor();
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    final textColor = _statusTextColor();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.outbound_rounded, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatWalletAmount(withdrawal.amount),
                      style: GoogleFonts.exo2(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.deepGreen,
                      ),
                    ),
                    Text(
                      withdrawal.destinationLabel.isNotEmpty
                          ? withdrawal.destinationLabel
                          : withdrawal.bankName,
                      style: GoogleFonts.exo2(
                        fontSize: 12,
                        color: AppColors.deepGreen.withValues(alpha: 0.55),
                      ),
                    ),
                    Text(
                      withdrawal.requestedAtHuman,
                      style: GoogleFonts.exo2(
                        fontSize: 11,
                        color: AppColors.deepGreen.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  withdrawal.statusLabel,
                  style: GoogleFonts.exo2(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.deepGreen.withValues(alpha: 0.3),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreditTile extends StatelessWidget {
  const _CreditTile({required this.credit});

  final SellerWalletCreditEntry credit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.kitchenOpen.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.kitchenOpen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.kitchenOpen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  credit.label,
                  style: GoogleFonts.exo2(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepGreen,
                  ),
                ),
                if (credit.orderNumber.isNotEmpty)
                  Text(
                    formatOrderDisplayNumber(
                      orderNumber: credit.orderNumber,
                      id: credit.id,
                    ),
                    style: GoogleFonts.exo2(
                      fontSize: 12,
                      color: AppColors.deepGreen.withValues(alpha: 0.55),
                    ),
                  ),
                Text(
                  credit.createdAtHuman,
                  style: GoogleFonts.exo2(
                    fontSize: 11,
                    color: AppColors.deepGreen.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${formatWalletAmount(credit.amount)}',
            style: GoogleFonts.exo2(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.kitchenOpen,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({
    required this.icon,
    required this.message,
    required this.hint,
  });

  final IconData icon;
  final String message;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.brandPurple.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text(
            message,
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w700,
              color: AppColors.deepGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: GoogleFonts.exo2(
              fontSize: 12,
              color: AppColors.deepGreen.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}
