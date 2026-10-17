import 'package:intl_phone_field/countries.dart';

/// ISO country code → display name (same dataset as phone country picker).
abstract final class CountryNames {
  static String label(String isoCode) {
    final upper = isoCode.toUpperCase();
    for (final country in countries) {
      if (country.code == upper) {
        return country.name;
      }
    }
    return upper;
  }
}
