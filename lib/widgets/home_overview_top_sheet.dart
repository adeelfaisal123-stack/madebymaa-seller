import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/seller_wallet.dart';
import '../theme/app_colors.dart';

/// Full-width top sheet (mirror of bottom sheet) with horizontally swipeable cards.
class HomeOverviewTopSheet {
  HomeOverviewTopSheet._();

  static Future<void> show(
    BuildContext context, {
    required double availableBalance,
    required double pendingBalance,
    required int pendingOrdersCount,
    required int deliveredOrdersCount,
    VoidCallback? onAvailableBalance,
    VoidCallback? onPendingBalance,
    VoidCallback? onPendingOrders,
    VoidCallback? onDeliveredOrders,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, _, _) {
        return _HomeOverviewTopSheetBody(
          availableBalance: availableBalance,
          pendingBalance: pendingBalance,
          pendingOrdersCount: pendingOrdersCount,
          deliveredOrdersCount: deliveredOrdersCount,
          onAvailableBalance: onAvailableBalance,
          onPendingBalance: onPendingBalance,
          onPendingOrders: onPendingOrders,
          onDeliveredOrders: onDeliveredOrders,
        );
      },
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }
}

class _HomeOverviewTopSheetBody extends StatefulWidget {
  const _HomeOverviewTopSheetBody({
    required this.availableBalance,
    required this.pendingBalance,
    required this.pendingOrdersCount,
    required this.deliveredOrdersCount,
    this.onAvailableBalance,
    this.onPendingBalance,
    this.onPendingOrders,
    this.onDeliveredOrders,
  });

  final double availableBalance;
  final double pendingBalance;
  final int pendingOrdersCount;
  final int deliveredOrdersCount;
  final VoidCallback? onAvailableBalance;
  final VoidCallback? onPendingBalance;
  final VoidCallback? onPendingOrders;
  final VoidCallback? onDeliveredOrders;

  @override
  State<_HomeOverviewTopSheetBody> createState() =>
      _HomeOverviewTopSheetBodyState();
}

class _HomeOverviewTopSheetBodyState extends State<_HomeOverviewTopSheetBody> {
  late final PageController _pageController;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.82);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    final cards = [
      _OverviewMetricCard(
        icon: Icons.account_balance_wallet_rounded,
        iconColor: AppColors.brandPurple,
        iconBg: AppColors.brandPurple.withValues(alpha: 0.12),
        title: 'Available balance',
        value: formatWalletAmount(widget.availableBalance),
        subtitle: 'Ready to withdraw',
        onTap: widget.onAvailableBalance,
      ),
      _OverviewMetricCard(
        icon: Icons.hourglass_top_rounded,
        iconColor: AppColors.orderPending,
        iconBg: AppColors.bootstrapWarningBg,
        title: 'Pending balance',
        value: formatWalletAmount(widget.pendingBalance),
        subtitle: widget.pendingBalance > 0
            ? 'Payout is being processed'
            : 'No payout in progress',
        highlight: widget.pendingBalance > 0,
        onTap: widget.onPendingBalance,
      ),
      _OverviewMetricCard(
        icon: Icons.pending_actions_rounded,
        iconColor: AppColors.orderPending,
        iconBg: AppColors.bootstrapWarningBg,
        title: 'Pending orders',
        value: '${widget.pendingOrdersCount}',
        subtitle: widget.pendingOrdersCount == 0
            ? 'No orders waiting'
            : widget.pendingOrdersCount == 1
                ? 'Needs your acceptance'
                : 'Need your acceptance',
        highlight: widget.pendingOrdersCount > 0,
        onTap: widget.onPendingOrders,
      ),
      _OverviewMetricCard(
        icon: Icons.check_circle_outline_rounded,
        iconColor: AppColors.kitchenOpen,
        iconBg: AppColors.kitchenOpen.withValues(alpha: 0.12),
        title: 'Delivered orders',
        value: '${widget.deliveredOrdersCount}',
        subtitle: widget.deliveredOrdersCount == 1
            ? 'Completed delivery'
            : 'Completed deliveries',
        highlight: widget.deliveredOrdersCount > 0,
        onTap: widget.onDeliveredOrders,
      ),
    ];

    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        color: AppColors.cream,
        elevation: 16,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: topInset),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.deepGreen.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Quick overview',
                              style: GoogleFonts.exo2(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.deepGreen,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(
                              Icons.close_rounded,
                              color: AppColors.deepGreen.withValues(alpha: 0.5),
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 156,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: cards.length,
                    onPageChanged: (index) =>
                        setState(() => _pageIndex = index),
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: cards[index],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(cards.length, (index) {
                    final active = index == _pageIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.brandPurple
                            : AppColors.brandPurple.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewMetricCard extends StatelessWidget {
  const _OverviewMetricCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.value,
    this.subtitle,
    this.highlight = false,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String value;
  final String? subtitle;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                Navigator.of(context).pop();
                onTap!();
              },
        child: Ink(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: highlight
                  ? AppColors.brandPurple.withValues(alpha: 0.22)
                  : AppColors.brandPurple.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.deepGreen.withValues(alpha: 0.35),
                      size: 22,
                    ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: GoogleFonts.exo2(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepGreen.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.exo2(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: highlight
                      ? AppColors.brandPurple
                      : AppColors.deepGreen,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.exo2(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepGreen.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
