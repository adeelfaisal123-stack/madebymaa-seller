// API base URL (no trailing slash).
//
// Production (cPanel): set once, e.g. https://api.yourdomain.com
// Local dev: run `dart run tool/sync_optica2_host.dart` to fill Wi‑Fi IP :8000
//
// Override at build time: flutter run --dart-define=OPTICA2_API_URL=https://...

abstract final class Optica2Host {  
  static const apiUrl = 'https://madebymaa.online';
}
