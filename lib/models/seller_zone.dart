import 'package:google_maps_flutter/google_maps_flutter.dart';

class SellerMapsConfig {
  const SellerMapsConfig({
    required this.apiKey,
    required this.defaultLat,
    required this.defaultLng,
  });

  final String apiKey;
  final double defaultLat;
  final double defaultLng;

  LatLng get defaultCenter => LatLng(defaultLat, defaultLng);

  factory SellerMapsConfig.fromJson(Map<String, dynamic> json) {
    return SellerMapsConfig(
      apiKey: json['api_key'] as String? ?? '',
      defaultLat: _toDouble(json['default_lat']) ?? 20.5937,
      defaultLng: _toDouble(json['default_lng']) ?? 78.9629,
    );
  }
}

class SellerZone {
  const SellerZone({
    required this.id,
    required this.name,
    required this.polygon,
    this.center,
  });

  final int id;
  final String name;
  final Map<String, dynamic> polygon;
  final LatLng? center;

  factory SellerZone.fromJson(Map<String, dynamic> json) {
    LatLng? center;
    final centerRaw = json['center'];
    if (centerRaw is Map<String, dynamic>) {
      final lat = _toDouble(centerRaw['lat']);
      final lng = _toDouble(centerRaw['lng']);
      if (lat != null && lng != null) {
        center = LatLng(lat, lng);
      }
    }

    final polygon = json['polygon'];
    return SellerZone(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? 'Zone',
      polygon: polygon is Map<String, dynamic>
          ? polygon
          : <String, dynamic>{},
      center: center,
    );
  }
}

class SellerZonesResponse {
  const SellerZonesResponse({
    required this.zones,
    required this.maps,
  });

  final List<SellerZone> zones;
  final SellerMapsConfig maps;

  factory SellerZonesResponse.fromJson(Map<String, dynamic> json) {
    final zonesRaw = json['zones'];
    final zones = <SellerZone>[];
    if (zonesRaw is List) {
      for (final item in zonesRaw) {
        if (item is Map<String, dynamic>) {
          zones.add(SellerZone.fromJson(item));
        }
      }
    }

    final mapsRaw = json['maps'];
    return SellerZonesResponse(
      zones: zones,
      maps: mapsRaw is Map<String, dynamic>
          ? SellerMapsConfig.fromJson(mapsRaw)
          : const SellerMapsConfig(
              apiKey: '',
              defaultLat: 20.5937,
              defaultLng: 78.9629,
            ),
    );
  }
}

double? _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
