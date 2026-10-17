import '../config/optica2_asset_url.dart';

/// Kitchen (restaurant) name, logo, and delivery time for the seller app.
class SellerKitchenProfile {
  const SellerKitchenProfile({
    required this.id,
    required this.name,
    this.logoUrl,
    this.deliveryMinutesMin,
    this.deliveryMinutesMax,
    this.deliveryTimeLabel,
    this.instantDeliveryEnabled = true,
  });

  final int id;
  final String name;
  final String? logoUrl;
  final int? deliveryMinutesMin;
  final int? deliveryMinutesMax;
  final String? deliveryTimeLabel;
  final bool instantDeliveryEnabled;

  String get subtitle {
    final delivery = deliveryTimeLabel?.trim();
    if (delivery != null && delivery.isNotEmpty) {
      return delivery;
    }
    if (deliveryMinutesMin != null && deliveryMinutesMax != null) {
      if (deliveryMinutesMin == deliveryMinutesMax) {
        return '$deliveryMinutesMin min';
      }
      return '$deliveryMinutesMin–$deliveryMinutesMax min';
    }
    return 'Update name, logo & delivery time';
  }

  factory SellerKitchenProfile.fromJson(Map<String, dynamic> json) {
    return SellerKitchenProfile(
      id: json['id'] as int,
      name: json['name'] as String,
      logoUrl: Optica2AssetUrl.resolve(json['logo_url'] as String?),
      deliveryMinutesMin: _parseInt(json['delivery_minutes_min']),
      deliveryMinutesMax: _parseInt(json['delivery_minutes_max']),
      deliveryTimeLabel: json['delivery_time_label'] as String?,
      instantDeliveryEnabled: _parseBool(json['instant_delivery_enabled'], defaultValue: true),
    );
  }

  static bool _parseBool(dynamic value, {required bool defaultValue}) {
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return defaultValue;
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}
