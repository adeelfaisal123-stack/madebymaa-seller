import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utils/reverse_geocoding.dart';

/// Pin position from the zone map, optionally with reverse-geocoded address fields.
class MapPinSelection {
  const MapPinSelection({
    required this.pin,
    this.address,
  });

  final LatLng pin;
  final ParsedAddress? address;
}
