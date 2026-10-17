import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/seller_wallet.dart';
import '../theme/app_colors.dart';
import '../utils/app_system_ui.dart';

class SellerWithdrawalDetailScreen extends StatelessWidget {
  const SellerWithdrawalDetailScreen({super.key, required this.withdrawal});

  final SellerWalletWithdrawal withdrawal;

  Color _statusColor() {
    return switch (withdrawal.status) {
      'pending' => AppColors.orderPending,
      'completed' => AppColors.kitchenOpen,
      'rejected' => AppColors.kitchenOff,
      _ => AppColors.brandPurple,
    };
  }

  IconData _statusIcon() {
    return switch (withdrawal.status) {
      'pending' => Icons.hourglass_top_rounded,
      'completed' => Icons.check_circle_rounded,
      'rejected' => Icons.cancel_rounded,
      _ => Icons.account_balance_wallet_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    final steps = withdrawal.timelineSteps;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.deepGreen),
        title: Text(
          'Withdrawal details',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w800,
            color: AppColors.deepGreen,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          AppSystemUi.bottomInset(context, 24),
        ),
        children: [
          _AmountHero(
            withdrawal: withdrawal,
            color: color,
            icon: _statusIcon(),
          ),
          const SizedBox(height: 20),
          _InfoCard(
            title: 'Payout destination',
            icon: withdrawal.isUpi
                ? Icons.qr_code_2_rounded
                : Icons.account_balance_outlined,
            children: withdrawal.isUpi
                ? [
                    _DetailRow(label: 'Type', value: 'UPI'),
                    _DetailRow(label: 'UPI ID', value: withdrawal.upiId),
                  ]
                : [
                    _DetailRow(label: 'Bank', value: withdrawal.bankName),
                    if (withdrawal.bankAccountTitle.isNotEmpty)
                      _DetailRow(
                        label: 'Account title',
                        value: withdrawal.bankAccountTitle,
                      ),
                    if (withdrawal.bankAccountNumber.isNotEmpty)
                      _DetailRow(
                        label: 'Account number',
                        value: withdrawal.bankAccountNumber,
                      ),
                    if (withdrawal.bankIban.isNotEmpty)
                      _DetailRow(label: 'IFSC', value: withdrawal.bankIban),
                  ],
          ),
          const SizedBox(height: 16),
          Text(
            'Status timeline',
            style: GoogleFonts.exo2(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.deepGreen,
            ),
          ),
          const SizedBox(height: 12),
          _WithdrawalTimeline(steps: steps, accent: color),
          const SizedBox(height: 16),
          _InfoCard(
            title: 'Reference',
            icon: Icons.tag_rounded,
            children: [
              _DetailRow(label: 'Withdrawal ID', value: withdrawal.reference),
              _DetailRow(label: 'Requested', value: withdrawal.requestedAtHuman),
              if (withdrawal.processedAtHuman != null &&
                  withdrawal.processedAtHuman!.isNotEmpty)
                _DetailRow(
                  label: withdrawal.isRejected ? 'Processed' : 'Completed',
                  value: withdrawal.processedAtHuman!,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountHero extends StatelessWidget {
  const _AmountHero({
    required this.withdrawal,
    required this.color,
    required this.icon,
  });

  final SellerWalletWithdrawal withdrawal;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.78)],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  withdrawal.statusLabel,
                  style: GoogleFonts.exo2(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            formatWalletAmount(withdrawal.amount),
            style: GoogleFonts.exo2(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            withdrawal.reference,
            style: GoogleFonts.exo2(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.brandPurple.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.brandPurple),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.exo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.exo2(
                fontSize: 12,
                color: AppColors.deepGreen.withValues(alpha: 0.5),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.exo2(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.deepGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WithdrawalTimeline extends StatelessWidget {
  const _WithdrawalTimeline({
    required this.steps,
    required this.accent,
  });

  final List<SellerWithdrawalTimelineStep> steps;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.brandPurple.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _TimelineStepRow(
              step: steps[i],
              isLast: i == steps.length - 1,
              accent: accent,
            ),
        ],
      ),
    );
  }
}

class _TimelineStepRow extends StatelessWidget {
  const _TimelineStepRow({
    required this.step,
    required this.isLast,
    required this.accent,
  });

  final SellerWithdrawalTimelineStep step;
  final bool isLast;
  final Color accent;

  Color _dotColor() {
    return switch (step.state) {
      SellerWithdrawalStepState.done => AppColors.kitchenOpen,
      SellerWithdrawalStepState.active => accent,
      SellerWithdrawalStepState.failed => AppColors.kitchenOff,
      SellerWithdrawalStepState.upcoming =>
        AppColors.deepGreen.withValues(alpha: 0.2),
    };
  }

  Color _lineColor() {
    if (step.state == SellerWithdrawalStepState.upcoming) {
      return AppColors.deepGreen.withValues(alpha: 0.1);
    }
    if (step.state == SellerWithdrawalStepState.failed) {
      return AppColors.kitchenOff.withValues(alpha: 0.4);
    }
    return _dotColor().withValues(alpha: 0.5);
  }

  IconData? _dotIcon() {
    return switch (step.state) {
      SellerWithdrawalStepState.done => Icons.check_rounded,
      SellerWithdrawalStepState.active => Icons.more_horiz_rounded,
      SellerWithdrawalStepState.failed => Icons.close_rounded,
      SellerWithdrawalStepState.upcoming => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = _dotColor();
    final isActive = step.state == SellerWithdrawalStepState.active;
    final isUpcoming = step.state == SellerWithdrawalStepState.upcoming;
    final icon = _dotIcon();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isActive ? 28 : 22,
                  height: isActive ? 28 : 22,
                  decoration: BoxDecoration(
                    color: isUpcoming
                        ? Colors.transparent
                        : dotColor.withValues(alpha: isUpcoming ? 0.1 : 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: dotColor,
                      width: isActive ? 2.5 : 2,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: dotColor.withValues(alpha: 0.45),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: icon != null
                      ? Icon(icon, size: isActive ? 16 : 13, color: dotColor)
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2.5,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _lineColor(),
                            _lineColor().withValues(alpha: 0.15),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: GoogleFonts.exo2(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isUpcoming
                          ? AppColors.deepGreen.withValues(alpha: 0.4)
                          : AppColors.deepGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.subtitle,
                    style: GoogleFonts.exo2(
                      fontSize: 12,
                      height: 1.4,
                      color: isUpcoming
                          ? AppColors.deepGreen.withValues(alpha: 0.35)
                          : AppColors.deepGreen.withValues(alpha: 0.6),
                    ),
                  ),
                  if (step.timestamp != null &&
                      step.timestamp!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: dotColor.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          step.timestamp!,
                          style: GoogleFonts.exo2(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: dotColor.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (isActive) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'In progress',
                        style: GoogleFonts.exo2(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: accent,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
