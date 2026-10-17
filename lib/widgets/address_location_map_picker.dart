import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_colors.dart';
import 'map_webview_controller.dart';
import 'map_webview_gestures.dart';

/// Fixed-center pin map for picking a home / business address location.
/// Users pan the map; the pin stays fixed in the middle.
class AddressLocationMapPicker extends StatefulWidget {
  const AddressLocationMapPicker({
    super.key,
    required this.apiKey,
    required this.initialCenter,
    this.pin,
    required this.onPinChanged,
    this.interactive = true,
  });

  final String apiKey;
  final LatLng initialCenter;
  final LatLng? pin;
  final ValueChanged<LatLng> onPinChanged;
  final bool interactive;

  @override
  State<AddressLocationMapPicker> createState() =>
      _AddressLocationMapPickerState();
}

class _AddressLocationMapPickerState extends State<AddressLocationMapPicker> {
  late final WebViewController _controller;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant AddressLocationMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pin != widget.pin ||
        oldWidget.apiKey != widget.apiKey ||
        oldWidget.initialCenter != widget.initialCenter ||
        oldWidget.interactive != widget.interactive) {
      _loadMap();
    }
  }

  void _initController() {
    _controller = createMapWebViewController()
      ..addJavaScriptChannel(
        'MapChannel',
        onMessageReceived: (message) {
          if (!widget.interactive) return;
          try {
            final data = jsonDecode(message.message);
            if (data is! Map<String, dynamic>) return;
            if (data['type'] != 'pin') return;
            final lat = (data['lat'] as num?)?.toDouble();
            final lng = (data['lng'] as num?)?.toDouble();
            if (lat == null || lng == null) return;
            widget.onPinChanged(LatLng(lat, lng));
          } catch (_) {}
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _ready = true);
          },
        ),
      );
    _loadMap();
  }

  void _loadMap() {
    setState(() => _ready = false);
    _controller.loadHtmlString(
      _buildHtml(
        apiKey: widget.apiKey,
        center: widget.pin ?? widget.initialCenter,
        interactive: widget.interactive,
      ),
      baseUrl: 'https://maps.googleapis.com',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(
          controller: _controller,
          gestureRecognizers: mapWebViewGestureRecognizers(),
        ),
        if (_ready)
          const IgnorePointer(
            child: Center(
              child: Padding(
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
        if (!_ready)
          const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
      ],
    );
  }
}

String _buildHtml({
  required String apiKey,
  required LatLng center,
  required bool interactive,
}) {
  final centerJson = jsonEncode({
    'lat': center.latitude,
    'lng': center.longitude,
  });
  final keyParam = Uri.encodeComponent(apiKey);
  final interactiveJs = interactive ? 'true' : 'false';

  return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" />
  <style>
    html, body, #map { height: 100%; margin: 0; padding: 0; }
  </style>
  <script src="https://maps.googleapis.com/maps/api/js?key=$keyParam&callback=initMap" async defer></script>
</head>
<body>
  <div id="map"></div>
  <script>
    const defaultCenter = $centerJson;
    const interactive = $interactiveJs;
    let map;
    let quiet = false;

    function initMap() {
      map = new google.maps.Map(document.getElementById('map'), {
        center: defaultCenter,
        zoom: 16,
        disableDefaultUI: true,
        gestureHandling: interactive ? 'greedy' : 'none',
        draggable: interactive,
        scrollwheel: interactive,
        disableDoubleClickZoom: !interactive,
      });

      if (interactive) {
        map.addListener('idle', () => {
          if (quiet) return;
          const c = map.getCenter();
          if (!c) return;
          MapChannel.postMessage(JSON.stringify({
            type: 'pin',
            lat: c.lat(),
            lng: c.lng()
          }));
        });
      }
    }
  </script>
</body>
</html>
''';
}
