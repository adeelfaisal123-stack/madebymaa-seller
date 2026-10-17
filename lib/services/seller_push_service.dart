import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../config/optica2_asset_url.dart';
import '../config/optica2_config.dart';
import '../firebase_bootstrap.dart';
import '../seller_auth_prefs.dart';
import '../seller_session_prefs.dart';
import 'optica2_api.dart';
import 'seller_auth_navigation.dart';

/// FCM setup and device-token sync for seller push notifications.
abstract final class SellerPushService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _backgroundPluginReady = false;
  static bool _tokenRefreshBound = false;
  static Future<void>? _initFuture;

  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Call from [MaterialApp.navigatorKey].
  static void bindNavigator(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    WidgetsFlutterBinding.ensureInitialized();
    await ensureFirebaseInitialized();
    await _ensureLocalNotificationsPlugin();

    if (message.notification != null) {
      return;
    }

    await _presentNotification(message);
  }

  /// Ensures FCM + local notifications are ready (idempotent).
  static Future<void> ensureReady() {
    return _initFuture ??= initialize();
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    await ensureFirebaseInitialized();
    await _ensureLocalNotificationsPlugin();

    if (!kIsWeb) {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
    }

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
    _initialized = true;

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      await _handlePayload(initial.data);
    }
  }

  static Future<void> _ensureLocalNotificationsPlugin() async {
    if (_backgroundPluginReady) return;

    if (!kIsWeb) {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: android);
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      const channel = AndroidNotificationChannel(
        'seller_alerts',
        'Seller alerts',
        description: 'Kitchen approval and account updates',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    _backgroundPluginReady = true;
  }

  static Future<String?> getToken() async {
    await ensureReady();
    try {
      return await _messaging.getToken();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM getToken failed: $e');
      }
      return null;
    }
  }

  /// Saves FCM token on Optica2 for admin-triggered pushes (e.g. KYC approved).
  static Future<bool> registerDevice({
    required Optica2Api api,
    required String phoneE164,
    int? sellerId,
  }) async {
    await ensureReady();

    final token = await getToken();
    if (token == null || token.isEmpty) {
      if (kDebugMode) {
        debugPrint('FCM registerDevice: no token (check Firebase / Play Services)');
      }
      return false;
    }

    final ok = await api.registerDeviceToken(
      phoneE164: phoneE164,
      fcmToken: token,
      sellerId: sellerId,
    );

    if (kDebugMode) {
      debugPrint(
        ok
            ? 'FCM token registered for seller ${sellerId ?? "?"}'
            : 'FCM token registration failed (API unreachable or seller not found)',
      );
    }

    if (!_tokenRefreshBound) {
      _tokenRefreshBound = true;
      _messaging.onTokenRefresh.listen((newToken) async {
        await api.registerDeviceToken(
          phoneE164: phoneE164,
          fcmToken: newToken,
          sellerId: sellerId,
        );
      });
    }

    return ok;
  }

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    await _presentNotification(message);
    await _handlePayload(message.data);
  }

  static void _onMessageOpened(RemoteMessage message) {
    unawaited(_handlePayload(message.data));
  }

  static void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload);
      if (data is Map<String, dynamic>) {
        unawaited(_handlePayload(data));
      }
    } catch (_) {}
  }

  static Future<void> _presentNotification(RemoteMessage message) async {
    if (kIsWeb) return;

    final data = message.data;
    final notification = message.notification;
    final title = _stringFrom(data['title']) ?? notification?.title;
    final body = _stringFrom(data['body']) ?? notification?.body;
    if (title == null && body == null) return;

    final imageUrl = _resolveImageUrl(data, notification);
    final style = await _bigPictureStyle(
      imageUrl: imageUrl,
      title: title,
      body: body,
    );

    if (kDebugMode && imageUrl != null && style == null) {
      debugPrint('Push image not shown — failed to load: $imageUrl');
    }

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'seller_alerts',
          'Seller alerts',
          channelDescription: 'Kitchen approval and account updates',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: style,
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  static String? _stringFrom(Object? value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String? _resolveImageUrl(
    Map<String, dynamic> data,
    RemoteNotification? notification,
  ) {
    final path = _stringFrom(data['image_path']);
    if (path != null) {
      final clean = path.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
      return Optica2AssetUrl.resolve('/uploads/$clean') ??
          '${Optica2Config.baseUrl}/uploads/$clean';
    }

    final fromData = _stringFrom(data['image_url']);
    if (fromData != null) {
      return _replaceLocalhost(fromData);
    }

    final fromAndroid = notification?.android?.imageUrl;
    if (fromAndroid != null && fromAndroid.isNotEmpty) {
      return _replaceLocalhost(fromAndroid);
    }

    final fromApple = notification?.apple?.imageUrl;
    if (fromApple != null && fromApple.isNotEmpty) {
      return _replaceLocalhost(fromApple);
    }

    return null;
  }

  static String _replaceLocalhost(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    if (uri.host != 'localhost' && uri.host != '127.0.0.1') {
      return url;
    }
    final api = Uri.parse(Optica2Config.baseUrl);
    return uri.replace(host: api.host, port: api.hasPort ? api.port : null).toString();
  }

  /// Big picture style: title and body above, image below when expanded.
  static Future<StyleInformation?> _bigPictureStyle({
    required String? imageUrl,
    String? title,
    String? body,
  }) async {
    if (imageUrl == null || imageUrl.isEmpty || kIsWeb) return null;

    try {
      final response = await http
          .get(Uri.parse(imageUrl))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('Push image HTTP ${response.statusCode}: $imageUrl');
        }
        return null;
      }

      final bytes = Uint8List.fromList(response.bodyBytes);
      final bitmap = ByteArrayAndroidBitmap(bytes);

      return BigPictureStyleInformation(
        bitmap,
        contentTitle: title,
        summaryText: body,
        hideExpandedLargeIcon: true,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Push image load failed: $e ($imageUrl)');
      }
      return null;
    }
  }

  static Future<void> _handlePayload(Map<String, dynamic> data) async {
    final type = data['type']?.toString();
    if (type == null || type.isEmpty) return;

    final sellerId = int.tryParse(data['seller_id']?.toString() ?? '') ??
        await SellerSessionPrefs.sellerId();
    final phone = await SellerAuthPrefs.phoneE164();

    final context = _navigatorKey?.currentContext;
    if (context == null || !context.mounted) return;

    switch (type) {
      case 'registration_approved':
        SellerAuthNavigation.openHome(context, skipKycGuard: true);
      case 'registration_rejected':
        if (sellerId != null && phone != null && phone.isNotEmpty) {
          SellerAuthNavigation.openKyc(
            context,
            sellerId: sellerId,
            phoneE164: phone,
          );
        }
      case 'kyc_approved':
        SellerAuthNavigation.openHome(context, skipKycGuard: true);
      case 'kyc_rejected':
        if (phone != null && phone.isNotEmpty) {
          SellerAuthNavigation.openDocumentKyc(
            context,
            phoneE164: phone,
            initialStatus: SellerDocumentKycStatusKind.rejected,
          );
        }
      case 'kyc_pending':
        if (sellerId != null && phone != null && phone.isNotEmpty) {
          SellerAuthNavigation.openKycPending(
            context,
            sellerId: sellerId,
            phoneE164: phone,
            message: data['body']?.toString(),
          );
        }
      case 'kitchen_update':
      case 'general':
      case 'new_order':
      case 'order_status_updated':
        break;
    }
  }
}
