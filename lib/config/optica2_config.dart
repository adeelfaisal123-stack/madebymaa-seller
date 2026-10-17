import 'dart:io' show HttpClient, Platform;

import 'package:flutter/foundation.dart';

import '../optica2_api_prefs.dart';
import 'optica2_host.g.dart';

/// Optica2 backend (Laravel) connection for seller login checks.
abstract final class Optica2Config {
  static const _port = 8000;
  static const _envUrl = String.fromEnvironment('OPTICA2_API_URL');
  static const _useEmulatorHost = bool.fromEnvironment(
    'OPTICA2_USE_EMULATOR_HOST',
    defaultValue: false,
  );

  static String? _resolvedBaseUrl;

  /// Call once at startup (see [main.dart]).
  static Future<void> initialize() async {
    await _applyResolvedHost();
  }

  /// Re-probe hosts after adb reverse, Wi‑Fi change, or before sign-in.
  static Future<void> refresh() async {
    await _applyResolvedHost();
  }

  static Future<void> _applyResolvedHost() async {
    final computed = _normalizeBaseUrl(_computeBaseUrl());

    if (_isProductionUrl(computed)) {
      await Optica2ApiPrefs.clearSavedBaseUrl();
    } else if (kDebugMode && _isLocalDevUrl(computed)) {
      final saved = await Optica2ApiPrefs.lastBaseUrl();
      if (saved != null && !_isLocalDevUrl(saved)) {
        await Optica2ApiPrefs.clearSavedBaseUrl();
      }
    }

    final url = await _resolveReachableBaseUrl();
    final reachable = await _probe(url);
    _resolvedBaseUrl = url;

    if (reachable) {
      if (!_isProductionUrl(url)) {
        final changed = await Optica2ApiPrefs.saveBaseUrlIfChanged(url);
        if (kDebugMode && changed) {
          debugPrint('Optica2 API URL changed.');
        }
      }
      if (kDebugMode) {
        debugPrint('Optica2 API → $url');
      }
      return;
    }

    await Optica2ApiPrefs.clearSavedBaseUrl();
    if (kDebugMode) {
      debugPrint(
        'Optica2 API not reachable at $url. '
        'See unreachableMessage() hints.',
      );
    }
  }

  /// On connection failure, try other dev hosts (LAN IP vs adb reverse).
  static Future<bool> tryRecoverHost() async {
    final previous = baseUrl;
    final url = await _resolveReachableBaseUrl();
    final reachable = await _probe(url);
    _resolvedBaseUrl = url;

    if (reachable) {
      await Optica2ApiPrefs.saveBaseUrlIfChanged(url);
      if (kDebugMode && url != previous) {
        debugPrint('Optica2 API recovered → $url');
      }
      return true;
    }

    await Optica2ApiPrefs.clearSavedBaseUrl();
    return false;
  }

  /// Shown when the device cannot open a TCP connection to [baseUrl].
  static String unreachableMessage() {
    if (_isProductionUrl(baseUrl)) {
      return 'Cannot reach the API at $baseUrl.\n\n'
          'Check your internet connection and that the server is online.';
    }
    return 'Cannot reach the API at $baseUrl.\n\n'
        '• Backend running: php artisan serve --host=0.0.0.0 --port=$_port\n'
        '• Phone on USB or wireless adb: adb reverse tcp:8000 tcp:8000\n'
        '  then hot restart the app (capital R in flutter run)\n'
        '• Same Wi‑Fi only: dart run tool/sync_optica2_host.dart\n'
        '  (some routers block phone→Mac; use adb reverse instead)';
  }

  /// Active base URL (no trailing slash).
  static String get baseUrl => _resolvedBaseUrl ?? _computeBaseUrl();

  static Future<String> _resolveReachableBaseUrl() async {
    final computed = _normalizeBaseUrl(_computeBaseUrl());

    if (_isProductionUrl(computed)) {
      return computed;
    }

    final candidates = <String>[];
    void add(String url) {
      final normalized = _normalizeBaseUrl(url);
      if (!candidates.contains(normalized)) {
        candidates.add(normalized);
      }
    }

    if (_envUrl.isNotEmpty) add(_envUrl);
    add(computed);

    // Local dev only: adb reverse / emulator before falling back to saved LAN IP.
    if (kDebugMode && !kIsWeb && Platform.isAndroid && _isLocalDevUrl(computed)) {
      add('http://127.0.0.1:$_port');
      if (_useEmulatorHost) add('http://10.0.2.2:$_port');
    }

    final saved = await Optica2ApiPrefs.lastBaseUrl();
    if (saved != null &&
        saved.isNotEmpty &&
        saved != computed &&
        _isLocalDevUrl(saved)) {
      add(saved);
    }

    for (final url in candidates) {
      if (await _probe(url)) return url;
    }

    return computed;
  }

