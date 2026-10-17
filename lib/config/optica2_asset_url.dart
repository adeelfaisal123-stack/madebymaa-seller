import 'optica2_config.dart';

/// Rewrites uploaded asset URLs to [Optica2Config.baseUrl].
///
/// Local dev often uses `127.0.0.1` for API (adb reverse) while Laravel
/// [SELLER_PUBLIC_URL] still has the Mac LAN IP — without this, images 404.
/// Production Hostinger serves Laravel assets below `/public`, so plain
/// `/uploads/...` and `/storage/...` are expanded to `/public/uploads/...`.
abstract final class Optica2AssetUrl {
  static String? resolve(String? url) {
    final raw = url?.trim();
    if (raw == null || raw.isEmpty) return raw;

    final parsed = Uri.tryParse(raw);
    if (parsed == null) {
      return _joinBase(raw);
    }

    if (!parsed.hasScheme) {
      final path = parsed.path.isEmpty ? raw : parsed.path;
      return _joinBase(path);
    }

    final normalizedPath = _normalizeAssetPath(parsed.path);
    if (normalizedPath == null) {
      return raw;
    }

    return _assetBaseUri().replace(path: normalizedPath).toString();
  }

  static List<String> resolveAll(Iterable<String> urls) {
    return urls
        .map(resolve)
        .whereType<String>()
        .where((u) => u.isNotEmpty)
        .toList();
  }

  static String? _joinBase(String path) {
    final normalizedPath = _normalizeAssetPath(path);
    if (normalizedPath == null) return path;
    return _assetBaseUri().replace(path: normalizedPath).toString();
  }

  static String? _normalizeAssetPath(String path) {
    var clean = path.trim().replaceAll('\\', '/');
    if (clean.isEmpty) return null;
    clean = clean.startsWith('/') ? clean : '/$clean';

    final publicPrefix = _assetWebPrefix();
    if (clean.startsWith('/public/uploads/') ||
        clean.startsWith('/public/storage/')) {
      if (publicPrefix.isEmpty) {
        return clean.substring('/public'.length);
      }
      return clean;
    }

    if (clean.startsWith('/uploads/') || clean.startsWith('/storage/')) {
      return '$publicPrefix$clean';
    }

    return null;
  }

  static String _assetWebPrefix() {
    final host = _assetBaseUri().host.toLowerCase();
    return host == 'madebymaa.online' || host.endsWith('.madebymaa.online')
        ? '/public'
        : '';
  }

  static Uri _assetBaseUri() {
    final parsed = Uri.tryParse(Optica2Config.baseUrl);
    if (parsed == null || parsed.host.isEmpty) {
      return Uri.parse('https://madebymaa.online');
    }

    final host = parsed.host.toLowerCase();
    final isMadeByMaa =
        host == 'madebymaa.online' || host.endsWith('.madebymaa.online');

    if (isMadeByMaa) {
      return Uri(
        scheme: 'https',
        host: host,
      );
    }

    return parsed.replace(path: '', query: null, fragment: null);
  }
}
