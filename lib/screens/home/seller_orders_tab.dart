import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/seller_order.dart';
import '../../seller_auth_prefs.dart';
import '../../seller_session_prefs.dart';
import '../../services/optica2_api.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_system_ui.dart';
import '../../widgets/app_toast.dart';
import '../seller_order_detail_screen.dart';

class SellerOrdersTab extends StatefulWidget {
  const SellerOrdersTab({
    super.key,
    this.openOrderId,
    this.onOpenOrderHandled,
    this.onOrderChanged,
    this.isActive = false,
  });

  final int? openOrderId;
  final VoidCallback? onOpenOrderHandled;
  final VoidCallback? onOrderChanged;
  final bool isActive;

  @override
  State<SellerOrdersTab> createState() => SellerOrdersTabState();
}

class SellerOrdersTabState extends State<SellerOrdersTab> {
  final _api = Optica2Api();
  bool _loading = true;
  SellerOrderFilter _filter = SellerOrderFilter.all;
  List<SellerOrder> _orders = const [];
  int? _lastOpenedOrderId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant SellerOrdersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _load();
    }
    if (widget.openOrderId != null &&
        widget.openOrderId != oldWidget.openOrderId) {
      _maybeOpenOrder(widget.openOrderId!);
    }
  }

  /// Opens the Orders tab filtered to pending — call before switching nav index.
  void showPendingOrders() {
    if (_filter != SellerOrderFilter.pending) {
      setState(() => _filter = SellerOrderFilter.pending);
    }
    _load();
  }

  /// Opens the Orders tab filtered to delivered — call before switching nav index.
  void showDeliveredOrders() {
    if (_filter != SellerOrderFilter.delivered) {
      setState(() => _filter = SellerOrderFilter.delivered);
    }
    _load();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);

    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ??
        await SellerAuthPrefs.phoneE164();
    if (phone == null || phone.isEmpty) {
      if (mounted) setState(() => _loading = false);
      // Auth may not be ready on first IndexedStack build — retry shortly.
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (mounted && _orders.isEmpty && !_loading) _load();
      });
      return;
    }

    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final orders = await _api.fetchOrders(
        phoneE164: phone,
        sellerId: sellerId,
        filter: _filter,
      );
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
      if (widget.openOrderId != null) {
        await _maybeOpenOrder(widget.openOrderId!);
      }
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.danger(context, e.message, bottomPadding: 100);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppToast.danger(
          context,
          e is Optica2ApiException
              ? e.message
              : 'Could not load orders.',
          bottomPadding: 100,
        );
      }
    }
  }

  Future<void> _maybeOpenOrder(int orderId) async {
    if (_lastOpenedOrderId == orderId) return;
    _lastOpenedOrderId = orderId;

    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ??
        await SellerAuthPrefs.phoneE164();
    if (phone == null || phone.isEmpty || !mounted) return;

    final sellerId = await SellerSessionPrefs.sellerId();
    if (!mounted) return;
    final changed = await openSellerOrderDetail(
      context,
      phoneE164: phone,
      orderId: orderId,
      sellerId: sellerId,
      api: _api,
    );
    if (changed && mounted) {
      await _load();
      widget.onOrderChanged?.call();
    }
    widget.onOpenOrderHandled?.call();
  }

  Future<void> _openOrder(SellerOrder order) async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ??
        await SellerAuthPrefs.phoneE164();
    if (phone == null || phone.isEmpty || !mounted) return;

    final sellerId = await SellerSessionPrefs.sellerId();
    if (!mounted) return;
    final changed = await openSellerOrderDetail(
      context,
      phoneE164: phone,
      orderId: order.id,
      sellerId: sellerId,
      api: _api,
    );
    if (changed && mounted) {
      await _load();
      widget.onOrderChanged?.call();
    }
  }

  void _setFilter(SellerOrderFilter filter) {
    if (_filter == filter) return;
    setState(() => _filter = filter);
    _load();
  }

  Color _filterChipColor(SellerOrderFilter filter) {
    return switch (filter) {
      SellerOrderFilter.pending => AppColors.orderPending,
      SellerOrderFilter.accepted => AppColors.sage,
      SellerOrderFilter.readyToPickUp => AppColors.brandPurple,
      SellerOrderFilter.pickedUp => AppColors.sage,
      SellerOrderFilter.onWay => AppColors.terracotta,
      SellerOrderFilter.delivered => AppColors.kitchenOpen,
      SellerOrderFilter.cancelled => AppColors.kitchenOff,
      SellerOrderFilter.all => AppColors.brandPurple,
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'pending' => AppColors.orderPending,
      'accepted' => AppColors.sage,
      'ready_to_pick_up' => AppColors.brandPurple,
      'picked_up' => AppColors.sage,
      'on_way' => AppColors.terracotta,
      'delivered' => AppColors.kitchenOpen,
      'cancelled' => AppColors.kitchenOff,
      _ => AppColors.deepGreen,
    };
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.brandPurple,
      onRefresh: _load,
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
                  Text(
                    'Orders',
                    style: GoogleFonts.exo2(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepGreen,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _loading
                        ? 'Loading…'
                        : '${_orders.length} ${_orders.length == 1 ? 'order' : 'orders'}',
                    style: GoogleFonts.exo2(
                      fontSize: 14,
                      color: AppColors.deepGreen.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final filter in SellerOrderFilter.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(
                                filter.label,
                                style: GoogleFonts.exo2(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _filter == filter
                                      ? (filter == SellerOrderFilter.pending
                                          ? AppColors.bootstrapWarningText
                                          : Colors.white)
                                      : AppColors.deepGreen,
                                ),
                              ),
                              selected: _filter == filter,
                              onSelected: (_) => _setFilter(filter),
                              selectedColor: _filterChipColor(filter),
                              backgroundColor: Colors.white,
                              checkmarkColor: Colors.white,
                              side: BorderSide(
                                color: _filter == filter
                                    ? _filterChipColor(filter)
                                    : _filterChipColor(filter)
                                        .withValues(alpha: 0.22),
                              ),
                              showCheckmark: false,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          if (_loading && _orders.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.brandPurple),
              ),
            )
          else if (_orders.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.brandPurple.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          size: 48,
                          color: AppColors.brandPurple.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _filter == SellerOrderFilter.all
                            ? 'No orders yet'
                            : 'No ${_filter.label.toLowerCase()} orders',
                        style: GoogleFonts.exo2(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'New orders from buyers will appear here.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.exo2(
                          fontSize: 14,
                          height: 1.45,
                          color: AppColors.deepGreen.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final order = _orders[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _OrderListCard(
                        order: order,
                        statusColor: _statusColor(order.status),
                        onTap: () => _openOrder(order),
                      ),
                    );
                  },
                  childCount: _orders.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 130)),
        ],
      ),
    );
  }
}

