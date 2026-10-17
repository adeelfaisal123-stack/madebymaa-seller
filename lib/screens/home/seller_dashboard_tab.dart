import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../kitchen_status_prefs.dart';
import '../../seller_auth_prefs.dart';
import '../../seller_session_prefs.dart';
import '../../services/optica2_api.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_system_ui.dart';
import '../../widgets/app_toast.dart';
import '../../models/kitchen_open_meal.dart';
import '../../models/kitchen_upcoming_day.dart';
import '../../models/seller_dashboard.dart';
import '../../models/seller_document_kyc_info.dart';
import '../../models/seller_order.dart';
import '../../services/seller_auth_navigation.dart';
import '../../widgets/home_overview_top_sheet.dart';
import '../../widgets/kitchen_open_wizard.dart';
import '../../widgets/kitchen_status_toggle.dart';
import '../../widgets/weekly_earnings_chart.dart';
import '../seller_messages_screen.dart';
import '../seller_notifications_screen.dart';
import '../register_seller_screen.dart';
import '../seller_wallet_screen.dart';

class SellerDashboardTab extends StatefulWidget {
  const SellerDashboardTab({
    super.key,
    this.onPendingOrdersCountChanged,
    this.onViewOrders,
    this.onViewDeliveredOrders,
    this.onViewOrderDetail,
    this.onViewMenu,
  });

  final ValueChanged<int>? onPendingOrdersCountChanged;
  final VoidCallback? onViewOrders;
  final VoidCallback? onViewDeliveredOrders;
  final ValueChanged<int>? onViewOrderDetail;
  final VoidCallback? onViewMenu;

  @override
  State<SellerDashboardTab> createState() => SellerDashboardTabState();
}

class SellerDashboardTabState extends State<SellerDashboardTab> {
  final _api = Optica2Api();
  bool _kitchenOpen = true;
  List<String> _kitchenOpenMeals = const [];
  List<KitchenUpcomingDayPlan> _upcomingKitchenDays = const [];
  bool _loaded = false;
  bool _saving = false;
  String? _loadError;
  SellerDocumentKycStatusKind _documentKycStatus =
      SellerDocumentKycStatusKind.notSubmitted;
  SellerDocumentKycInfo? _documentKyc;
  bool _kitchenSetupPending = false;
  int _unreadNotifications = 0;
  SellerDashboard _dashboard = SellerDashboard.empty;
  bool _dashboardLoading = true;
  double? _walletBalance;
  double _pendingWithdrawal = 0;
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ??
        await SellerAuthPrefs.phoneE164();
    if (phone == null || phone.isEmpty) {
      final cached = await KitchenStatusPrefs.isOpen();
      if (mounted) {
        setState(() {
          _kitchenOpen = cached;
          _loaded = true;
          _loadError = null;
        });
      }
      return;
    }

    final sellerId = await SellerSessionPrefs.sellerId();

