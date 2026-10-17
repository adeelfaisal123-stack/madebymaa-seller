import '../models/seller_zone.dart';
import 'optica2_api.dart';

/// Google Maps key and defaults from Optica2 admin (System settings).
abstract final class GoogleMapsConfigService {
  static SellerMapsConfig? _cached;

  static SellerMapsConfig get maps =>
      _cached ??
      const SellerMapsConfig(
        apiKey: '',
        defaultLat: 20.5937,
        defaultLng: 78.9629,
      );

  static bool get isConfigured => maps.apiKey.isNotEmpty;

  /// Loads `/api/seller/maps-config` (admin panel key). Safe to call multiple times.
  static Future<SellerMapsConfig> ensureLoaded({Optica2Api? api}) async {
    try {
      return await loadFromAdmin(api: api);
    } catch (_) {
      return _cached ?? maps;
    }
  }

  /// Always reads the latest key from Optica2 admin (`GET /api/seller/maps-config`).
  static Future<SellerMapsConfig> loadFromAdmin({
    Optica2Api? api,
    bool refresh = false,
  }) async {
    if (!refresh && _cached != null && _cached!.apiKey.isNotEmpty) {
      return _cached!;
    }

    final client = api ?? Optica2Api();
    final config = await client.fetchMapsConfig();
    if (config.apiKey.isNotEmpty) {
      _cached = config;
    } else if (_cached == null) {
      _cached = config;
    }
    return config;
  }

  /// Zones API also returns `maps`; prefer that when non-empty.
  static void applyFromZones(SellerMapsConfig config) {
    if (config.apiKey.isNotEmpty) {
      _cached = config;
    } else if (_cached == null) {
      _cached = config;
    }
  }
}
