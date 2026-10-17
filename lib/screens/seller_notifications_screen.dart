import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/seller_notification.dart';
import '../seller_session_prefs.dart';
import '../services/optica2_api.dart';
import '../theme/app_colors.dart';
import '../widgets/app_toast.dart';

/// Lists push notifications and alerts received for this seller account.
class SellerNotificationsScreen extends StatefulWidget {
  const SellerNotificationsScreen({super.key, required this.phoneE164});

  final String phoneE164;

  @override
  State<SellerNotificationsScreen> createState() =>
      _SellerNotificationsScreenState();
}

class _SellerNotificationsScreenState extends State<SellerNotificationsScreen> {
  final _api = Optica2Api();
  bool _loading = true;
  List<SellerNotification> _notifications = [];

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
      final result = await _api.fetchNotifications(
        phoneE164: widget.phoneE164,
        sellerId: sellerId,
      );
      if (!mounted) return;
      setState(() {
        _notifications = result.notifications;
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

  Future<void> _openNotification(SellerNotification notification) async {
    if (!notification.isRead) {
      try {
        final sellerId = await SellerSessionPrefs.sellerId();
        await _api.markNotificationRead(
          phoneE164: widget.phoneE164,
          notificationId: notification.id,
          sellerId: sellerId,
        );
        if (mounted) {
          setState(() {
            _notifications = _notifications
                .map(
                  (n) => n.id == notification.id
                      ? SellerNotification(
                          id: n.id,
                          type: n.type,
                          title: n.title,
                          body: n.body,
                          imageUrl: n.imageUrl,
                          isRead: true,
                          createdAt: n.createdAt,
                          createdAtHuman: n.createdAtHuman,
                        )
                      : n,
                )
                .toList();
          });
        }
      } catch (_) {
        // Still show detail if mark-read fails.
      }
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NotificationDetailSheet(notification: notification),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Notifications',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w800,
            color: AppColors.deepGreen,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.deepGreen),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.terracotta,
              child: _notifications.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.45,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.notifications_none_rounded,
                                    size: 56,
                                    color: AppColors.deepGreen.withValues(alpha: 0.35),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No notifications yet',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.exo2(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.deepGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Order alerts, KYC updates, and announcements will appear here when you receive them.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.exo2(
                                      fontSize: 14,
                                      color: AppColors.deepGreen.withValues(alpha: 0.65),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final n = _notifications[index];
                        return _NotificationTile(
                          notification: n,
                          onTap: () => _openNotification(n),
                        );
                      },
                    ),
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final SellerNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.terracotta.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.terracotta,
                  size: 22,
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
                            notification.title,
                            style: GoogleFonts.exo2(
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.deepGreen,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: const BoxDecoration(
                              color: AppColors.terracotta,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.exo2(
                        fontSize: 13,
                        color: AppColors.deepGreen.withValues(alpha: 0.7),
                        height: 1.35,
                      ),
                    ),
                    if (notification.createdAtHuman.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        notification.createdAtHuman,
                        style: GoogleFonts.exo2(
                          fontSize: 12,
                          color: AppColors.deepGreen.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.deepGreen.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationDetailSheet extends StatelessWidget {
  const _NotificationDetailSheet({required this.notification});

  final SellerNotification notification;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
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
                  notification.title,
                  style: GoogleFonts.exo2(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepGreen,
                  ),
                ),
                if (notification.createdAtHuman.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    notification.createdAtHuman,
                    style: GoogleFonts.exo2(
                      fontSize: 13,
                      color: AppColors.deepGreen.withValues(alpha: 0.5),
                    ),
                  ),
                ],
                if (notification.imageUrl != null &&
                    notification.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      notification.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  notification.body,
                  style: GoogleFonts.exo2(
                    fontSize: 15,
                    color: AppColors.deepGreen.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