    try {
      final result = await _api.fetchKitchenStatus(
        phoneE164: phone,
        sellerId: sellerId,
      );
      if (result.sellerId != null) {
        await SellerSessionPrefs.saveSellerId(result.sellerId!);
      }
      await KitchenStatusPrefs.cacheDetails(
        open: result.kitchenOpen,
        meals: result.kitchenOpenMeals,
        upcoming: result.upcomingKitchenDays,
      );
      if (mounted) {
        setState(() {
          _kitchenOpen = result.kitchenOpen;
          _kitchenOpenMeals = result.kitchenOpenMeals;
          _upcomingKitchenDays = result.upcomingKitchenDays;
          _documentKycStatus = result.documentKycStatus;
          _loaded = true;
          _loadError = null;
        });
      }
      unawaited(_loadUnreadNotifications(phone, sellerId));
      _loadHomeData(phone, sellerId);
    } on Optica2ApiException catch (e) {
      final cached = await KitchenStatusPrefs.isOpen();
      if (mounted) {
        setState(() {
          _kitchenOpen = cached;
          _loaded = true;
          _loadError = e.message;
        });
      }
      _loadHomeData(phone, sellerId);
    } catch (_) {
      final cached = await KitchenStatusPrefs.isOpen();
      if (mounted) {
        setState(() {
          _kitchenOpen = cached;
          _loaded = true;
          _loadError = 'Could not load kitchen status.';
        });
      }
      _loadHomeData(phone, sellerId);
    }
  }

  void _loadHomeData(String phone, int? sellerId) {
    unawaited(_loadDashboard(phone, sellerId));
    unawaited(_loadWallet(phone, sellerId));
    unawaited(_refreshDocumentKycStatus());
  }

  Future<void> _loadWallet(String phone, int? sellerId) async {
    try {
      final wallet = await _api.fetchWallet(
        phoneE164: phone,
        sellerId: sellerId,
      );
      if (!mounted) return;
      setState(() {
        _walletBalance = wallet.balance;
        _pendingWithdrawal = wallet.pendingWithdrawal;
      });
    } catch (_) {}
  }

  Future<void> _openWallet() async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ??
        await SellerAuthPrefs.phoneE164();
    if (phone == null || phone.isEmpty || !mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SellerWalletScreen(phoneE164: phone),
      ),
    );

    if (!mounted) return;
    final sellerId = await SellerSessionPrefs.sellerId();
    unawaited(_loadWallet(phone, sellerId));
  }

  Future<void> _openOverviewSheet() async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ??
        await SellerAuthPrefs.phoneE164();

    var pendingOrdersCount = _resolvedPendingCount();
    var deliveredOrdersCount = _dashboard.stats.deliveredOrdersCount;

    if (phone != null && phone.isNotEmpty) {
      final sellerId = await SellerSessionPrefs.sellerId();
      await Future.wait([
        _loadWallet(phone, sellerId),
        _loadDashboard(phone, sellerId, silent: true),
      ]);

      pendingOrdersCount = _resolvedPendingCount();
      deliveredOrdersCount = _dashboard.stats.deliveredOrdersCount;

      try {
        final orderCounts = await Future.wait([
          _api.fetchOrders(
            phoneE164: phone,
            sellerId: sellerId,
            filter: SellerOrderFilter.pending,
          ),
          _api.fetchOrders(
            phoneE164: phone,
            sellerId: sellerId,
            filter: SellerOrderFilter.delivered,
          ),
        ]);
        pendingOrdersCount = math.max(
          orderCounts[0].length,
          _resolvedPendingCount(),
        );
        deliveredOrdersCount = math.max(
          orderCounts[1].length,
          math.max(
            _dashboard.stats.deliveredOrdersCount,
            _dashboard.stats.completedToday,
          ),
        );
      } catch (_) {
        pendingOrdersCount = _resolvedPendingCount();
        deliveredOrdersCount = math.max(
          _dashboard.stats.deliveredOrdersCount,
          _dashboard.stats.completedToday,
        );
      }
    }
    if (!mounted) return;

    await HomeOverviewTopSheet.show(
      context,
      availableBalance: _walletBalance ?? 0,
      pendingBalance: _pendingWithdrawal,
      pendingOrdersCount: pendingOrdersCount,
      deliveredOrdersCount: deliveredOrdersCount,
      onAvailableBalance: _openWallet,
      onPendingBalance: _openWallet,
      onPendingOrders: widget.onViewOrders,
      onDeliveredOrders: widget.onViewDeliveredOrders,
    );
  }

  int _resolvedPendingCount() {
    return math.max(
      _dashboard.stats.pendingOrdersCount,
      _dashboard.pendingOrders.length,
    );
  }

  Future<void> _loadDashboard(
    String phone,
    int? sellerId, {
    bool silent = false,
  }) async {
    if (!silent && mounted) setState(() => _dashboardLoading = true);

    try {
      final dashboard = await _api.fetchDashboard(
        phoneE164: phone,
        sellerId: sellerId,
      );
      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
        _dashboardLoading = false;
      });
      widget.onPendingOrdersCountChanged?.call(
        math.max(
          dashboard.stats.pendingOrdersCount,
          dashboard.pendingOrders.length,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _dashboardLoading = false);
    }
  }

  Future<void> _refreshAll() async {
    await _loadStatus();
  }

  Future<void> reload() => _refreshAll();

  Future<void> _setKitchenOpen(bool open) async {
    if (_saving) return;

    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ??
        await SellerAuthPrefs.phoneE164();
    if (phone == null || phone.isEmpty) {
      if (!mounted) return;
      AppToast.warning(
        context,
        'Sign in required to update kitchen status.',
        bottomPadding: 100,
      );
      return;
    }

    KitchenOpenWizardResult? wizard;
    if (open) {
      if (!mounted) return;
      wizard = await runKitchenOpenWizard(
        context,
        initialTodayMeals: _kitchenOpenMeals.isNotEmpty
            ? _kitchenOpenMeals
            : const ['lunch'],
        initialUpcoming: _upcomingKitchenDays,
      );
      if (wizard == null || !mounted) return;
    }

    final previous = _kitchenOpen;
    final previousMeals = List<String>.from(_kitchenOpenMeals);
    final previousUpcoming = List<KitchenUpcomingDayPlan>.from(_upcomingKitchenDays);
    setState(() {
      _kitchenOpen = open;
      if (open && wizard != null) {
        _kitchenOpenMeals = wizard.todayMeals;
        _upcomingKitchenDays = wizard.upcomingPlans;
      } else if (!open) {
        _kitchenOpenMeals = const [];
      }
      _saving = true;
    });

    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final result = await _api.updateKitchenStatus(
        phoneE164: phone,
        kitchenOpen: open,
        kitchenOpenMeals: open ? wizard!.todayMeals : null,
        upcomingDaysJson: open ? wizard!.upcomingDaysJson : null,
        sellerId: sellerId,
      );
      if (result.sellerId != null) {
        await SellerSessionPrefs.saveSellerId(result.sellerId!);
      }
      await KitchenStatusPrefs.cacheDetails(
        open: result.kitchenOpen,
        meals: result.kitchenOpenMeals,
        upcoming: result.upcomingKitchenDays,
      );
      if (!mounted) return;
      setState(() {
        _kitchenOpen = result.kitchenOpen;
        _kitchenOpenMeals = result.kitchenOpenMeals;
        _upcomingKitchenDays = result.upcomingKitchenDays;
        _saving = false;
      });
      _showStatusSnack(result.kitchenOpen, result.message);
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _kitchenOpen = previous;
        _kitchenOpenMeals = previousMeals;
        _upcomingKitchenDays = previousUpcoming;
        _saving = false;
      });
      AppToast.danger(
        context,
        e.message,
        bottomPadding: 100,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _kitchenOpen = previous;
        _kitchenOpenMeals = previousMeals;
        _upcomingKitchenDays = previousUpcoming;
        _saving = false;
      });
      AppToast.danger(
        context,
        'Could not save kitchen status. Try again.',
        bottomPadding: 100,
      );
    }
  }

  Future<void> _openDocumentKyc() async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ??
        await SellerAuthPrefs.phoneE164();
    if (phone == null || phone.isEmpty) {
      if (!mounted) return;
      AppToast.warning(context, 'Sign in required to upload KYC documents.');
      return;
    }
    if (!mounted) return;

    await SellerAuthNavigation.openDocumentKycFlow(
      context,
      phoneE164: phone,
      status: _documentKycStatus,
      documentKyc: _documentKyc,
    );

    if (!mounted) return;
    await _refreshDocumentKycStatus();
  }

  Future<void> _openKitchenSetup() async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ??
        await SellerAuthPrefs.phoneE164();
    if (phone == null || phone.isEmpty) {
      if (!mounted) return;
      AppToast.warning(context, 'Sign in required to set up your kitchen.');
      return;
    }

    final sellerId = await SellerSessionPrefs.sellerId();
    if (sellerId == null) {
      if (!mounted) return;
      AppToast.warning(context, 'Seller account not found. Try signing in again.');
      return;
    }
    if (!mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RegisterSellerScreen(
          phoneE164: phone,
          phoneVerified: true,
          kitchenSetupOnly: true,
          sellerId: sellerId,
        ),
      ),
    );

    if (!mounted) return;
    await _refreshDocumentKycStatus();
  }

  Future<void> _loadUnreadNotifications(
    String phone,
    int? sellerId,
  ) async {
    try {
      final result = await _api.fetchNotifications(
        phoneE164: phone,
        sellerId: sellerId,
      );
      if (mounted) {
        setState(() => _unreadNotifications = result.unreadCount);
      }
    } catch (_) {
      // Badge is optional — ignore fetch errors.
    }
  }

  Future<void> _openNotifications() async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ??
        await SellerAuthPrefs.phoneE164();
    if (phone == null || phone.isEmpty || !mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SellerNotificationsScreen(phoneE164: phone),
      ),
    );

    if (!mounted) return;
    final sellerId = await SellerSessionPrefs.sellerId();
    await _loadUnreadNotifications(phone, sellerId);
  }

  void _openMessages() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SellerMessagesScreen(),
      ),
    );
  }

  Future<void> _refreshDocumentKycStatus() async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ??
        await SellerAuthPrefs.phoneE164();
    if (phone == null || phone.isEmpty) return;

    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final result = await _api.fetchSellerKycStatus(
        phoneE164: phone,
        sellerId: sellerId,
      );
      if (mounted) {
        setState(() {
          _documentKycStatus = result.documentKycStatus;
          _documentKyc = result.documentKyc ??
              SellerDocumentKycInfo(
                status: result.documentKycStatus,
                hasUploads: false,
              );
          _kitchenSetupPending = result.kitchenSetupPending;
        });
      }
    } catch (_) {
      // Keep current banner state if refresh fails.
    }
  }

  void _showStatusSnack(bool open, [String? message]) {
    if (!mounted) return;
    final text = message ??
        (open
            ? 'Kitchen is open — buyers can place orders'
            : 'Kitchen is off — orders paused');
    if (open) {
      AppToast.success(context, text, bottomPadding: 100);
    } else {
      AppToast.success(
        context,
        text,
        bottomPadding: 100,
        background: AppColors.kitchenOff,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _dashboard.stats;
    final pending = _dashboard.pendingOrders;

    return RefreshIndicator(
      color: AppColors.brandPurple,
      onRefresh: _refreshAll,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                AppSystemUi.topInset(context, 8),
                24,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_greeting()}, Chef',
                              style: GoogleFonts.exo2(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color:
                                    AppColors.deepGreen.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _dashboard.kitchenName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.exo2(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppColors.deepGreen,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _DashboardHeaderIconButton(
                            icon: Icons.notifications_outlined,
                            badgeCount: _unreadNotifications,
                            onTap: _openNotifications,
                          ),
                          const SizedBox(width: 4),
                          _DashboardHeaderIconButton(
                            icon: Icons.chat_bubble_outline_rounded,
                            onTap: _openMessages,
                          ),
                          const SizedBox(width: 4),
                          _DashboardHeaderIconButton(
                            icon: Icons.keyboard_arrow_down_rounded,
                            badgeCount: _resolvedPendingCount(),
                            onTap: _openOverviewSheet,
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_loadError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _loadError!,
                      style: GoogleFonts.exo2(
                        fontSize: 12,
                        color: AppColors.terracotta,
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_documentKycStatus.needsBanner) ...[
                    _DocumentKycAlertCard(
                      status: _documentKycStatus,
                      onTap: _openDocumentKyc,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_kitchenSetupPending) ...[
                    _KitchenSetupAlertCard(onTap: _openKitchenSetup),
                    const SizedBox(height: 12),
                  ],
                  _HeroCard(
                    isOpen: _kitchenOpen,
                    openMeals: _kitchenOpenMeals,
                    earningsToday: stats.earningsToday,
                    activeOrders: stats.activeOrders,
                    loading: _dashboardLoading,
                    statusLoading: !_loaded,
                    saving: _saving,
                    onKitchenOpenChanged: _setKitchenOpen,
                  ),
                  if (pending.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _PendingOrdersAlertBanner(
                      count: pending.length,
                      onTap: widget.onViewOrders,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Pending orders',
                            style: GoogleFonts.exo2(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepGreen,
                            ),
                          ),
                        ),
                        if (pending.length > 1)
                          TextButton(
                            onPressed: widget.onViewOrders,
                            child: Text(
                              'View all',
                              style: GoogleFonts.exo2(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandPurple,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final order in pending)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PendingOrderCard(
                          order: order,
                          onTap: () {
                            if (widget.onViewOrderDetail != null) {
                              widget.onViewOrderDetail!(order.id);
                            } else {
                              widget.onViewOrders?.call();
                            }
                          },
                        ),
                      ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'Today at a glance',
                    style: GoogleFonts.exo2(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepGreen,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.08,
              ),
              delegate: SliverChildListDelegate([
                _StatTile(
                  icon: Icons.receipt_long_rounded,
                  label: 'Orders today',
                  value: _dashboardLoading ? '…' : '${stats.ordersToday}',
                  subtitle: stats.activeOrders > 0
                      ? '${stats.activeOrders} active'
                      : stats.completedToday > 0
                          ? '${stats.completedToday} done'
                          : null,
                  accent: AppColors.brandPurple,
                ),
                _StatTile(
                  icon: Icons.payments_rounded,
                  label: 'Earned today',
                  value: _dashboardLoading
                      ? '…'
                      : formatInr(stats.earningsToday),
                  subtitle: stats.earningsWeek > 0
                      ? '${formatInr(stats.earningsWeek)} this week'
                      : null,
                  accent: AppColors.terracotta,
                ),
                _StatTile(
                  icon: Icons.restaurant_menu_rounded,
                  label: 'Menu dishes',
                  value: _dashboardLoading ? '…' : '${stats.dishesCount}',
                  subtitle: stats.dishesAvailable > 0
                      ? '${stats.dishesAvailable} available'
                      : 'Add dishes to menu',
                  accent: AppColors.sage,
                ),
                _StatTile(
                  icon: Icons.star_rounded,
                  label: 'Rating',
                  value: _dashboardLoading ? '…' : stats.ratingLabel,
                  subtitle: stats.ratingCount > 0
                      ? '${stats.ratingCount} reviews'
                      : 'No reviews yet',
                  accent: AppColors.amberGlow,
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Performance',
                    style: GoogleFonts.exo2(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepGreen,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PerformanceRow(
                    loading: _dashboardLoading,
                    completedToday: stats.completedToday,
                    earningsTotal: stats.earningsTotal,
                    activeOrders: stats.activeOrders,
                  ),
                  const SizedBox(height: 20),
                  WeeklyEarningsChart(
                    days: _dashboard.weeklyEarnings.isNotEmpty
                        ? _dashboard.weeklyEarnings
                        : parseWeeklyEarnings(null, stats),
                    weekTotal: stats.earningsWeek,
                    loading: _dashboardLoading,
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 130)),
        ],
      ),
    );
  }
}

class _DashboardHeaderIconButton extends StatelessWidget {
  const _DashboardHeaderIconButton({
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.brandPurple.withValues(alpha: 0.14),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: AppColors.brandPurple,
              ),
              if (badgeCount > 0)
                Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(
                      color: AppColors.kitchenOff,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                    child: Text(
                      badgeCount > 9 ? '9+' : '$badgeCount',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.exo2(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
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

class _DocumentKycAlertCard extends StatelessWidget {
  const _DocumentKycAlertCard({
    required this.status,
    required this.onTap,
  });

  final SellerDocumentKycStatusKind status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pending = status == SellerDocumentKycStatusKind.pending;
    final rejected = status == SellerDocumentKycStatusKind.rejected;

    final title = pending
        ? 'KYC verification in progress'
        : rejected
            ? 'KYC rejected'
            : 'Complete your KYC';

    final subtitle = pending
        ? 'We are reviewing your Aadhaar and FSSAI. Tap to view or re-upload.'
        : rejected
            ? 'Tap to try again — upload Aadhaar and FSSAI documents.'
            : 'Upload your Aadhaar card and FSSAI license to verify your kitchen.';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                AppColors.kitchenOff,
                AppColors.kitchenOffDeep,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.kitchenOff.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  pending
                      ? Icons.hourglass_top_rounded
                      : rejected
                          ? Icons.refresh_rounded
                          : Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.exo2(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.exo2(
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.9),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KitchenSetupAlertCard extends StatelessWidget {
  const _KitchenSetupAlertCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [
                AppColors.brandPurple,
                AppColors.brandPurpleDeep,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandPurple.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set up your kitchen profile',
                      style: GoogleFonts.exo2(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add your kitchen name, logo, cuisines, and delivery times.',
                      style: GoogleFonts.exo2(
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.9),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.isOpen,
    this.openMeals = const [],
    this.earningsToday = 0,
    this.activeOrders = 0,
    this.loading = false,
    this.statusLoading = false,
    this.saving = false,
    required this.onKitchenOpenChanged,
  });

  final bool isOpen;
  final List<String> openMeals;
  final double earningsToday;
  final int activeOrders;
  final bool loading;
  final bool statusLoading;
  final bool saving;
  final ValueChanged<bool> onKitchenOpenChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isOpen
              ? [AppColors.kitchenOpen, AppColors.kitchenOpenDeep]
              : [AppColors.kitchenOff, AppColors.kitchenOffDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: (isOpen ? AppColors.kitchenOpen : AppColors.kitchenOff)
                .withValues(alpha: 0.38),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isOpen
                            ? const Color(0xFF4ADE80)
                            : Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: isOpen
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                ),
                              ],
                      ),
                    ),
                    Text(
                      isOpen ? 'Kitchen is live' : 'Kitchen is off',
                      style: GoogleFonts.exo2(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isOpen
                      ? (kitchenOpenMealsLabel(openMeals).isNotEmpty
                          ? 'Open for ${kitchenOpenMealsLabel(openMeals)} — buyers can place orders.'
                          : 'Buyers can browse your menu and place orders.')
                      : 'Flip the switch when you are ready to take orders.',
                  style: GoogleFonts.exo2(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
                if (!loading && (earningsToday > 0 || activeOrders > 0)) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (earningsToday > 0)
                        _HeroMetric(
                          icon: Icons.currency_rupee_rounded,
                          label: formatInr(earningsToday),
                          caption: 'today',
                        ),
                      if (earningsToday > 0 && activeOrders > 0)
                        const SizedBox(width: 16),
                      if (activeOrders > 0)
                        _HeroMetric(
                          icon: Icons.local_shipping_outlined,
                          label: '$activeOrders',
                          caption: activeOrders == 1 ? 'active order' : 'active',
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          KitchenLiveToggleDock(
            isOpen: isOpen,
            onChanged: onKitchenOpenChanged,
            enabled: !saving,
            loading: statusLoading || saving,
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.label,
    required this.caption,
  });

  final IconData icon;
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.85)),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.exo2(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          caption,
          style: GoogleFonts.exo2(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}

class _PendingOrdersAlertBanner extends StatelessWidget {
  const _PendingOrdersAlertBanner({
    required this.count,
    this.onTap,
  });

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                AppColors.orderPending,
                AppColors.orderPending.withValues(alpha: 0.88),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.orderPending.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.bootstrapWarningText.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pending_actions_rounded,
                  color: AppColors.bootstrapWarningText,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 1
                          ? '1 order needs your attention'
                          : '$count orders need your attention',
                      style: GoogleFonts.exo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.bootstrapWarningText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to review and accept pending orders',
                      style: GoogleFonts.exo2(
                        fontSize: 12,
                        color: AppColors.bootstrapWarningText.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.bootstrapWarningText.withValues(alpha: 0.85),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingOrderCard extends StatelessWidget {
  const _PendingOrderCard({
    required this.order,
    this.onTap,
  });

  final SellerPendingOrder order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.orderPending.withValues(alpha: 0.45),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.orderPending.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bootstrapWarningBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.statusLabel,
                      style: GoogleFonts.exo2(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.bootstrapWarningText,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    order.placedAtHuman,
                    style: GoogleFonts.exo2(
                      fontSize: 11,
                      color: AppColors.deepGreen.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                order.displayNumber,
                style: GoogleFonts.exo2(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepGreen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                order.itemsSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.exo2(
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.deepGreen.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (order.deliverySlotLabel.isNotEmpty) ...[
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppColors.brandPurple.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.deliverySlotLabel,
                        style: GoogleFonts.exo2(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandPurple,
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  Text(
                    formatInr(order.kitchenTotal),
                    style: GoogleFonts.exo2(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.terracotta,
                    ),
                  ),
                ],
              ),
              if (order.paymentLabel.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  order.paymentLabel,
                  style: GoogleFonts.exo2(
                    fontSize: 11,
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

class _PerformanceRow extends StatelessWidget {
  const _PerformanceRow({
    required this.loading,
    required this.completedToday,
    required this.earningsTotal,
    required this.activeOrders,
  });

  final bool loading;
  final int completedToday;
  final double earningsTotal;
  final int activeOrders;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PerformanceTile(
            icon: Icons.check_circle_outline_rounded,
            label: 'Completed',
            value: loading ? '…' : '$completedToday',
            caption: 'today',
            color: AppColors.sage,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PerformanceTile(
            icon: Icons.trending_up_rounded,
            label: 'Lifetime',
            value: loading ? '…' : formatInr(earningsTotal),
            caption: 'earnings',
            color: AppColors.terracotta,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PerformanceTile(
            icon: Icons.local_fire_department_outlined,
            label: 'In kitchen',
            value: loading ? '…' : '$activeOrders',
            caption: 'active now',
            color: AppColors.brandPurple,
          ),
        ),
      ],
    );
  }
}

class _PerformanceTile extends StatelessWidget {
  const _PerformanceTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.exo2(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.deepGreen,
            ),
          ),
          Text(
            caption,
            style: GoogleFonts.exo2(
              fontSize: 10,
              color: AppColors.deepGreen.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent.withValues(alpha: 0.2),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.exo2(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepGreen,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.exo2(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepGreen.withValues(alpha: 0.55),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.exo2(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: accent.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
