import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/map_pin_selection.dart';
import '../models/seller_zone.dart';
import '../theme/app_colors.dart';
import '../utils/geo_polygon.dart';

/// Native Flutter Google Map for selecting a kitchen pin inside a delivery zone.
///
/// The pin stays fixed at the map center; users pan/zoom the map to choose a
/// location (no tap-to-move or drag-the-marker).
class KycZoneGoogleMapFlutter extends StatefulWidget {
  const KycZoneGoogleMapFlutter({
    super.key,
    required this.zones,
    required this.zone,
    required this.initialCenter,
    this.pin,
    required this.onPinChanged,
    this.onLocationPicked,
    this.interactive = true,
  });

  final List<SellerZone> zones;
  final SellerZone zone;
  final LatLng initialCenter;
  final LatLng? pin;
  final ValueChanged<LatLng> onPinChanged;
  final ValueChanged<MapPinSelection>? onLocationPicked;
  final bool interactive;

  @override
  State<KycZoneGoogleMapFlutter> createState() =>
      _KycZoneGoogleMapFlutterState();
}

class _KycZoneGoogleMapFlutterState extends State<KycZoneGoogleMapFlutter> {
  GoogleMapController? _controller;
  LatLng? _lastValidPin;
  LatLng? _currentCameraTarget;
  late LatLng _lastValidCameraTarget;
  var _programmaticMove = false;
  var _mapReady = false;

  List<LatLng> get _zonePath => GeoPolygon.toLatLngs(widget.zone.polygon);
  LatLngBounds? get _zoneBounds => GeoPolygon.boundsFor(widget.zone.polygon);

  @override
  void initState() {
    super.initState();
    _lastValidPin = widget.pin;
    _lastValidCameraTarget =
        _validCameraTarget(widget.pin ?? widget.initialCenter);
    _currentCameraTarget = _lastValidCameraTarget;
  }

  @override
  void didUpdateWidget(covariant KycZoneGoogleMapFlutter oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.zone.id != widget.zone.id ||
        oldWidget.zones.length != widget.zones.length) {
      _lastValidPin = widget.pin;
      _lastValidCameraTarget = _validCameraTarget(
        widget.pin ?? widget.initialCenter,
      );
      _currentCameraTarget = _lastValidCameraTarget;
      _fitZone();
      return;
    }

    if (widget.pin != null &&
        widget.pin != oldWidget.pin &&
        !_sameLatLng(widget.pin, _lastValidPin)) {
      _lastValidPin = widget.pin;
      _animateTo(widget.pin!);
    }
  }

  bool _sameLatLng(LatLng? a, LatLng? b) {
    if (a == null || b == null) return a == b;
    return (a.latitude - b.latitude).abs() < 1e-7 &&
        (a.longitude - b.longitude).abs() < 1e-7;
  }

  Future<void> _fitZone() async {
    final controller = _controller;
    final bounds = _zoneBounds;
    if (controller == null || bounds == null) return;

    _programmaticMove = true;
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 36),
      );
    } finally {
      _programmaticMove = false;
    }
  }

  Future<void> _animateTo(LatLng target) async {
    final controller = _controller;
    if (controller == null) return;

    final safe = _validCameraTarget(target);
    _programmaticMove = true;
    try {
      await controller.animateCamera(CameraUpdate.newLatLng(safe));
    } finally {
      _programmaticMove = false;
    }
  }

  LatLng _validCameraTarget(LatLng target) {
    if (GeoPolygon.containsLatLng(widget.zone.polygon, target)) return target;
    final center = widget.zone.center;
    if (center != null &&
        GeoPolygon.containsLatLng(widget.zone.polygon, center)) {
      return center;
    }
    final path = _zonePath;
    return path.isEmpty ? target : path.first;
  }

  void _onCameraMove(CameraPosition position) {
    final target = position.target;
    _currentCameraTarget = target;
    if (GeoPolygon.containsLatLng(widget.zone.polygon, target)) {
      _lastValidCameraTarget = target;
    }
  }

  Future<void> _onCameraIdle() async {
    if (!widget.interactive || _programmaticMove) return;

    final controller = _controller;
    final target = _currentCameraTarget;
    if (controller == null || target == null) return;

    if (!GeoPolygon.containsLatLng(widget.zone.polygon, target)) {
      _programmaticMove = true;
      try {
        await controller.animateCamera(
          CameraUpdate.newLatLng(_lastValidCameraTarget),
        );
      } finally {
        _programmaticMove = false;
      }
      return;
    }

    _acceptPin(target);
  }

  void _acceptPin(LatLng pin) {
    if (!GeoPolygon.containsLatLng(widget.zone.polygon, pin)) return;
    if (_sameLatLng(pin, _lastValidPin)) return;

    _lastValidPin = pin;
    _lastValidCameraTarget = pin;

    final picked = widget.onLocationPicked;
    if (picked != null) {
      picked(MapPinSelection(pin: pin));
    } else {
      widget.onPinChanged(pin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zoneBounds = _zoneBounds;

    final polygons = widget.zones
        .map((zone) {
          final zonePath = GeoPolygon.toLatLngs(zone.polygon);
          if (zonePath.length < 3) return null;
          final selected = zone.id == widget.zone.id;
          return Polygon(
            polygonId: PolygonId('zone_${zone.id}'),
            points: zonePath,
            strokeColor:
                selected ? AppColors.brandPurple : AppColors.deepGreen,
            strokeWidth: selected ? 3 : 1,
            fillColor: (selected ? AppColors.brandPurple : AppColors.deepGreen)
                .withValues(alpha: selected ? 0.24 : 0.10),
            consumeTapEvents: false,
          );
        })
        .whereType<Polygon>()
        .toSet();

    return Stack(
      fit: StackFit.expand,
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _validCameraTarget(widget.pin ?? widget.initialCenter),
            zoom: 14,
          ),
          cameraTargetBounds: zoneBounds == null
              ? CameraTargetBounds.unbounded
              : CameraTargetBounds(zoneBounds),
          minMaxZoomPreference: const MinMaxZoomPreference(4, 21),
          polygons: polygons,
          markers: const <Marker>{},
          onMapCreated: (controller) {
            _controller = controller;
            _mapReady = true;
            if (widget.pin != null) {
              _animateTo(widget.pin!);
            } else {
              _fitZone();
            }
          },
          onCameraMove: _onCameraMove,
          onCameraIdle: _onCameraIdle,
          zoomControlsEnabled: widget.interactive,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          scrollGesturesEnabled: widget.interactive,
          zoomGesturesEnabled: widget.interactive,
          gestureRecognizers: widget.interactive
              ? {
                  Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                }
              : const <Factory<OneSequenceGestureRecognizer>>{},
        ),
        if (_mapReady || widget.interactive)
          const IgnorePointer(
            child: Center(
              child: Padding(
                // Offset so the pin tip sits on the map center.
                padding: EdgeInsets.only(bottom: 36),
                child: Icon(
                  Icons.location_on,
                  size: 44,
                  color: AppColors.brandPurple,
                  shadows: [
                    Shadow(
                      color: Color(0x66000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
