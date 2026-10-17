import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../seller_auth_prefs.dart';
import '../seller_session_prefs.dart';
import '../services/optica2_api.dart';
import '../services/seller_auth_navigation.dart';
import '../services/seller_push_service.dart';
import '../theme/app_colors.dart';
import '../widgets/kitchen_blocked_overlay.dart';
import '../widgets/seller_bottom_nav.dart';
import 'home/seller_dashboard_tab.dart';
import 'home/seller_kitchen_tab.dart';
import 'home/seller_menu_tab.dart';
import 'home/seller_orders_tab.dart';
import 'home/seller_profile_tab.dart';

/// Main seller shell after KYC approval — fixed full-width bottom navigation.
class SellerHomeScreen extends StatefulWidget {
  const SellerHomeScreen({super.key, this.skipKycGuard = false});

  final bool skipKycGuard;

  @override
  State<SellerHomeScreen> createState() => _SellerHomeScreenState();
}

class _SellerHomeScreenState extends State<SellerHomeScreen> {
  final _optica2 = Optica2Api();
  final _menuTabKey = GlobalKey<SellerMenuTabState>();
  final _ordersTabKey = GlobalKey<SellerOrdersTabState>();
  final _dashboardTabKey = GlobalKey<SellerDashboardTabState>();
  bool _checking = true;
  bool _kitchenBlocked = false;
  String _kitchenBlockedMessage =
      'Your kitchen has been blocked. Please contact the administrator.';
  int _navIndex = 0;
  int _ordersBadge = 0;
  int? _openOrderId;

  static const _centerNavIndex = 2;
  static const _ordersNavIndex = 1;

  List<SellerNavItem> get _navItems => [
        const SellerNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
        ),
        SellerNavItem(
          icon: Icons.receipt_long_outlined,
          activeIcon: Icons.receipt_long_rounded,
          label: 'Orders',
          badge: _ordersBadge > 0 ? _ordersBadge : null,
        ),
        const SellerNavItem(
          icon: Icons.restaurant_menu_outlined,
          activeIcon: Icons.restaurant_menu_rounded,
          label: 'Menu',
        ),
        const SellerNavItem(
          icon: Icons.soup_kitchen_outlined,
          activeIcon: Icons.soup_kitchen_rounded,
          label: 'Kitchen',
        ),
        const SellerNavItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Profile',
        ),
      ];

  @override
  void initState() {
    super.initState();
    _guardKyc();
  }

  @override
  void dispose() {
    _optica2.close();
    super.dispose();
  }

  Future<void> _registerPush(String phoneE164) async {
    final sellerId = await SellerSessionPrefs.sellerId();
    await SellerPushService.registerDevice(
      api: _optica2,
      phoneE164: phoneE164,
      sellerId: sellerId,
    );
  }

  Future<void> _guardKyc() async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ??
        await SellerAuthPrefs.phoneE164();

    if (widget.skipKycGuard) {
      if (phone != null && phone.isNotEmpty) {
        await _registerPush(phone);
      }
      if (mounted) setState(() => _checking = false);
      return;
    }

    if (phone == null || phone.isEmpty) {
      if (mounted) setState(() => _checking = false);
      return;
    }

    try {
      final result = await _optica2.checkSellerPhone(phone);
      if (!mounted) return;
      if (result.sellerId != null) {
        await SellerSessionPrefs.saveSellerId(result.sellerId!);
      }

      if (SellerAuthNavigation.needsKycForm(result)) {
        SellerAuthNavigation.openKyc(
          context,
          sellerId: result.sellerId!,
          phoneE164: phone,
          resumeToHomeOnComplete: true,
        );
        return;
      }

      if (SellerAuthNavigation.isAwaitingKycApproval(result)) {
        SellerAuthNavigation.openKycPending(
          context,
          sellerId: result.sellerId!,
          phoneE164: phone,
          message: result.message,
        );
        return;
      }

      if (result.kitchenBlocked) {
        if (mounted) {
          setState(() {
            _kitchenBlocked = true;
            _kitchenBlockedMessage = result.message;
            _checking = false;
          });
        }
        await _registerPush(phone);
        return;
      }

      try {
        final sellerId = await SellerSessionPrefs.sellerId();
        final status = await _optica2.fetchKitchenStatus(
          phoneE164: phone,
          sellerId: sellerId,
        );
        if (status.kitchenBlocked && mounted) {
          setState(() {
            _kitchenBlocked = true;
            _kitchenBlockedMessage = status.message != 'OK'
                ? status.message
                : _kitchenBlockedMessage;
          });
        }
      } catch (_) {
        // Offline — rely on check-phone flag only.
      }
    } catch (_) {
      // Stay on home when check fails offline.
    }

    await _registerPush(phone);
    if (mounted) setState(() => _checking = false);
  }

  void _viewPendingOrders() {
    _ordersTabKey.currentState?.showPendingOrders();
    _onNavChanged(_ordersNavIndex);
  }

  void _viewDeliveredOrders() {
    _ordersTabKey.currentState?.showDeliveredOrders();
    _onNavChanged(_ordersNavIndex);
  }

  void _onNavChanged(int index) {
    if (index == _navIndex) return;
    HapticFeedback.lightImpact();
    setState(() => _navIndex = index);
    if (index == _ordersNavIndex) {
      _ordersTabKey.currentState?.reload();
    }
  }

  void _viewOrder(int orderId) {
    setState(() {
      _openOrderId = orderId;
      _navIndex = _ordersNavIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.brandPurple),
        ),
      );
    }

    if (_kitchenBlocked) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        body: KitchenBlockedOverlay(message: _kitchenBlockedMessage),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.cream,
      extendBody: true,
      body: IndexedStack(
        index: _navIndex,
        children: [
          SellerDashboardTab(
            key: _dashboardTabKey,
            onPendingOrdersCountChanged: (count) {
              if (_ordersBadge != count) {
                setState(() => _ordersBadge = count);
              }
            },
            onViewOrders: _viewPendingOrders,
            onViewDeliveredOrders: _viewDeliveredOrders,
            onViewOrderDetail: _viewOrder,
            onViewMenu: () {
              _onNavChanged(_centerNavIndex);
              _menuTabKey.currentState?.reload();
            },
          ),
          SellerOrdersTab(
            key: _ordersTabKey,
            isActive: _navIndex == _ordersNavIndex,
            openOrderId: _openOrderId,
            onOrderChanged: () => _dashboardTabKey.currentState?.reload(),
            onOpenOrderHandled: () {
              if (_openOrderId != null) {
                setState(() => _openOrderId = null);
              }
            },
          ),
          SellerMenuTab(key: _menuTabKey),
          SellerKitchenTab(
            onViewMenu: () {
              _onNavChanged(_centerNavIndex);
              _menuTabKey.currentState?.reload();
            },
          ),
          const SellerProfileTab(),
        ],
      ),
      bottomNavigationBar: SellerBottomNav(
        currentIndex: _navIndex,
        items: _navItems,
        centerIndex: _centerNavIndex,
        onChanged: _onNavChanged,
      ),
    );
  }
}