  static bool _isProductionUrl(String url) {
    if (_isLocalDevUrl(url)) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.scheme == 'https' || !_isLocalDevUrl(url);
  }

  static bool _isLocalDevUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return false;
    final host = uri.host.toLowerCase();
    if (host == 'localhost' || host == '127.0.0.1') return true;
    if (host.startsWith('192.168.')) return true;
    if (host == '10.0.2.2') return true;
    return false;
  }

  static Duration get _probeTimeout {
    if (kDebugMode && !kIsWeb && Platform.isAndroid) {
      return const Duration(seconds: 3);
    }
    return const Duration(seconds: 4);
  }

  static Future<bool> _probe(String baseUrl) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = _probeTimeout;
      final uri = Uri.parse('$baseUrl/api/otp/config');
      final request = await client.getUrl(uri);
      final response = await request.close();
      await response.drain();
      client.close();
      // Any HTTP response means the host is reachable (500 = server misconfig, not offline).
      return response.statusCode >= 100 && response.statusCode < 600;
    } catch (_) {
      return false;
    }
  }

  static String _computeBaseUrl() {
    if (_envUrl.isNotEmpty) return _normalizeBaseUrl(_envUrl);

    if (kIsWeb) {
      return 'http://localhost:$_port';
    }

    if (!kIsWeb && Platform.isAndroid && _useEmulatorHost) {
      return 'http://10.0.2.2:$_port';
    }

    return Optica2Host.apiUrl;
  }

  static String _normalizeBaseUrl(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  /// Optional — must match Optica2 `SELLER_API_KEY` when set.
  static const apiKey = String.fromEnvironment(
    'OPTICA2_API_KEY',
    defaultValue: '',
  );

  static Uri otpConfigUri() => Uri.parse('$baseUrl/api/otp/config');

  static Uri otpSendUri() => Uri.parse('$baseUrl/api/otp/send');

  static Uri otpVerifyUri() => Uri.parse('$baseUrl/api/otp/verify');

  static Uri sellerDashboardUri() =>
      Uri.parse('$baseUrl/api/seller/dashboard');

  static Uri sellerOrdersUri() => Uri.parse('$baseUrl/api/seller/orders');

  static Uri sellerOrderShowUri() =>
      Uri.parse('$baseUrl/api/seller/orders/show');

  static Uri sellerOrderMarkReadyUri() =>
      Uri.parse('$baseUrl/api/seller/orders/mark-ready');

  static Uri sellerOrderAcceptUri() =>
      Uri.parse('$baseUrl/api/seller/orders/accept');

  static Uri sellerOrderMarkPickedUpUri() =>
      Uri.parse('$baseUrl/api/seller/orders/mark-picked-up');

  static Uri sellerWalletUri() => Uri.parse('$baseUrl/api/seller/wallet');

  static Uri sellerWalletWithdrawUri() =>
      Uri.parse('$baseUrl/api/seller/wallet/withdraw');

  static Uri sellerPayoutMethodsUri() =>
      Uri.parse('$baseUrl/api/seller/payout-methods');

  static Uri sellerPayoutMethodsStoreUri() =>
      Uri.parse('$baseUrl/api/seller/payout-methods/store');

  static Uri sellerPayoutMethodsDeleteUri() =>
      Uri.parse('$baseUrl/api/seller/payout-methods/delete');

  static Uri checkPhoneUri() =>
      Uri.parse('$baseUrl/api/seller/auth/check-phone');

  static Uri registerUri() =>
      Uri.parse('$baseUrl/api/seller/auth/register');

  static Uri setupKitchenUri() =>
      Uri.parse('$baseUrl/api/seller/auth/setup-kitchen');

  static Uri completeKycUri() =>
      Uri.parse('$baseUrl/api/seller/auth/complete-kyc');

  static Uri kycStatusUri() =>
      Uri.parse('$baseUrl/api/seller/auth/kyc-status');

  static Uri submitDocumentKycUri() =>
      Uri.parse('$baseUrl/api/seller/auth/submit-document-kyc');

  static Uri updateBankDetailsUri() =>
      Uri.parse('$baseUrl/api/seller/bank-details');

  static Uri sellerProfileUri() => Uri.parse('$baseUrl/api/seller/profile');

  static Uri sellerProfileUpdateUri() =>
      Uri.parse('$baseUrl/api/seller/profile');

  static Uri sellerAddressUri() => Uri.parse('$baseUrl/api/seller/address');

  static Uri sellerAddressSubmitUri() =>
      Uri.parse('$baseUrl/api/seller/address/submit');

  static Uri sellerMapsConfigUri() =>
      Uri.parse('$baseUrl/api/seller/maps-config');

  static Uri sellerNotificationsUri() =>
      Uri.parse('$baseUrl/api/seller/notifications');

  static Uri sellerNotificationsReadUri() =>
      Uri.parse('$baseUrl/api/seller/notifications/read');

  static Uri sellerLegalUri() => Uri.parse('$baseUrl/api/seller/legal');

  static Uri sellerHelpSupportUri() =>
      Uri.parse('$baseUrl/api/seller/help-support');

  static Uri sellerKycAgreementUri() =>
      Uri.parse('$baseUrl/api/seller/kyc-agreement');

  static Uri sellerTrainingVideosUri() =>
      Uri.parse('$baseUrl/api/seller/training-videos');

  static Uri sellerLegalDocumentUri(String type) =>
      Uri.parse('$baseUrl/api/seller/legal/document?type=$type');

  static Uri sellerCuisinesUri() => Uri.parse('$baseUrl/api/seller/cuisines');

  static Uri sellerSuperCategoriesUri() =>
      Uri.parse('$baseUrl/api/seller/super-categories');

  static Uri sellerDishCategoriesUri() =>
      Uri.parse('$baseUrl/api/seller/dish-categories');

  static Uri sellerZonesUri() => Uri.parse('$baseUrl/api/seller/zones');

  static Uri kitchenStatusUri() =>
      Uri.parse('$baseUrl/api/seller/kitchen-status');

  static Uri kitchenProfileUri() =>
      Uri.parse('$baseUrl/api/seller/kitchen-profile');

  static Uri kitchenProfileUpdateUri() =>
      Uri.parse('$baseUrl/api/seller/kitchen-profile/update');

  static Uri kitchenAnnouncementUri() =>
      Uri.parse('$baseUrl/api/seller/kitchen-announcement');

  static Uri kitchenAnnouncementUpdateUri() =>
      Uri.parse('$baseUrl/api/seller/kitchen-announcement/update');

  static Uri kitchenCuisinesUri() =>
      Uri.parse('$baseUrl/api/seller/kitchen-cuisines');

  static Uri kitchenCuisinesUpdateUri() =>
      Uri.parse('$baseUrl/api/seller/kitchen-cuisines/update');

  static Uri sellerDishesUri() => Uri.parse('$baseUrl/api/seller/dishes');

  static Uri sellerDishesStoreUri() =>
      Uri.parse('$baseUrl/api/seller/dishes/store');

  static Uri sellerDishesUpdateUri() =>
      Uri.parse('$baseUrl/api/seller/dishes/update');

  static Uri sellerDishesDeleteUri() =>
      Uri.parse('$baseUrl/api/seller/dishes/delete');

  static Uri sellerDishesAvailabilityUri() =>
      Uri.parse('$baseUrl/api/seller/dishes/availability');

  static Uri sellerAddonsUri() => Uri.parse('$baseUrl/api/seller/addons');

  static Uri sellerAddonsStoreUri() =>
      Uri.parse('$baseUrl/api/seller/addons/store');

  static Uri sellerAddonsUpdateUri() =>
      Uri.parse('$baseUrl/api/seller/addons/update');

  static Uri sellerAddonsDeleteUri() =>
      Uri.parse('$baseUrl/api/seller/addons/delete');

  static Uri sellerCouponsUri() => Uri.parse('$baseUrl/api/seller/coupons');

  static Uri sellerCouponsStoreUri() =>
      Uri.parse('$baseUrl/api/seller/coupons/store');

  static Uri sellerCouponsUpdateUri() =>
      Uri.parse('$baseUrl/api/seller/coupons/update');

  static Uri sellerCouponsActiveUri() =>
      Uri.parse('$baseUrl/api/seller/coupons/active');

  static Uri sellerCouponsDeleteUri() =>
      Uri.parse('$baseUrl/api/seller/coupons/delete');

  static Uri sellerDeviceTokenUri() =>
      Uri.parse('$baseUrl/api/seller/device-token');
}