class _OrderListCard extends StatelessWidget {
  const _OrderListCard({
    required this.order,
    required this.statusColor,
    required this.onTap,
  });

  final SellerOrder order;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final needsAction = order.status == 'pending' ||
        order.status == 'accepted' ||
        order.status == 'ready_to_pick_up';
    final statusTextColor = order.status == 'pending'
        ? AppColors.bootstrapWarningText
        : statusColor;

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
              color: needsAction
                  ? statusColor.withValues(alpha: 0.45)
                  : statusColor.withValues(alpha: 0.18),
              width: needsAction ? 1.5 : 1,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.statusLabel,
                      style: GoogleFonts.exo2(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusTextColor,
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.displayNumber,
                          style: GoogleFonts.exo2(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.deepGreen,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.deliverySlotLabel.isNotEmpty
                              ? order.deliverySlotLabel
                              : order.paymentLabel,
                          style: GoogleFonts.exo2(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.deepGreen.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatOrderAmount(order.kitchenTotal),
                    style: GoogleFonts.exo2(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.terracotta,
                    ),
                  ),
                ],
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
              if (order.deliverySlotLabel.isNotEmpty ||
                  order.paymentLabel.isNotEmpty) ...[
                const SizedBox(height: 10),
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
                    ],
                    if (order.paymentLabel.isNotEmpty)
                      Text(
                        order.paymentLabel,
                        style: GoogleFonts.exo2(
                          fontSize: 11,
                          color: AppColors.deepGreen.withValues(alpha: 0.45),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'View details',
                    style: GoogleFonts.exo2(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandPurple,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.brandPurple,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
