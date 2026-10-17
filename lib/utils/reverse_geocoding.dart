import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class ParsedAddress {
  const ParsedAddress({
    required this.address,
    required this.city,
    required this.state,
    required this.country,
  });

  final String address;
  final String city;
  final String state;
  final String country;

  bool get hasAnyField =>
      address.isNotEmpty ||
      city.isNotEmpty ||
      state.isNotEmpty ||
      country.isNotEmpty;
}

Future<LatLng?> geocodeAddressQuery(String query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return null;

  try {
    final locations = await locationFromAddress(trimmed);
    if (locations.isEmpty) return null;
    final first = locations.first;
    return LatLng(first.latitude, first.longitude);
  } catch (_) {
    return null;
  }
}

Future<ParsedAddress?> reverseGeocodeLocation(
  LatLng location, {
  String? googleMapsApiKey,
}) async {
  final key = googleMapsApiKey?.trim() ?? '';
  if (key.isNotEmpty) {
    final fromGoogle = await _reverseGeocodeViaGoogleApi(location, key);
    if (fromGoogle != null && fromGoogle.hasAnyField) {
      return fromGoogle;
    }
  }

  return _reverseGeocodeViaPlacemark(location);
}

Future<ParsedAddress?> _reverseGeocodeViaGoogleApi(
  LatLng location,
  String apiKey,
) async {
  try {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'latlng': '${location.latitude},${location.longitude}',
        'key': apiKey,
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) return null;
    if (body['status'] != 'OK') return null;

    final results = body['results'];
    if (results is! List || results.isEmpty) return null;

    final first = results.first;
    if (first is! Map<String, dynamic>) return null;

    final components = first['address_components'];
    if (components is! List) return null;

    String? pick(Iterable<String> types) {
      for (final raw in components) {
        if (raw is! Map<String, dynamic>) continue;
        final itemTypes = raw['types'];
        if (itemTypes is! List) continue;
        for (final type in types) {
          if (itemTypes.contains(type)) {
            final longName = raw['long_name'];
            if (longName is String && longName.trim().isNotEmpty) {
              return longName.trim();
            }
          }
        }
      }
      return null;
    }

    String? pickShort(Iterable<String> types) {
      for (final raw in components) {
        if (raw is! Map<String, dynamic>) continue;
        final itemTypes = raw['types'];
        if (itemTypes is! List) continue;
        for (final type in types) {
          if (itemTypes.contains(type)) {
            final shortName = raw['short_name'];
            if (shortName is String && shortName.trim().isNotEmpty) {
              return shortName.trim();
            }
          }
        }
      }
      return null;
    }

    final streetNumber = pick(const ['street_number']);
    final route = pick(const ['route']);
    final sublocality = pick(const [
      'sublocality',
      'sublocality_level_1',
      'sublocality_level_2',
    ]);
    final neighborhood = pick(const ['neighborhood']);
    final locality = pick(const ['locality']);
    final admin2 = pick(const ['administrative_area_level_2']);
    final state = pick(const ['administrative_area_level_1']);
    final country = pickShort(const ['country']) ?? pick(const ['country']);

    final streetParts = <String>[
      ?streetNumber,
      ?route,
      ?sublocality,
      ?neighborhood,
    ];

    var address = _uniqueJoin(streetParts);
    if (address.isEmpty) {
      final formatted = first['formatted_address'];
      if (formatted is String && formatted.trim().isNotEmpty) {
        address = formatted.trim();
      }
    }

    final city = locality ?? admin2 ?? sublocality ?? '';
    final stateName = state ?? '';
    final countryCode = (country ?? '').toUpperCase();

    return ParsedAddress(
      address: address,
      city: city,
      state: stateName,
      country: countryCode.length == 2 ? countryCode : 'IN',
    );
  } catch (_) {
    return null;
  }
}

Future<ParsedAddress?> _reverseGeocodeViaPlacemark(LatLng location) async {
  try {
    final placemarks = await placemarkFromCoordinates(
      location.latitude,
      location.longitude,
    );
    if (placemarks.isEmpty) return null;

    final place = placemarks.first;
    final streetParts = <String>[
      if ((place.subThoroughfare ?? '').trim().isNotEmpty)
        place.subThoroughfare!.trim(),
      if ((place.thoroughfare ?? '').trim().isNotEmpty)
        place.thoroughfare!.trim(),
      if ((place.street ?? '').trim().isNotEmpty) place.street!.trim(),
      if ((place.subLocality ?? '').trim().isNotEmpty)
        place.subLocality!.trim(),
      if ((place.name ?? '').trim().isNotEmpty) place.name!.trim(),
    ];

    final cityCandidates = [
      (place.locality ?? '').trim(),
      (place.subAdministrativeArea ?? '').trim(),
      (place.administrativeArea ?? '').trim(),
    ];

    final city = cityCandidates.firstWhere(
      (value) => value.isNotEmpty,
      orElse: () => '',
    );

    final state = (place.administrativeArea ?? '').trim();
    final country = (place.isoCountryCode ?? '').trim().toUpperCase();

    return ParsedAddress(
      address: _uniqueJoin(streetParts),
      city: city,
      state: state,
      country: country.length == 2 ? country : 'IN',
    );
  } catch (_) {
    return null;
  }
}

String _uniqueJoin(List<String> parts) {
  final unique = <String>[];
  for (final part in parts) {
    final trimmed = part.trim();
    if (trimmed.isEmpty || unique.contains(trimmed)) continue;
    unique.add(trimmed);
  }
  return unique.join(', ');
}
