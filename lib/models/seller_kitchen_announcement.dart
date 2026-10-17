import 'package:flutter/material.dart';

/// Kitchen announcement shown to customers.
class SellerKitchenAnnouncement {
  const SellerKitchenAnnouncement({
    this.title,
    this.description,
    this.type,
    this.typeLabel,
  });

  final String? title;
  final String? description;
  final KitchenAnnouncementType? type;
  final String? typeLabel;

  bool get hasContent =>
      (title != null && title!.trim().isNotEmpty) ||
      (description != null && description!.trim().isNotEmpty);

  String get displayTypeLabel =>
      typeLabel?.trim().isNotEmpty == true
          ? typeLabel!.trim()
          : (type?.label ?? '');

  factory SellerKitchenAnnouncement.fromJson(Map<String, dynamic> json) {
    return SellerKitchenAnnouncement(
      title: json['title'] as String?,
      description: json['description'] as String?,
      type: KitchenAnnouncementType.fromApi(json['type'] as String?),
      typeLabel: json['type_label'] as String?,
    );
  }
}

enum KitchenAnnouncementType {
  general(
    'general',
    'General update',
    Icons.campaign_outlined,
  ),
  offer(
    'offer',
    'Offer / promo',
    Icons.local_offer_outlined,
  ),
  holiday(
    'holiday',
    'Holiday / closed',
    Icons.event_busy_outlined,
  ),
  menuUpdate(
    'menu_update',
    'Menu update',
    Icons.restaurant_menu_outlined,
  );

  const KitchenAnnouncementType(this.apiValue, this.label, this.icon);

  final String apiValue;
  final String label;
  final IconData icon;

  static KitchenAnnouncementType? fromApi(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    for (final value in KitchenAnnouncementType.values) {
      if (value.apiValue == raw) return value;
    }
    return null;
  }
}
