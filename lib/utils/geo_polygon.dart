import 'package:google_maps_flutter/google_maps_flutter.dart';

/// GeoJSON polygon helpers (admin zones use `{ type: Polygon, coordinates: [[[lng,lat],...]] }`).
abstract final class GeoPolygon {
  static List<LatLng> toLatLngs(Map<String, dynamic> geoJson) {
    if (geoJson['type'] != 'Polygon') return const [];

    final coordinates = geoJson['coordinates'];
    if (coordinates is! List || coordinates.isEmpty) return const [];

    final ring = coordinates.first;
    if (ring is! List) return const [];

    final points = <LatLng>[];
    for (final point in ring) {
      if (point is List && point.length >= 2) {
        final lng = _asDouble(point[0]);
        final lat = _asDouble(point[1]);
        if (lng != null && lat != null) {
          points.add(LatLng(lat, lng));
        }
      }
    }
    return points;
  }

  static bool containsLatLng(Map<String, dynamic> geoJson, LatLng point) {
    return containsPoint(geoJson, point.latitude, point.longitude);
  }

  static bool containsPoint(
    Map<String, dynamic> geoJson,
    double latitude,
    double longitude,
  ) {
    final ring = toLatLngs(geoJson);
    if (ring.length < 3) return false;

    var inside = false;
    var j = ring.length - 1;

    for (var i = 0; i < ring.length; i++) {
      final yi = ring[i].latitude;
      final xi = ring[i].longitude;
      final yj = ring[j].latitude;
      final xj = ring[j].longitude;

      final intersect = ((yi > latitude) != (yj > latitude)) &&
          (longitude <
              (xj - xi) * (latitude - yi) / ((yj - yi) == 0 ? 1e-12 : yj - yi) +
                  xi);

      if (intersect) inside = !inside;
      j = i;
    }

    return inside;
  }

  static LatLng? centerFor(Map<String, dynamic> geoJson) {
    final bounds = boundsFor(geoJson);
    if (bounds == null) return null;
    return LatLng(
      (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
      (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
    );
  }

  static LatLngBounds? boundsFor(Map<String, dynamic> geoJson) {
    final points = toLatLngs(geoJson);
    if (points.isEmpty) return null;

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final p in points) {
      minLat = minLat < p.latitude ? minLat : p.latitude;
      maxLat = maxLat > p.latitude ? maxLat : p.latitude;
      minLng = minLng < p.longitude ? minLng : p.longitude;
      maxLng = maxLng > p.longitude ? maxLng : p.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
