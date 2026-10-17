import '../config/optica2_asset_url.dart';

/// In-app notification / alert from the backend inbox.
class SellerNotification {
  const SellerNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.imageUrl,
    required this.isRead,
    this.createdAt,
    this.createdAtHuman = '',
  });

  final int id;
  final String type;
  final String title;
  final String body;
  final String? imageUrl;
  final bool isRead;
  final String? createdAt;
  final String createdAtHuman;

  factory SellerNotification.fromJson(Map<String, dynamic> json) {
    return SellerNotification(
      id: json['id'] as int? ?? 0,
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      imageUrl: Optica2AssetUrl.resolve(json['image_url'] as String?),
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] as String?,
      createdAtHuman: json['created_at_human'] as String? ?? '',
    );
  }
}

class SellerNotificationsResult {
  const SellerNotificationsResult({
    required this.notifications,
    required this.unreadCount,
  });

  final List<SellerNotification> notifications;
  final int unreadCount;

  factory SellerNotificationsResult.fromJson(Map<String, dynamic> json) {
    final rawList = json['notifications'];
    final list = rawList is List
        ? rawList
            .whereType<Map<String, dynamic>>()
            .map(SellerNotification.fromJson)
            .toList()
        : <SellerNotification>[];

    return SellerNotificationsResult(
      notifications: list,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}
