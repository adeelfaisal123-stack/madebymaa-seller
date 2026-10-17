import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl_phone_field/countries.dart';

/// Resolves ISO 3166-1 alpha-2 country for phone field defaults.
abstract final class DeviceCountry {
  static const _fallback = 'IN';

  static String fromDeviceLocale() {
    final code =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    if (code != null && code.length == 2) {
      return normalize(code);
    }
    return _fallback;
  }

  static bool isSupported(String isoCode) {
    final upper = isoCode.toUpperCase();
    return countries.any((c) => c.code == upper);
  }

  static String normalize(String isoCode) {
    final upper = isoCode.toUpperCase();
    return isSupported(upper) ? upper : _fallback;
  }

  /// Uses GPS when permitted; otherwise device locale country.
  static Future<String> resolveFromLocation() async {
    final localeCountry = fromDeviceLocale();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return localeCountry;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return localeCountry;
      }

      var position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) return localeCountry;

      final iso = placemarks.first.isoCountryCode;
      if (iso != null && iso.isNotEmpty) {
        return normalize(iso);
      }
    } catch (_) {
      // Fall back to locale.
    }

    return localeCountry;
  }
}
