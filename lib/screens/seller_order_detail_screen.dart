import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/optica2_asset_url.dart';
import '../../models/seller_order.dart';
import '../../services/optica2_api.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_system_ui.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/seller_order_status_timeline.dart';
import '../../widgets/swipe_to_confirm_button.dart';
import 'seller_help_support_screen.dart';

class SellerOrderDetailScreen extends StatefulWidget {
  const SellerOrderDetailScreen({
    super.key,
    required this.order,
    required this.phoneE164,
    this.sellerId,
  });

  final SellerOrderDetail order;
  final String phoneE164;
  final int? sellerId;

  @override
  State<SellerOrderDetailScreen> createState() =>
      _SellerOrderDetailScreenState();
}

class _SellerOrderDetailScreenState extends State<SellerOrderDetailScreen>
    with SingleTickerProviderStateMixin {
  final _api = Optica2Api();
  late SellerOrderDetail _order;
  late final AnimationController _confettiController;
  bool _changed = false;
  bool _saving = false;
  bool _deliveryCelebrated = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeCelebrateDelivered(null, _order.status);
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _api.close();
    super.dispose();
  }

  void _setOrder(SellerOrderDetail updated) {
    final previousStatus = _order.status;

    setState(() {
      _order = updated;
      _changed = true;
      _saving = false;
    });

    _maybeCelebrateDelivered(previousStatus, updated.status);
  }

  void _maybeCelebrateDelivered(String? previousStatus, String nextStatus) {
    if (nextStatus != 'delivered' || _deliveryCelebrated) return;
    if (previousStatus == 'delivered') return;

    _deliveryCelebrated = true;
    _confettiController.forward(from: 0);
  }

  Color _statusColor() {
    return switch (_order.status) {
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

  Future<void> _acceptOrder() async {
    if (_saving || !_order.canAccept) return;

    setState(() => _saving = true);
    try {
      final updated = await _api.acceptOrder(
        phoneE164: widget.phoneE164,
        orderId: _order.id,
        sellerId: widget.sellerId,
      );
      if (!mounted) return;
      _setOrder(updated);
      AppToast.success(context, 'Order accepted', bottomPadding: 100);
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.danger(context, e.message, bottomPadding: 100);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.danger(
        context,
        'Could not accept order.',
        bottomPadding: 100,
      );
    }
  }

  Future<void> _markReady() async {
    if (_saving || !_order.canMarkReady) return;

    setState(() => _saving = true);

    try {
      final updated = await _api.markOrderReady(
        phoneE164: widget.phoneE164,
        orderId: _order.id,
        sellerId: widget.sellerId,
      );
      if (!mounted) return;
      _setOrder(updated);
      final dispatchError = updated.deliveryPartner?.dispatchError?.message;
      if (dispatchError != null && dispatchError.isNotEmpty) {
        AppToast.warning(
          context,
          'Order is ready, but Adloggs dispatch failed: $dispatchError',
          bottomPadding: 100,
        );
      } else {
        AppToast.success(
          context,
          'Order marked ready for pickup',
          bottomPadding: 100,
        );
      }
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.danger(context, e.message, bottomPadding: 100);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.danger(
        context,
        'Could not update order status.',
        bottomPadding: 100,
      );
    }
  }

  Future<void> _markPickedUp() async {
    if (_saving || !_order.canMarkPickedUp) return;

    setState(() => _saving = true);

    try {
      final updated = await _api.markOrderPickedUp(
        phoneE164: widget.phoneE164,
        orderId: _order.id,
        sellerId: widget.sellerId,
      );
      if (!mounted) return;
      _setOrder(updated);
      AppToast.success(
        context,
        'Order marked picked up',
        bottomPadding: 100,
      );
      final pickupSyncError = updated.deliveryPartner?.pickupSyncError?.message;
      if (pickupSyncError != null && pickupSyncError.isNotEmpty) {
        AppToast.warning(
          context,
          'Adloggs pickup not confirmed yet: $pickupSyncError',
          bottomPadding: 100,
        );
      }
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.danger(context, e.message, bottomPadding: 100);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.danger(
        context,
        'Could not mark order picked up.',
        bottomPadding: 100,
      );
    }
  }

  Color _orderActionTrackColor() {
    if (_order.canAccept) return AppColors.kitchenOpen;
    if (_order.canMarkReady) return AppColors.brandPurple;
    if (_order.canMarkPickedUp) return AppColors.sage;
    return AppColors.deepGreen;
  }

  void _onOrderActionConfirmed() {
    if (_order.canAccept) {
      _acceptOrder();
    } else if (_order.canMarkReady) {
      _markReady();
    } else if (_order.canMarkPickedUp && !_order.hasDispatchFailure) {
      _markPickedUp();
    }
  }

  Future<void> _chatWithAdmin() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final help = await _api.fetchSellerHelpSupport();
      if (!mounted) return;

      final dispatchError =
          _order.deliveryPartner?.dispatchError?.message ?? 'Dispatch failed';
      final message =
          'Hi, I need help with order ${_order.displayNumber}. '
          'Adloggs delivery dispatch failed: $dispatchError';

      Future<bool> open(Uri uri) =>
          launchUrl(uri, mode: LaunchMode.externalApplication);

      if (help.whatsapp.isNotEmpty) {
        final digits = help.whatsapp.replaceAll(RegExp(r'\D'), '');
        if (digits.isNotEmpty &&
            await open(
              Uri.parse(
                'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
              ),
            )) {
          return;
        }
      }

      if (help.phone.isNotEmpty) {
        final digits = help.phone.replaceAll(RegExp(r'[^\d+]'), '');
        if (digits.isNotEmpty && await open(Uri(scheme: 'tel', path: digits))) {
          return;
        }
      }

      if (help.email.isNotEmpty &&
          await open(
            Uri(
              scheme: 'mailto',
              path: help.email,
              query: 'subject=${Uri.encodeComponent('Dispatch failed — ${_order.displayNumber}')}'
                  '&body=${Uri.encodeComponent(message)}',
            ),
          )) {
        return;
      }

      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SellerHelpSupportScreen(initialContent: help),
        ),
      );
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      AppToast.danger(context, e.message, bottomPadding: 100);
    } catch (_) {
      if (!mounted) return;
      AppToast.danger(
        context,
        'Could not open support contact.',
        bottomPadding: 100,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _pop() => Navigator.of(context).pop(_changed);

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          backgroundColor: AppColors.cream,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: const IconThemeData(color: AppColors.deepGreen),
          leading: BackButton(onPressed: _pop),
          title: Text(
            _order.displayNumber,
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w800,
              color: AppColors.deepGreen,
            ),
          ),
        ),
        bottomNavigationBar: _order.hasBottomBarAction
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: _order.showChatWithAdminAction
                      ? _ChatWithAdminButton(
                          loading: _saving,
                          onPressed: _saving ? null : _chatWithAdmin,
                        )
                      : SwipeToConfirmButton(
                          key: ValueKey(_order.status),
                          label: _order.orderActionSwipeLabel,
                          loadingLabel: _order.orderActionLoadingLabel,
                          trackColor: _orderActionTrackColor(),
                          loading: _saving,
                          enabled: !_saving,
                          onConfirmed: _onOrderActionConfirmed,
                        ),
                ),
              )
            : null,
        body: Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(
                24,
                0,
                24,
                AppSystemUi.bottomInset(
                  context,
                  _order.hasBottomBarAction ? 88 : 24,
                ),
              ),
              children: [
                _StatusHeader(
                  order: _order,
                  statusColor: statusColor,
                ),
                const SizedBox(height: 16),
                if (_order.displayStatusTimeline.isNotEmpty)
                  SellerOrderStatusTimeline(
                    steps: _order.displayStatusTimeline,
                    currentIndex: _order.displayStatusStepIndex,
                    accentColor: statusColor,
                    deliveredActiveSubtitle:
                        'Congratulations, you have earned ${formatOrderAmount(_order.kitchenTotal)}',
                    isCancelled: _order.isCancelled,
                  ),
                if (_order.displayStatusTimeline.isNotEmpty)
                  const SizedBox(height: 16),
                _SectionCard(
                  title: 'Delivery',
                  icon: Icons.location_on_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_order.deliverySlotLabel.isNotEmpty)
                        Text(
                          _order.deliverySlotLabel,
                          style: GoogleFonts.exo2(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandPurple,
                          ),
                        ),
                      if (_order.deliveryTimeLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _order.deliveryTimeLabel,
                          style: GoogleFonts.exo2(
                            fontSize: 13,
                            color: AppColors.deepGreen.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_order.deliveryPartner != null &&
                    (_order.deliveryPartner!.hasRider ||
                        _order.deliveryPartner!.hasDispatchError ||
                        _order.status == 'ready_to_pick_up' ||
                        _order.status == 'picked_up' ||
                        _order.status == 'on_way')) ...[
                  const SizedBox(height: 12),
                  _DeliveryPartnerCard(partner: _order.deliveryPartner!),
                ],
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Items (${_order.itemCount})',
                  icon: Icons.restaurant_rounded,
                  child: Column(
                    children: [
                      for (var i = 0; i < _order.items.length; i++) ...[
                        if (i > 0) const Divider(height: 20),
                        _OrderLineItemRow(item: _order.items[i]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Payment',
                  icon: Icons.payments_outlined,
                  child: Column(
                    children: [
                      _InfoRow(
                        label: 'Method',
                        value: _order.paymentLabel,
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        label: 'Status',
                        value: _order.paymentStatus.isNotEmpty
                            ? _order.paymentStatus.toUpperCase()
                            : '—',
                      ),
                      const Divider(height: 24),
                      _InfoRow(
                        label: 'Kitchen total',
                        value: formatOrderAmount(_order.kitchenTotal),
                        valueStyle: GoogleFonts.exo2(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.terracotta,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_order.notes != null && _order.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Order notes',
                    icon: Icons.sticky_note_2_outlined,
                    child: Text(
                      _order.notes!.trim(),
                      style: GoogleFonts.exo2(
                        fontSize: 14,
                        height: 1.45,
                        color: AppColors.deepGreen.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Placed ${_order.placedAtHuman}'
                  '${_order.updatedAtHuman.isNotEmpty ? ' · Updated ${_order.updatedAtHuman}' : ''}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.exo2(
                    fontSize: 12,
                    color: AppColors.deepGreen.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: _ConfettiOverlay(animation: _confettiController),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfettiOverlay extends StatelessWidget {
  const _ConfettiOverlay({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        if (animation.value == 0 || animation.value == 1) {
          return const SizedBox.shrink();
        }

        return CustomPaint(
          painter: _ConfettiPainter(animation.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.progress);

  final double progress;

  static const _colors = [
    AppColors.kitchenOpen,
    AppColors.brandPurple,
    AppColors.terracotta,
    AppColors.amberGlow,
    AppColors.sage,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final eased = Curves.easeOutCubic.transform(progress.clamp(0, 1));
    final fade = (1 - progress).clamp(0.0, 1.0);
    final random = math.Random(24);

    for (var i = 0; i < 86; i++) {
      final startX = random.nextDouble() * size.width;
      final drift = (random.nextDouble() - 0.5) * size.width * 0.55;
      final speed = 0.55 + random.nextDouble() * 0.8;
      final x = startX + drift * eased;
      final y = -40 + (size.height + 140) * ((progress * speed) % 1.0);
      final pieceSize = 5 + random.nextDouble() * 8;
      final rotation = (progress * math.pi * 5) + random.nextDouble() * math.pi;
      final paint = Paint()
        ..color = _colors[i % _colors.length].withValues(alpha: fade);

      canvas
        ..save()
        ..translate(x, y)
        ..rotate(rotation);

      if (i.isEven) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: pieceSize * 0.75,
              height: pieceSize * 1.5,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, pieceSize * 0.45, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({
    required this.order,
    required this.statusColor,
  });

  final SellerOrderDetail order;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            statusColor,
            statusColor.withValues(alpha: 0.82),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              order.statusLabel,
              style: GoogleFonts.exo2(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            formatOrderAmount(order.kitchenTotal),
            style: GoogleFonts.exo2(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'} for your kitchen',
            style: GoogleFonts.exo2(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryPartnerCard extends StatelessWidget {
  const _DeliveryPartnerCard({required this.partner});

  final SellerDeliveryPartner partner;

  Future<void> _callRider(BuildContext context) async {
    final phone = partner.riderPhone;
    if (phone == null || phone.isEmpty) return;

    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      AppToast.warning(context, 'Could not open phone dialer.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final assigned = partner.hasRider;
    final dispatchFailed = partner.hasDispatchError;
    final statusLabel = dispatchFailed
        ? 'Dispatch failed'
        : partner.status?.isNotEmpty == true
            ? partner.status!
            : assigned
                ? 'Delivery partner assigned'
                : 'Finding delivery partner…';

    final accent = dispatchFailed ? AppColors.terracotta : AppColors.sage;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dispatchFailed
            ? AppColors.terracotta.withValues(alpha: 0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent.withValues(alpha: dispatchFailed ? 0.45 : 0.25),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  dispatchFailed
                      ? Icons.error_outline_rounded
                      : Icons.delivery_dining_rounded,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery partner',
                      style: GoogleFonts.exo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.deepGreen,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusLabel,
                      style: GoogleFonts.exo2(
                        fontSize: 12,
                        color: dispatchFailed
                            ? AppColors.terracotta
                            : AppColors.deepGreen.withValues(alpha: 0.58),
                        fontWeight:
                            dispatchFailed ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (dispatchFailed) ...[
            const SizedBox(height: 14),
            Text(
              partner.dispatchError!.message,
              style: GoogleFonts.exo2(
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: AppColors.deepGreen.withValues(alpha: 0.82),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Check kitchen and delivery locations are correct, then reopen this order to retry dispatch.',
              style: GoogleFonts.exo2(
                fontSize: 12,
                height: 1.4,
                color: AppColors.deepGreen.withValues(alpha: 0.55),
              ),
            ),
          ],
          if (assigned && !dispatchFailed) ...[
            if (partner.hasPickupOtp) ...[
              const SizedBox(height: 14),
              Text(
                'Pickup OTP',
                style: GoogleFonts.exo2(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepGreen.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                partner.pickupOtp!,
                style: GoogleFonts.exo2(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  color: AppColors.deepGreen,
                ),
              ),
              Text(
                'Share this OTP with the rider when handing over the order.',
                style: GoogleFonts.exo2(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.deepGreen.withValues(alpha: 0.55),
                ),
              ),
            ],
            if (partner.hasPickupSyncError) ...[
              const SizedBox(height: 12),
              Text(
                partner.pickupSyncError!.message,
                style: GoogleFonts.exo2(
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: AppColors.terracotta,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (partner.riderName?.isNotEmpty == true)
                        Text(
                          partner.riderName!,
                          style: GoogleFonts.exo2(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.deepGreen,
                          ),
                        ),
                      if (partner.riderPhone?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          partner.riderPhone!,
                          style: GoogleFonts.exo2(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.sage,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (partner.riderPhone?.isNotEmpty == true)
                  IconButton.filled(
                    onPressed: () => _callRider(context),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.sage,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.phone_rounded                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

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
          child,
        ],
      ),
    );
  }
}

class _OrderLineItemRow extends StatelessWidget {
  const _OrderLineItemRow({required this.item});

  final SellerOrderLineItem item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = Optica2AssetUrl.resolve(item.imageUrl);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 56,
            height: 56,
            color: AppColors.brandPurple.withValues(alpha: 0.08),
            child: imageUrl != null
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _dishPlaceholder(),
                  )
                : _dishPlaceholder(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.dishName,
                      style: GoogleFonts.exo2(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepGreen,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: (item.isVeg ? AppColors.sage : AppColors.kitchenOff)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.isVeg ? 'Veg' : 'Non-veg',
                      style: GoogleFonts.exo2(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: item.isVeg ? AppColors.sage : AppColors.kitchenOff,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${formatOrderAmount(item.unitPrice)} × ${item.quantity}',
                style: GoogleFonts.exo2(
                  fontSize: 12,
                  color: AppColors.deepGreen.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
        Text(
          formatOrderAmount(item.lineTotal),
          style: GoogleFonts.exo2(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.deepGreen,
          ),
        ),
      ],
    );
  }

  Widget _dishPlaceholder() {
    return Icon(
      Icons.restaurant_rounded,
      color: AppColors.brandPurple.withValues(alpha: 0.35),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.exo2(
            fontSize: 13,
            color: AppColors.deepGreen.withValues(alpha: 0.55),
          ),
        ),
        Text(
          value,
          style: valueStyle ??
              GoogleFonts.exo2(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.deepGreen,
              ),
        ),
      ],
    );
  }
}

class _ChatWithAdminButton extends StatelessWidget {
  const _ChatWithAdminButton({
    required this.loading,
    required this.onPressed,
  });

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.terracotta,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.terracotta.withValues(alpha: 0.55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        icon: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              )
            : const Icon(Icons.chat_bubble_outline_rounded),
        label: Text(
          loading ? 'Opening…' : 'Chat with support',
          style: GoogleFonts.exo2(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

/// Opens order detail after fetching from API. Returns true if status changed.
Future<bool> openSellerOrderDetail(
  BuildContext context, {
  required String phoneE164,
  required int orderId,
  int? sellerId,
  required Optica2Api api,
}) async {
  try {
    final detail = await api.fetchOrderDetail(
      phoneE164: phoneE164,
      orderId: orderId,
      sellerId: sellerId,
    );
    if (!context.mounted) return false;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SellerOrderDetailScreen(
          order: detail,
          phoneE164: phoneE164,
          sellerId: sellerId,
        ),
      ),
    );
    return changed ?? false;
  } on Optica2ApiException catch (e) {
    if (context.mounted) AppToast.danger(context, e.message);
  } catch (_) {
    if (context.mounted) {
      AppToast.danger(context, 'Could not load order details.');
    }
  }
  return false;
}
