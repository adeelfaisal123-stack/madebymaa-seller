import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../config/optica2_config.dart';
import '../utils/msg91_phone.dart';
import '../models/seller_cuisine.dart';
import '../models/seller_super_category.dart';
import '../models/seller_account_profile.dart';
import '../models/seller_address_info.dart';
import '../models/seller_bank_details.dart';
import '../models/seller_addon.dart';
import '../models/seller_coupon.dart';
import '../models/seller_dish.dart';
import '../models/seller_dish_category.dart';
import '../models/seller_kitchen_announcement.dart';
import '../models/seller_kitchen_cuisines.dart';
import '../models/seller_kitchen_profile.dart';
import '../models/seller_legal_document.dart';
import '../models/seller_help_support.dart';
import '../models/seller_notification.dart';
import '../models/kitchen_open_meal.dart';
import '../models/kitchen_upcoming_day.dart';
import '../models/seller_document_kyc_info.dart';
import '../models/seller_kyc_agreement_template.dart';
import '../models/otp_config.dart';
import '../models/otp_send_result.dart';
import '../models/seller_dashboard.dart';
import '../models/seller_order.dart';
import '../models/seller_training_video.dart';
import '../models/seller_payout_method.dart';
import '../models/seller_wallet.dart';
import '../models/seller_zone.dart';
import '../models/kyc_upload_file.dart';

/// Document KYC (Aadhaar / FSSAI) from `users.seller_kyc_status`.
enum SellerDocumentKycStatusKind {
  notSubmitted,
  pending,
  approved,
  rejected,
  unknown;

  static SellerDocumentKycStatusKind fromApi(String? value) {
    switch (value) {
      case 'not_submitted':
        return SellerDocumentKycStatusKind.notSubmitted;
      case 'pending':
        return SellerDocumentKycStatusKind.pending;
      case 'approved':
        return SellerDocumentKycStatusKind.approved;
      case 'rejected':
        return SellerDocumentKycStatusKind.rejected;
      default:
        return SellerDocumentKycStatusKind.unknown;
    }
  }

  bool get needsBanner => this != SellerDocumentKycStatusKind.approved;

  bool get isRejected => this == SellerDocumentKycStatusKind.rejected;

  bool get canUpload =>
      this == SellerDocumentKycStatusKind.notSubmitted ||
      this == SellerDocumentKycStatusKind.rejected;

  String get displayLabel => switch (this) {
        SellerDocumentKycStatusKind.notSubmitted => 'Not submitted',
        SellerDocumentKycStatusKind.pending => 'Pending review',
        SellerDocumentKycStatusKind.approved => 'Approved',
        SellerDocumentKycStatusKind.rejected => 'Rejected',
        SellerDocumentKycStatusKind.unknown => 'Unknown',
      };
}

/// Registration / zone KYC from `users.seller_registration_status`.
enum SellerKycStatusKind {
  notRegistered,
  notSubmitted,
  pending,
  approved,
  rejected,
  blocked,
  unknown;

  static SellerKycStatusKind fromApi(String? value) {
    switch (value) {
      case 'not_registered':
        return SellerKycStatusKind.notRegistered;
      case 'not_submitted':
        return SellerKycStatusKind.notSubmitted;
      case 'pending':
        return SellerKycStatusKind.pending;
      case 'approved':
        return SellerKycStatusKind.approved;
      case 'rejected':
        return SellerKycStatusKind.rejected;
      case 'blocked':
        return SellerKycStatusKind.blocked;
      default:
        return SellerKycStatusKind.unknown;
    }
  }
}

class SellerPhoneCheckResult {
  const SellerPhoneCheckResult({
    required this.exists,
    required this.canLogin,
    required this.kycPending,
    required this.kycAwaitingApproval,
    required this.kitchenSetupPending,
    required this.kycStatus,
    required this.documentKycStatus,
    required this.message,
    this.kitchenBlocked = false,
    this.documentKyc,
    this.bankDetails,
    this.sellerId,
    this.sellerName,
    this.phoneE164,
    this.sellerProfile,
  });

  final bool exists;
  final bool canLogin;
  final bool kitchenBlocked;
  /// Must complete delivery zone (not submitted or rejected).
  final bool kycPending;
  /// Submitted to admin; waiting for approval in database.
  final bool kycAwaitingApproval;
  /// Approved but kitchen profile not created yet.
  final bool kitchenSetupPending;
  final SellerKycStatusKind kycStatus;
  final SellerDocumentKycStatusKind documentKycStatus;
  final String message;
  final SellerDocumentKycInfo? documentKyc;
  final SellerBankDetails? bankDetails;
  final int? sellerId;
  final String? sellerName;
  final String? phoneE164;
  final SellerAccountProfile? sellerProfile;

  bool get needsKycForm =>
      kycPending && sellerId != null && !kycAwaitingApproval;

  bool get needsKitchenSetup =>
      kitchenSetupPending && sellerId != null && canLogin;

  bool get isAwaitingAdminApproval =>
      kycAwaitingApproval || kycStatus == SellerKycStatusKind.pending;

  bool get isNotRegistered =>
      !exists || kycStatus == SellerKycStatusKind.notRegistered;

  factory SellerPhoneCheckResult.fromJson(Map<String, dynamic> json) {
    final seller = json['seller'];
    String? name;
    String? phone;
    int? id;
    SellerAccountProfile? sellerProfile;
    if (seller is Map<String, dynamic>) {
      sellerProfile = SellerAccountProfile.fromJson(seller);
      name = seller['name'] as String?;
      phone = seller['phone'] as String?;
      final rawId = seller['id'];
      if (rawId is int) {
        id = rawId;
      } else if (rawId is num) {
        id = rawId.toInt();
      }
    }
    final statusRaw = json['kyc_status'] as String?;
    final documentRaw = json['document_kyc_status'] as String?;
    final documentKycJson = json['document_kyc'];
    SellerDocumentKycInfo? documentKyc;
    if (documentKycJson is Map<String, dynamic>) {
      documentKyc = SellerDocumentKycInfo.fromJson(documentKycJson);
    }
    final bankJson = json['bank_details'];
    final bankDetails = bankJson is Map<String, dynamic>
        ? SellerBankDetails.fromJson(bankJson)
        : const SellerBankDetails();
    return SellerPhoneCheckResult(
      exists: json['exists'] == true,
      canLogin: json['can_login'] == true,
      kycPending: json['kyc_pending'] == true,
      kycAwaitingApproval: json['kyc_awaiting_approval'] == true,
      kitchenSetupPending: json['kitchen_setup_pending'] == true,
      kycStatus: SellerKycStatusKind.fromApi(statusRaw),
      documentKycStatus: documentKyc?.status ??
          SellerDocumentKycStatusKind.fromApi(documentRaw),
      message: (json['message'] as String?) ?? 'Unable to verify phone number.',
      kitchenBlocked: json['kitchen_blocked'] == true,
      documentKyc: documentKyc,
      bankDetails: bankDetails,
      sellerId: id,
      sellerName: name,
      phoneE164: phone,
      sellerProfile: sellerProfile,
    );
  }
}

class KitchenStatusResult {
  const KitchenStatusResult({
    required this.kitchenOpen,
    required this.kitchenBlocked,
    required this.openDays,
    required this.documentKycStatus,
    required this.message,
    this.kitchenOpenMeals = const [],
    this.upcomingKitchenDays = const [],
    this.sellerId,
    this.sellerName,
    this.phoneE164,
  });

  final bool kitchenOpen;
  final List<String> kitchenOpenMeals;
  final List<KitchenUpcomingDayPlan> upcomingKitchenDays;
  final bool kitchenBlocked;
  final Map<String, bool> openDays;
  final SellerDocumentKycStatusKind documentKycStatus;
  final String message;
  final int? sellerId;
  final String? sellerName;
  final String? phoneE164;

  factory KitchenStatusResult.fromJson(Map<String, dynamic> json) {
    final seller = json['seller'];
    int? id;
    String? name;
    String? phone;
    if (seller is Map<String, dynamic>) {
      final rawId = seller['id'];
      if (rawId is int) {
        id = rawId;
      } else if (rawId is num) {
        id = rawId.toInt();
      }
      name = seller['name'] as String?;
      phone = seller['phone'] as String?;
    }
    final openDaysRaw = json['open_days'];
    final openDays = <String, bool>{};
    if (openDaysRaw is Map) {
      for (final entry in openDaysRaw.entries) {
        openDays[entry.key.toString()] = entry.value == true;
      }
    }

    return KitchenStatusResult(
      kitchenOpen: json['kitchen_open'] == true,
      kitchenOpenMeals: parseKitchenOpenMeals(json['kitchen_open_meals']),
      upcomingKitchenDays:
          parseUpcomingKitchenDays(json['upcoming_kitchen_days']),
      kitchenBlocked: json['kitchen_blocked'] == true,
      openDays: openDays,
      documentKycStatus: SellerDocumentKycStatusKind.fromApi(
        json['document_kyc_status'] as String?,
      ),
      message: (json['message'] as String?) ?? 'OK',
      sellerId: id,
      sellerName: name,
      phoneE164: phone,
    );
  }
}

class SellerRegisterResult {
  const SellerRegisterResult({
    required this.message,
    required this.sellerId,
    required this.phoneE164,
    this.sellerName,
  });

  final String message;
  final int sellerId;
  final String phoneE164;
  final String? sellerName;
}

class Optica2ApiException implements Exception {
  Optica2ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Hides Laravel/SQL internals from sign-in and other user-facing screens.
String userFacingApiMessage(
  Map<String, dynamic>? body, {
  required String fallback,
  int? statusCode,
}) {
  if (statusCode != null && statusCode >= 500) {
    return 'Optica2 server error. Try again later.';
  }
  final raw = body?['message'];
  if (raw is String && _looksLikeInternalServerError(raw)) {
    return 'Optica2 server error. Try again later.';
  }
  if (raw is String && raw.trim().isNotEmpty) {
    return raw;
  }
  return fallback;
}

bool _looksLikeInternalServerError(String message) {
  final lower = message.toLowerCase();
  return lower.contains('sqlstate') ||
      lower.contains('access denied for user') ||
      lower.contains('queryexception') ||
      lower.contains('connection refused') ||
      lower.contains('could not find driver');
}

/// Calls Optica2 before Firebase OTP to ensure the number is a registered vendor.
class Optica2Api {
  Optica2Api({
    http.Client? client,
    bool recoverHostOnFailure = true,
  })  : _client = client ?? http.Client(),
        _recoverHostOnFailure = recoverHostOnFailure;

  final http.Client _client;
  final bool _recoverHostOnFailure;

  /// Looks up a seller phone without treating "not registered" as an error.
  Future<SellerPhoneCheckResult> probeSellerPhone(String phoneE164) async {
    final result = await _postCheckPhone(phoneE164);
    if (result == null) {
      throw Optica2ApiException('Unexpected response from Optica2.');
    }
    return result;
  }

  /// Ensures the phone belongs to an active seller (throws if not registered).
  Future<SellerPhoneCheckResult> checkSellerPhone(String phoneE164) async {
    final result = await probeSellerPhone(phoneE164);

    if (result.isNotRegistered) {
      throw Optica2ApiException(
        result.message,
        statusCode: 404,
      );
    }

    if (result.needsKycForm || result.isAwaitingAdminApproval) {
      return result;
    }

    if (!result.canLogin) {
      throw Optica2ApiException(
        result.message,
        statusCode: 403,
      );
    }

    return result;
  }

  Future<SellerPhoneCheckResult?> _postCheckPhone(String phoneE164) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (Optica2Config.apiKey.isNotEmpty) {
      headers['X-Seller-Api-Key'] = Optica2Config.apiKey;
    }

    http.Response response;
    try {
      response = await _client
          .post(
            Optica2Config.checkPhoneUri(),
            headers: headers,
            body: jsonEncode({'phone': phoneE164}),
          )
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      await _failUnreachable(e);
    }

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      }
    } catch (_) {
      // ignore malformed JSON
    }

    if (response.statusCode == 401) {
      throw Optica2ApiException(
        body?['message'] as String? ?? 'Invalid API key.',
        statusCode: 401,
      );
    }

    if (response.statusCode >= 500) {
      throw Optica2ApiException(
        'Optica2 server error. Try again later.',
        statusCode: response.statusCode,
      );
    }

    if (body == null) {
      return null;
    }

    return SellerPhoneCheckResult.fromJson(body);
  }

  /// Lists cuisines for kitchen registration (from admin).
  Future<List<SellerCuisine>> fetchCuisines() async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (Optica2Config.apiKey.isNotEmpty) {
      headers['X-Seller-Api-Key'] = Optica2Config.apiKey;
    }

    http.Response response;
    try {
      response = await _client
          .get(Optica2Config.sellerCuisinesUri(), headers: headers)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      await _failUnreachable(e);
    }

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      }
    } catch (_) {}

    if (response.statusCode != 200 || body == null) {
      throw Optica2ApiException(
        body?['message'] as String? ?? 'Could not load cuisines.',
        statusCode: response.statusCode,
      );
    }

    final raw = body['cuisines'];
    final list = <SellerCuisine>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          list.add(SellerCuisine.fromJson(item));
        }
      }
    }
    return list;
  }

  /// Active meal windows (Breakfast, Lunch, Evening, etc.) from admin.
  Future<List<SellerSuperCategory>> fetchSuperCategories() async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (Optica2Config.apiKey.isNotEmpty) {
      headers['X-Seller-Api-Key'] = Optica2Config.apiKey;
    }

    http.Response response;
    try {
      response = await _client
          .get(Optica2Config.sellerSuperCategoriesUri(), headers: headers)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      await _failUnreachable(e);
    }

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      }
    } catch (_) {}

    if (response.statusCode != 200 || body == null) {
      throw Optica2ApiException(
        body?['message'] as String? ?? 'Could not load meal categories.',
        statusCode: response.statusCode,
      );
    }

    final raw = body['super_categories'];
    if (raw is! List) return const [];

    return raw
        .whereType<Map<String, dynamic>>()
        .map(SellerSuperCategory.fromJson)
        .toList();
  }

  /// Active menu categories with nested sub categories (Biryani, Rice, etc.).
  Future<List<SellerDishCategory>> fetchDishCategories() async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (Optica2Config.apiKey.isNotEmpty) {
      headers['X-Seller-Api-Key'] = Optica2Config.apiKey;
    }

    http.Response response;
    try {
      response = await _client
          .get(Optica2Config.sellerDishCategoriesUri(), headers: headers)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      await _failUnreachable(e);
    }

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      }
    } catch (_) {}

    if (response.statusCode != 200 || body == null) {
      throw Optica2ApiException(
        body?['message'] as String? ?? 'Could not load categories.',
        statusCode: response.statusCode,
      );
    }

    final raw = body['dish_categories'];
    if (raw is! List) return const [];

    return raw
        .whereType<Map<String, dynamic>>()
        .map(SellerDishCategory.fromJson)
        .where((c) => c.id > 0)
        .toList();
  }

  /// Registers a new seller with personal details only; admin approval follows.
  Future<SellerRegisterResult> registerSellerMinimal({
    required String phoneE164,
    required String name,
    required String email,
    required String address,
    required String city,
    required String state,
    required String country,
  }) async {
    final request = http.MultipartRequest('POST', Optica2Config.registerUri());
    request.headers['Accept'] = 'application/json';
    if (Optica2Config.apiKey.isNotEmpty) {
      request.headers['X-Seller-Api-Key'] = Optica2Config.apiKey;
    }

    request.fields.addAll({
      'phone': phoneE164,
      'name': name,
      'email': email.trim(),
      'address': address,
      'city': city,
      'state': state,
      'country': country,
    });

    return _parseRegisterResponse(request, phoneE164);
  }

  /// Creates kitchen profile after admin approval.
  Future<SellerRegisterResult> setupSellerKitchen({
    required String phoneE164,
    required String businessName,
    required List<int> cuisineIds,
    required int deliveryMinutesMin,
    required int deliveryMinutesMax,
    required XFile logo,
    int? sellerId,
  }) async {
    final request =
        http.MultipartRequest('POST', Optica2Config.setupKitchenUri());
    request.headers['Accept'] = 'application/json';
    if (Optica2Config.apiKey.isNotEmpty) {
      request.headers['X-Seller-Api-Key'] = Optica2Config.apiKey;
    }

    request.fields.addAll({
      'phone': phoneE164,
      'business_name': businessName,
      'delivery_minutes_min': deliveryMinutesMin.toString(),
      'delivery_minutes_max': deliveryMinutesMax.toString(),
      if (sellerId != null) 'seller_id': sellerId.toString(),
    });
    for (var i = 0; i < cuisineIds.length; i++) {
      request.fields['cuisine_ids[$i]'] = cuisineIds[i].toString();
    }

    final logoBytes = await logo.readAsBytes();
    request.files.add(
      http.MultipartFile.fromBytes(
        'logo',
        logoBytes,
        filename: _imageUploadName(logo, 'kitchen_logo'),
      ),
    );

    return _parseRegisterResponse(request, phoneE164);
  }

  Future<SellerRegisterResult> _parseRegisterResponse(
    http.MultipartRequest request,
    String phoneE164,
  ) async {
    http.Response response;
    try {
      final streamed =
          await _client.send(request).timeout(const Duration(seconds: 60));
      response = await http.Response.fromStream(streamed);
    } catch (e) {
      await _failUnreachable(e);
    }

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      }
    } catch (_) {}

    final message = body?['message'] as String?;

    if (response.statusCode == 401) {
      throw Optica2ApiException(
        message ?? 'Invalid API key.',
        statusCode: 401,
      );
    }

    if (response.statusCode == 422) {
      final errors = body?['errors'];
      if (errors is Map<String, dynamic>) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) {
          throw Optica2ApiException(first.first.toString(), statusCode: 422);
        }
      }
      throw Optica2ApiException(
        message ?? 'Please check your details and try again.',
        statusCode: 422,
      );
    }

    if (response.statusCode >= 500) {
      throw Optica2ApiException(
        'Optica2 server error. Try again later.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Optica2ApiException(
        message ?? 'Registration failed.',
        statusCode: response.statusCode,
      );
    }

    final seller = body?['seller'];
    int? sellerId;
    String? sellerName;
    if (seller is Map<String, dynamic>) {
      final id = seller['id'];
      if (id is int) {
        sellerId = id;
      } else if (id is num) {
        sellerId = id.toInt();
      }
      sellerName = seller['name'] as String?;
    }

    if (sellerId == null) {
      throw Optica2ApiException(
        'Registration succeeded but seller id was missing.',
        statusCode: response.statusCode,
      );
    }

    return SellerRegisterResult(
      message: message ?? 'Signup completed. Please wait for admin approval.',
      sellerId: sellerId,
      phoneE164: phoneE164,
      sellerName: sellerName,
    );
  }

  /// Google Maps API key saved in Optica2 admin (System settings).
  Future<SellerMapsConfig> fetchMapsConfig() async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (Optica2Config.apiKey.isNotEmpty) {
      headers['X-Seller-Api-Key'] = Optica2Config.apiKey;
    }

    http.Response response;
    try {
      response = await _client
          .get(Optica2Config.sellerMapsConfigUri(), headers: headers)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      await _failUnreachable(e);
    }

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      }
    } catch (_) {}

    if (response.statusCode != 200 || body == null) {
      throw Optica2ApiException(
        body?['message'] as String? ?? 'Could not load maps settings.',
        statusCode: response.statusCode,
      );
    }

    final mapsRaw = body['maps'];
    if (mapsRaw is Map<String, dynamic>) {
      return SellerMapsConfig.fromJson(mapsRaw);
    }

    return const SellerMapsConfig(
      apiKey: '',
      defaultLat: 20.5937,
      defaultLng: 78.9629,
    );
  }

  /// Terms & conditions and privacy policy for the seller app.
  Future<SellerNotificationsResult> fetchNotifications({
    required String phoneE164,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{'phone': phoneE164};
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.sellerNotificationsUri(),
      body,
      errorFallback: 'Could not load notifications.',
    );

    return SellerNotificationsResult.fromJson(decoded);
  }

  Future<void> markNotificationRead({
    required String phoneE164,
    required int notificationId,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{
      'phone': phoneE164,
      'notification_id': notificationId,
    };
    if (sellerId != null) body['seller_id'] = sellerId;

    await _postJson(
      Optica2Config.sellerNotificationsReadUri(),
      body,
      errorFallback: 'Could not update notification.',
    );
  }

  Future<SellerLegalDocuments> fetchSellerLegalDocuments() async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (Optica2Config.apiKey.isNotEmpty) {
      headers['X-Seller-Api-Key'] = Optica2Config.apiKey;
    }

    http.Response response;
    try {
      response = await _client
          .get(Optica2Config.sellerLegalUri(), headers: headers)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      await _failUnreachable(e);
    }

    final body = _decodeJsonMap(response);
    if (response.statusCode != 200 || body == null) {
      throw Optica2ApiException(
        body?['message'] as String? ?? 'Could not load legal documents.',
        statusCode: response.statusCode,
      );
    }

    return SellerLegalDocuments.fromJson(body);
  }

  /// Agreement PDF template uploaded from admin (document KYC step).
  Future<SellerKycAgreementTemplate> fetchSellerKycAgreement({
    required String phoneE164,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{'phone': phoneE164};
    if (sellerId != null) {
      body['seller_id'] = sellerId;
    }

    final decoded = await _postJson(
      Optica2Config.sellerKycAgreementUri(),
      body,
      errorFallback: 'Could not load seller agreement.',
    );

    final agreement = decoded['agreement'];
    if (agreement is Map<String, dynamic>) {
      return SellerKycAgreementTemplate.fromJson(agreement);
    }

    throw Optica2ApiException('Could not load seller agreement.');
  }

  /// Active training videos for the kitchen stories strip.
  Future<List<SellerTrainingVideo>> fetchTrainingVideos() async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (Optica2Config.apiKey.isNotEmpty) {
      headers['X-Seller-Api-Key'] = Optica2Config.apiKey;
    }

    http.Response response;
    try {
      response = await _client
          .get(Optica2Config.sellerTrainingVideosUri(), headers: headers)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      await _failUnreachable(e);
    }

    final body = _decodeJsonMap(response);
    if (response.statusCode != 200 || body == null) {
      throw Optica2ApiException(
        body?['message'] as String? ?? 'Could not load training videos.',
        statusCode: response.statusCode,
      );
    }

    final videos = body['videos'];
    if (videos is! List) return const [];

    return videos
        .whereType<Map<String, dynamic>>()
        .map(SellerTrainingVideo.fromJson)
        .where((video) => video.videoUrl.isNotEmpty)
        .toList();
  }

  /// Single legal document (`terms` or `privacy`).
  Future<SellerLegalDocument> fetchSellerLegalDocument({
    required String type,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (Optica2Config.apiKey.isNotEmpty) {
      headers['X-Seller-Api-Key'] = Optica2Config.apiKey;
    }

    http.Response response;
    try {
      response = await _client
          .get(Optica2Config.sellerLegalDocumentUri(type), headers: headers)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      await _failUnreachable(e);
    }

    final body = _decodeJsonMap(response);
    if (response.statusCode != 200 || body == null) {
      throw Optica2ApiException(
        body?['message'] as String? ?? 'Could not load document.',
        statusCode: response.statusCode,
      );
    }

    final docJson = body['document'];
    if (docJson is Map<String, dynamic>) {
      return SellerLegalDocument.fromJson(docJson);
    }

    throw Optica2ApiException('Could not load document.');
  }

  Future<SellerHelpSupport> fetchSellerHelpSupport() async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (Optica2Config.apiKey.isNotEmpty) {
      headers['X-Seller-Api-Key'] = Optica2Config.apiKey;
    }

    http.Response response;
    try {
      response = await _client
          .get(Optica2Config.sellerHelpSupportUri(), headers: headers)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      await _failUnreachable(e);
    }

    final body = _decodeJsonMap(response);
    if (response.statusCode != 200 || body == null) {
      throw Optica2ApiException(
        body?['message'] as String? ?? 'Could not load help & support.',
        statusCode: response.statusCode,
      );
    }

    final helpJson = body['help_support'];
    if (helpJson is Map<String, dynamic>) {
      return SellerHelpSupport.fromJson(helpJson);
    }

    return SellerHelpSupport.empty;
  }

  Map<String, dynamic>? _decodeJsonMap(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  /// Lists active delivery zones (from admin) for KYC map step.
  Future<SellerZonesResponse> fetchSellerZones() async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (Optica2Config.apiKey.isNotEmpty) {
      headers['X-Seller-Api-Key'] = Optica2Config.apiKey;
    }

    http.Response response;
    try {
      response = await _client
          .get(Optica2Config.sellerZonesUri(), headers: headers)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      await _failUnreachable(e);
    }

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      }
    } catch (_) {}

    if (response.statusCode != 200 || body == null) {
      throw Optica2ApiException(
        body?['message'] as String? ?? 'Could not load delivery zones.',
        statusCode: response.statusCode,
      );
    }

    return SellerZonesResponse.fromJson(body);
  }

  /// Submits delivery zone pin after initial registration.
  Future<String> completeSellerKyc({
    required int sellerId,
    required String phoneE164,
    required int zoneId,
    required double latitude,
    required double longitude,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (Optica2Config.apiKey.isNotEmpty) {
      headers['X-Seller-Api-Key'] = Optica2Config.apiKey;
    }

    http.Response response;
    try {
      response = await _client
          .post(
            Optica2Config.completeKycUri(),
            headers: headers,
            body: jsonEncode({
              'phone': phoneE164,
              'seller_id': sellerId,
              'zone_id': zoneId,
              'latitude': latitude,
              'longitude': longitude,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      await _failUnreachable(e);
    }
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      }
    } catch (_) {}

    final message = body?['message'] as String?;

    if (response.statusCode == 401) {
      throw Optica2ApiException(
        message ?? 'Invalid API key.',
        statusCode: 401,
      );
    }

    if (response.statusCode == 422) {
      final errors = body?['errors'];
      if (errors is Map<String, dynamic>) {
        for (final entry in errors.entries) {
          final value = entry.value;
          if (value is List && value.isNotEmpty) {
            throw Optica2ApiException(value.first.toString(), statusCode: 422);
          }
        }
      }
      throw Optica2ApiException(
        message ?? 'Please check your details and try again.',
        statusCode: 422,
      );
    }

    if (response.statusCode >= 500) {
      throw Optica2ApiException(
        'Optica2 server error. Try again later.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode != 200) {
      throw Optica2ApiException(
        message ?? 'Verification upload failed.',
        statusCode: response.statusCode,
      );
    }

    return message ??
        'Information submitted. Please wait — your KYC is pending admin approval.';
  }

  /// Registers this device for push notifications (FCM). Returns false on failure.
  Future<bool> registerDeviceToken({
    required String phoneE164,
    required String fcmToken,
    int? sellerId,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (Optica2Config.apiKey.isNotEmpty) {
      headers['X-Seller-Api-Key'] = Optica2Config.apiKey;
    }

    final body = <String, dynamic>{
      'phone': phoneE164,
      'fcm_token': fcmToken,
    };
    if (sellerId != null) {
      body['seller_id'] = sellerId;
    }

    try {
      final response = await _client
          .post(
            Optica2Config.sellerDeviceTokenUri(),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Uploads Aadhaar + FSSAI and sets document KYC to pending for admin review.
  Future<String> submitDocumentKyc({
    required String phoneE164,
    required String aadhaarNumber,
    required String fssaiNumber,
    required XFile aadhaarFront,
    required XFile aadhaarBack,
    required XFile fssaiDocument,
    required KycUploadFile agreementSignature,
    required KycUploadFile agreementPdf,
    List<int>? aadhaarFrontBytes,
    List<int>? aadhaarBackBytes,
    List<int>? fssaiDocumentBytes,
    int? sellerId,
  }) async {
    final request =
        http.MultipartRequest('POST', Optica2Config.submitDocumentKycUri());
    request.headers['Accept'] = 'application/json';
    if (Optica2Config.apiKey.isNotEmpty) {
      request.headers['X-Seller-Api-Key'] = Optica2Config.apiKey;
    }

    request.fields.addAll({
      'phone': phoneE164,
      'aadhaar_number': aadhaarNumber.trim(),
      'fssai_number': fssaiNumber.trim(),
    });
    if (sellerId != null) {
      request.fields['seller_id'] = sellerId.toString();
    }

    final frontBytes = aadhaarFrontBytes ?? await aadhaarFront.readAsBytes();
    final backBytes = aadhaarBackBytes ?? await aadhaarBack.readAsBytes();
    final fssaiBytes = fssaiDocumentBytes ?? await fssaiDocument.readAsBytes();

    request.files.addAll([
      http.MultipartFile.fromBytes(
        'aadhaar_front',
        frontBytes,
        filename: _imageUploadName(aadhaarFront, 'aadhaar_front'),
      ),
      http.MultipartFile.fromBytes(
        'aadhaar_back',
        backBytes,
        filename: _imageUploadName(aadhaarBack, 'aadhaar_back'),
      ),
      http.MultipartFile.fromBytes(
        'fssai_document',
        fssaiBytes,
        filename: _imageUploadName(fssaiDocument, 'fssai_document'),
      ),
      http.MultipartFile.fromBytes(
        'agreement_signature',
        agreementSignature.bytes,
        filename: _uploadFilename(
          agreementSignature.name,
          'agreement_signature',
        ),
      ),
      http.MultipartFile.fromBytes(
        'agreement_pdf',
        agreementPdf.bytes,
        filename: _pdfUploadFilename(agreementPdf.name),
        contentType: MediaType('application', 'pdf'),
      ),
    ]);

    http.Response response;
    try {
      final streamed =
          await _client.send(request).timeout(const Duration(seconds: 90));
      response = await http.Response.fromStream(streamed);
    } catch (e) {
      await _failUnreachable(e);
    }

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      }
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Optica2ApiException(
        body?['message'] as String? ??
            (body?['errors'] is Map
                ? _firstValidationError(body!['errors'] as Map)
                : null) ??
            'Could not upload KYC documents.',
        statusCode: response.statusCode,
      );
    }

    return body?['message'] as String? ??
        'KYC documents submitted. We will review them shortly.';
  }

  String? _firstValidationError(Map<dynamic, dynamic> errors) {
    for (final entry in errors.entries) {
      final value = entry.value;
      if (value is List && value.isNotEmpty) {
        return value.first.toString();
      }
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  /// Saves vendor bank details (bank name, IBAN, account number, account title).
  Future<SellerBankDetails> updateBankDetails({
    required String phoneE164,
    required String bankName,
    required String bankIban,
    required String bankAccountNumber,
    required String bankAccountTitle,
    int? sellerId,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (Optica2Config.apiKey.isNotEmpty) {
      headers['X-Seller-Api-Key'] = Optica2Config.apiKey;
    }

    final body = <String, dynamic>{
      'phone': phoneE164,
      'bank_name': bankName.trim(),
      'bank_iban': bankIban.replaceAll(RegExp(r'\s+'), '').toUpperCase(),
      'bank_account_number':
          bankAccountNumber.replaceAll(RegExp(r'\D'), ''),
      'bank_account_title': bankAccountTitle.trim(),
    };
    if (sellerId != null) {
      body['seller_id'] = sellerId;
    }

    http.Response response;
    try {
      response = await _client
          .put(
            Optica2Config.updateBankDetailsUri(),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      await _failUnreachable(e);
    }

    Map<String, dynamic>? decoded;
    try {
      final raw = jsonDecode(response.body);
      if (raw is Map<String, dynamic>) {
        decoded = raw;
      }
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Optica2ApiException(
        decoded?['message'] as String? ??
            (decoded?['errors'] is Map
                ? _firstValidationError(decoded!['errors'] as Map)
                : null) ??
            'Could not save bank details.',
        statusCode: response.statusCode,
      );
    }

    final bankJson = decoded?['bank_details'];
    if (bankJson is Map<String, dynamic>) {
      return SellerBankDetails.fromJson(bankJson);
    }

    return SellerBankDetails(
      bankName: bankName,
      bankIban: bankIban,
      bankAccountNumber: bankAccountNumber,
      bankAccountTitle: bankAccountTitle,
      isComplete: true,
    );
  }

  Future<SellerAccountProfile> fetchSellerProfile({
    required String phoneE164,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{'phone': phoneE164};
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.sellerProfileUri(),
      body,
      errorFallback: 'Could not load profile.',
    );

    final profile = decoded['profile'];
    if (profile is Map<String, dynamic>) {
      return SellerAccountProfile.fromJson(profile);
    }
    throw Optica2ApiException('Could not load profile.');
  }

  Future<SellerAccountProfile> updateSellerProfile({
    required String phoneE164,
    required String name,
    required String email,
    int? sellerId,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (Optica2Config.apiKey.isNotEmpty) {
      headers['X-Seller-Api-Key'] = Optica2Config.apiKey;
    }

    final body = <String, dynamic>{
      'phone': phoneE164,
      'name': name.trim(),
      'email': email.trim(),
    };
    if (sellerId != null) body['seller_id'] = sellerId;

    http.Response response;
    try {
      response = await _client
          .put(
            Optica2Config.sellerProfileUpdateUri(),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      await _failUnreachable(e);
    }

    Map<String, dynamic>? decoded;
    try {
      final raw = jsonDecode(response.body);
      if (raw is Map<String, dynamic>) {
        decoded = raw;
      }
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Optica2ApiException(
        decoded?['message'] as String? ??
            (decoded?['errors'] is Map
                ? _firstValidationError(decoded!['errors'] as Map)
                : null) ??
            'Could not update profile.',
        statusCode: response.statusCode,
      );
    }

    final profile = decoded?['profile'];
    if (profile is Map<String, dynamic>) {
      return SellerAccountProfile.fromJson(profile);
    }
    throw Optica2ApiException('Could not update profile.');
  }

  Future<SellerAddressInfo> fetchSellerAddress({
    required String phoneE164,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{'phone': phoneE164};
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.sellerAddressUri(),
      body,
      errorFallback: 'Could not load address.',
    );

    final address = decoded['address'];
    if (address is Map<String, dynamic>) {
      return SellerAddressInfo.fromJson(address);
    }
    throw Optica2ApiException('Could not load address.');
  }

  Future<SellerAddressInfo> submitSellerAddress({
    required String phoneE164,
    required String address,
    required String city,
    required String state,
    required String country,
    required int zoneId,
    required double latitude,
    required double longitude,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{
      'phone': phoneE164,
      'address': address.trim(),
      'city': city.trim(),
      'state': state.trim(),
      'country': country.trim().toUpperCase(),
      'zone_id': zoneId,
      'latitude': latitude,
      'longitude': longitude,
    };
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.sellerAddressSubmitUri(),
      body,
      errorFallback: 'Could not save address.',
    );

    final addressJson = decoded['address'];
    if (addressJson is Map<String, dynamic>) {
      return SellerAddressInfo.fromJson(addressJson);
    }
    throw Optica2ApiException('Could not save address.');
  }

  /// Reads current KYC status from the database for this seller.
  Future<SellerPhoneCheckResult> fetchSellerKycStatus({
    required String phoneE164,
    int? sellerId,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (Optica2Config.apiKey.isNotEmpty) {
      headers['X-Seller-Api-Key'] = Optica2Config.apiKey;
    }

    final body = <String, dynamic>{'phone': phoneE164};
    if (sellerId != null) {
      body['seller_id'] = sellerId;
    }

    http.Response response;
    try {
      response = await _client
          .post(
            Optica2Config.kycStatusUri(),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      await _failUnreachable(e);
    }

    Map<String, dynamic>? decoded;
    try {
      final raw = jsonDecode(response.body);
      if (raw is Map<String, dynamic>) {
        decoded = raw;
      }
    } catch (_) {}

    if (response.statusCode == 404) {
      throw Optica2ApiException(
        decoded?['message'] as String? ?? 'Seller not found.',
        statusCode: 404,
      );
    }

    if (decoded == null) {
      throw Optica2ApiException(
        'Unexpected response from Optica2.',
        statusCode: response.statusCode,
      );
    }

    decoded['exists'] = true;
    return SellerPhoneCheckResult.fromJson(decoded);
  }

  /// Reads `users.kitchen_open` for the signed-in seller.
  Future<KitchenStatusResult> fetchKitchenStatus({
    required String phoneE164,
    int? sellerId,
  }) =>
      _kitchenStatusRequest(phoneE164: phoneE164, sellerId: sellerId);

  /// Updates `users.kitchen_open` in the database.
  Future<KitchenStatusResult> updateKitchenStatus({
    required String phoneE164,
    required bool kitchenOpen,
    List<String>? kitchenOpenMeals,
    String? upcomingDaysJson,
    int? sellerId,
  }) =>
      _kitchenStatusRequest(
        phoneE164: phoneE164,
        sellerId: sellerId,
        kitchenOpen: kitchenOpen,
        kitchenOpenMeals: kitchenOpenMeals,
        upcomingDaysJson: upcomingDaysJson,
      );

  /// Saves which weekdays the kitchen is open (`restaurants.open_days`).
  Future<KitchenStatusResult> updateKitchenOpenDays({
    required String phoneE164,
    required String openDaysJson,
    int? sellerId,
  }) =>
      _kitchenStatusRequest(
        phoneE164: phoneE164,
        sellerId: sellerId,
        openDaysJson: openDaysJson,
      );

  /// Updates tomorrow and day-after schedule without toggling live kitchen.
  Future<KitchenStatusResult> updateKitchenUpcomingDays({
    required String phoneE164,
    required String upcomingDaysJson,
    int? sellerId,
  }) =>
      _kitchenStatusRequest(
        phoneE164: phoneE164,
        sellerId: sellerId,
        upcomingDaysJson: upcomingDaysJson,
      );

  Future<KitchenStatusResult> _kitchenStatusRequest({
    required String phoneE164,
    int? sellerId,
    bool? kitchenOpen,
    List<String>? kitchenOpenMeals,
    String? upcomingDaysJson,
    String? openDaysJson,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (Optica2Config.apiKey.isNotEmpty) {
      headers['X-Seller-Api-Key'] = Optica2Config.apiKey;
    }

    final body = <String, dynamic>{'phone': phoneE164};
    if (sellerId != null) {
      body['seller_id'] = sellerId;
    }
    if (kitchenOpen != null) {
      body['kitchen_open'] = kitchenOpen;
    }
    if (kitchenOpenMeals != null && kitchenOpenMeals.isNotEmpty) {
      body['kitchen_open_meals'] = kitchenOpenMeals;
    }
    if (upcomingDaysJson != null && upcomingDaysJson.isNotEmpty) {
      body['upcoming_days_json'] = upcomingDaysJson;
    }
    if (openDaysJson != null && openDaysJson.isNotEmpty) {
      body['open_days_json'] = openDaysJson;
    }

    http.Response response;
    try {
      response = await _client
          .post(
            Optica2Config.kitchenStatusUri(),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      await _failUnreachable(e);
    }

    Map<String, dynamic>? decoded;
    try {
      final raw = jsonDecode(response.body);
      if (raw is Map<String, dynamic>) {
        decoded = raw;
      }
    } catch (_) {}

    final message = decoded?['message'] as String?;

    if (response.statusCode == 401) {
      throw Optica2ApiException(
        message ?? 'Invalid API key.',
        statusCode: 401,
      );
    }

    if (response.statusCode == 403) {
      throw Optica2ApiException(
        message ?? 'Unable to update kitchen status.',
        statusCode: 403,
      );
    }

    if (response.statusCode == 404) {
      throw Optica2ApiException(
        message ?? 'Seller not found.',
        statusCode: 404,
      );
    }

    if (response.statusCode >= 500) {
      throw Optica2ApiException(
        'Optica2 server error. Try again later.',
        statusCode: response.statusCode,
      );
    }

    if (decoded == null || response.statusCode != 200) {
      throw Optica2ApiException(
        message ?? 'Unexpected response from Optica2.',
        statusCode: response.statusCode,
      );
    }

    return KitchenStatusResult.fromJson(decoded);
  }

  /// Kitchen name and logo for the signed-in seller's restaurant.
  Future<SellerKitchenProfile> fetchKitchenProfile({
    required String phoneE164,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{'phone': phoneE164};
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.kitchenProfileUri(),
      body,
      errorFallback: 'Could not load kitchen profile.',
    );

    final kitchenJson = decoded['kitchen'];
    if (kitchenJson is Map<String, dynamic>) {
      return SellerKitchenProfile.fromJson(kitchenJson);
    }
    throw Optica2ApiException('Could not load kitchen profile.');
  }

  /// Updates kitchen name and optionally replaces the logo.
  Future<SellerKitchenProfile> updateKitchenProfile({
    required String phoneE164,
    required String name,
    required int deliveryMinutesMin,
    required int deliveryMinutesMax,
    required bool instantDeliveryEnabled,
    XFile? logo,
    int? sellerId,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Optica2Config.kitchenProfileUpdateUri(),
    );
    request.headers['Accept'] = 'application/json';
    if (Optica2Config.apiKey.isNotEmpty) {
      request.headers['X-Seller-Api-Key'] = Optica2Config.apiKey;
    }

    request.fields.addAll({
      'phone': phoneE164,
      'name': name.trim(),
      'delivery_minutes_min': deliveryMinutesMin.toString(),
      'delivery_minutes_max': deliveryMinutesMax.toString(),
      'instant_delivery_enabled': instantDeliveryEnabled ? '1' : '0',
    });
    if (sellerId != null) {
      request.fields['seller_id'] = sellerId.toString();
    }

    if (logo != null) {
      final logoBytes = await logo.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'logo',
          logoBytes,
          filename: _imageUploadName(logo, 'kitchen_logo'),
        ),
      );
    }

    final decoded = await _sendMultipart(
      request,
      'Could not update kitchen profile.',
    );

    final kitchenJson = decoded['kitchen'];
    if (kitchenJson is Map<String, dynamic>) {
      return SellerKitchenProfile.fromJson(kitchenJson);
    }
    throw Optica2ApiException('Could not update kitchen profile.');
  }

  /// Kitchen announcement title and description.
  Future<SellerKitchenAnnouncement> fetchKitchenAnnouncement({
    required String phoneE164,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{'phone': phoneE164};
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.kitchenAnnouncementUri(),
      body,
      errorFallback: 'Could not load announcement.',
    );

    final announcementJson = decoded['announcement'];
    if (announcementJson is Map<String, dynamic>) {
      return SellerKitchenAnnouncement.fromJson(announcementJson);
    }
    throw Optica2ApiException('Could not load announcement.');
  }

  /// Updates kitchen announcement title and description.
  Future<SellerKitchenAnnouncement> updateKitchenAnnouncement({
    required String phoneE164,
    required String? title,
    required String? description,
    required KitchenAnnouncementType? type,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{
      'phone': phoneE164,
      'title': title?.trim() ?? '',
      'description': description?.trim() ?? '',
      'type': type?.apiValue ?? '',
    };
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.kitchenAnnouncementUpdateUri(),
      body,
      errorFallback: 'Could not update announcement.',
    );

    final announcementJson = decoded['announcement'];
    if (announcementJson is Map<String, dynamic>) {
      return SellerKitchenAnnouncement.fromJson(announcementJson);
    }
    throw Optica2ApiException('Could not update announcement.');
  }

  Future<SellerKitchenCuisines> fetchKitchenCuisines({
    required String phoneE164,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{'phone': phoneE164};
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.kitchenCuisinesUri(),
      body,
      errorFallback: 'Could not load cuisines.',
    );

    final json = decoded['kitchen_cuisines'];
    if (json is Map<String, dynamic>) {
      return SellerKitchenCuisines.fromJson(json);
    }
    throw Optica2ApiException('Could not load cuisines.');
  }

  Future<SellerKitchenCuisines> updateKitchenCuisines({
    required String phoneE164,
    required List<int> cuisineIds,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{
      'phone': phoneE164,
      'cuisine_ids': cuisineIds,
    };
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.kitchenCuisinesUpdateUri(),
      body,
      errorFallback: 'Could not update cuisines.',
    );

    final json = decoded['kitchen_cuisines'];
    if (json is Map<String, dynamic>) {
      return SellerKitchenCuisines.fromJson(json);
    }
    throw Optica2ApiException('Could not update cuisines.');
  }

  static String _imageUploadName(XFile file, String fallback) {
    return _uploadFilename(file.name, fallback);
  }

  static String _uploadFilename(String name, String fallback) {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty && trimmed.contains('.')) return trimmed;
    return '$fallback.jpg';
  }

  static String _pdfUploadFilename(String name) {
    final trimmed = name.trim();
    if (trimmed.toLowerCase().endsWith('.pdf')) return trimmed;
    if (trimmed.isNotEmpty) return '$trimmed.pdf';
    return 'seller-agreement.pdf';
  }

  /// Home dashboard stats, earnings, and pending orders.
  Future<SellerDashboard> fetchDashboard({
    required String phoneE164,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{'phone': phoneE164};
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.sellerDashboardUri(),
      body,
      errorFallback: 'Could not load dashboard.',
    );

    final dashboard = decoded['dashboard'];
    if (dashboard is Map<String, dynamic>) {
      return SellerDashboard.fromJson(dashboard);
    }
    return SellerDashboard.empty;
  }

  /// Lists orders for the vendor's kitchen.
  Future<List<SellerOrder>> fetchOrders({
    required String phoneE164,
    int? sellerId,
    SellerOrderFilter filter = SellerOrderFilter.all,
  }) async {
    final body = <String, dynamic>{
      'phone': phoneE164,
      'filter': filter.apiValue,
    };
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.sellerOrdersUri(),
      body,
      errorFallback: 'Could not load orders.',
    );

    final orders = decoded['orders'];
    if (orders is List) {
      return orders
          .whereType<Map<String, dynamic>>()
          .map(SellerOrder.fromJson)
          .toList();
    }
    return const [];
  }

  /// Full order detail for the vendor's kitchen.
  Future<SellerOrderDetail> fetchOrderDetail({
    required String phoneE164,
    required int orderId,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{
      'phone': phoneE164,
      'order_id': orderId,
    };
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.sellerOrderShowUri(),
      body,
      errorFallback: 'Could not load order details.',
    );

    final order = decoded['order'];
    if (order is Map<String, dynamic>) {
      return SellerOrderDetail.fromJson(order);
    }
    throw Optica2ApiException('Could not load order details.');
  }

  /// Marks an accepted order as ready for pickup.
  Future<SellerOrderDetail> markOrderReady({
    required String phoneE164,
    required int orderId,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{
      'phone': phoneE164,
      'order_id': orderId,
    };
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.sellerOrderMarkReadyUri(),
      body,
      errorFallback: 'Could not update order status.',
    );

    final order = decoded['order'];
    if (order is Map<String, dynamic>) {
      return SellerOrderDetail.fromJson(order);
    }
    throw Optica2ApiException('Could not update order status.');
  }

  /// Accepts a pending order from the kitchen.
  Future<SellerOrderDetail> acceptOrder({
    required String phoneE164,
    required int orderId,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{
      'phone': phoneE164,
      'order_id': orderId,
    };
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.sellerOrderAcceptUri(),
      body,
      errorFallback: 'Could not accept order.',
    );

    final order = decoded['order'];
    if (order is Map<String, dynamic>) {
      return SellerOrderDetail.fromJson(order);
    }
    throw Optica2ApiException('Could not accept order.');
  }

  /// Marks a ready order as picked up by the seller/rider handoff.
  Future<SellerOrderDetail> markOrderPickedUp({
    required String phoneE164,
    required int orderId,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{
      'phone': phoneE164,
      'order_id': orderId,
    };
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.sellerOrderMarkPickedUpUri(),
      body,
      errorFallback: 'Could not mark order picked up.',
    );

    final order = decoded['order'];
    if (order is Map<String, dynamic>) {
      return SellerOrderDetail.fromJson(order);
    }
    throw Optica2ApiException('Could not mark order picked up.');
  }

  /// Wallet balance, credits, and withdrawal history.
  Future<SellerWalletSnapshot> fetchWallet({
    required String phoneE164,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{'phone': phoneE164};
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.sellerWalletUri(),
      body,
      errorFallback: 'Could not load wallet.',
    );

    return SellerWalletSnapshot.fromJson(decoded);
  }

  /// Request payout to saved bank details.
  Future<SellerWalletWithdrawal> requestWalletWithdrawal({
    required String phoneE164,
    required double amount,
    required int payoutMethodId,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{
      'phone': phoneE164,
      'amount': amount,
      'payout_method_id': payoutMethodId,
    };
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.sellerWalletWithdrawUri(),
      body,
      errorFallback: 'Could not request withdrawal.',
    );

    final withdrawal = decoded['withdrawal'];
    if (withdrawal is Map<String, dynamic>) {
      return SellerWalletWithdrawal.fromJson(withdrawal);
    }
    throw Optica2ApiException('Could not request withdrawal.');
  }

  Future<List<SellerPayoutMethod>> fetchPayoutMethods({
    required String phoneE164,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{'phone': phoneE164};
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.sellerPayoutMethodsUri(),
      body,
      errorFallback: 'Could not load payout methods.',
    );

    final rawList = decoded['payout_methods'];
    if (rawList is! List) return const [];

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(SellerPayoutMethod.fromJson)
        .toList();
  }

  Future<SellerPayoutMethod> createPayoutMethod({
    required String phoneE164,
    required SellerPayoutMethodType type,
    String? label,
    String? bankName,
    String? bankAccountTitle,
    String? bankAccountNumber,
    String? bankIfsc,
    String? upiId,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{
      'phone': phoneE164,
      'type': type.apiValue,
    };
    if (sellerId != null) body['seller_id'] = sellerId;
    if (label != null && label.trim().isNotEmpty) {
      body['label'] = label.trim();
    }
    if (type == SellerPayoutMethodType.bank) {
      body['bank_name'] = bankName?.trim();
      body['bank_account_title'] = bankAccountTitle?.trim();
      body['bank_account_number'] =
          bankAccountNumber?.replaceAll(RegExp(r'\D'), '');
      body['bank_ifsc'] =
          bankIfsc?.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    } else {
      body['upi_id'] = upiId?.trim().toLowerCase();
    }

    final decoded = await _postJson(
      Optica2Config.sellerPayoutMethodsStoreUri(),
      body,
      errorFallback: 'Could not save payout method.',
    );

    final method = decoded['payout_method'];
    if (method is Map<String, dynamic>) {
      return SellerPayoutMethod.fromJson(method);
    }
    throw Optica2ApiException('Could not save payout method.');
  }

  Future<void> deletePayoutMethod({
    required String phoneE164,
    required int payoutMethodId,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{
      'phone': phoneE164,
      'payout_method_id': payoutMethodId,
    };
    if (sellerId != null) body['seller_id'] = sellerId;

    await _postJson(
      Optica2Config.sellerPayoutMethodsDeleteUri(),
      body,
      errorFallback: 'Could not delete payout method.',
    );
  }

  /// Lists dishes for the vendor's kitchen.
  Future<List<SellerDish>> fetchDishes({
    required String phoneE164,
    int? sellerId,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (Optica2Config.apiKey.isNotEmpty) {
      headers['X-Seller-Api-Key'] = Optica2Config.apiKey;
    }

    final body = <String, dynamic>{'phone': phoneE164};
    if (sellerId != null) body['seller_id'] = sellerId;

    http.Response response;
    try {
      response = await _client
          .post(
            Optica2Config.sellerDishesUri(),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      await _failUnreachable(e);
    }

    Map<String, dynamic>? decoded;
    try {
      final raw = jsonDecode(response.body);
      if (raw is Map<String, dynamic>) decoded = raw;
    } catch (_) {}

    if (response.statusCode == 403) {
      throw Optica2ApiException(
        decoded?['message'] as String? ?? 'Cannot load menu.',
        statusCode: 403,
      );
    }

    if (response.statusCode != 200 || decoded == null) {
      throw Optica2ApiException(
        decoded?['message'] as String? ?? 'Could not load menu.',
        statusCode: response.statusCode,
      );
    }

    final rawList = decoded['dishes'];
    if (rawList is! List) return const [];

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(SellerDish.fromJson)
        .toList();
  }

  /// Creates a dish with photos (multipart).
  Future<SellerDish> createDish({
    required String phoneE164,
    required List<int> superCategoryIds,
    required int dishCategoryId,
    required int dishSubcategoryId,
    required String name,
    required String? description,
    required String? ingredients,
    required String? tags,
    required String? availabilityJson,
    required double price,
    required DishDiscountType discountType,
    double? discountValue,
    required bool isVeg,
    required List<XFile> images,
    List<int> addonIds = const [],
    int? sellerId,
  }) async {
    final request =
        http.MultipartRequest('POST', Optica2Config.sellerDishesStoreUri());
    request.headers['Accept'] = 'application/json';
    if (Optica2Config.apiKey.isNotEmpty) {
      request.headers['X-Seller-Api-Key'] = Optica2Config.apiKey;
    }

    request.fields.addAll({
      'phone': phoneE164,
      'dish_category_id': dishCategoryId.toString(),
      'dish_subcategory_id': dishSubcategoryId.toString(),
      'name': name.trim(),
      'description': (description ?? '').trim(),
      'ingredients': (ingredients ?? '').trim(),
      'tags': (tags ?? '').trim(),
      if (availabilityJson != null && availabilityJson.isNotEmpty)
        'availability_json': availabilityJson,
      'price': price.toStringAsFixed(2),
      'discount_type': discountType.apiValue,
      'is_veg': isVeg ? '1' : '0',
    });
    if (sellerId != null) {
      request.fields['seller_id'] = sellerId.toString();
    }
    if (discountType != DishDiscountType.none && discountValue != null) {
      request.fields['discount_value'] = discountValue.toStringAsFixed(2);
    }
    _attachSuperCategoryIds(request, superCategoryIds);
    _attachAddonIds(request, addonIds);

    for (var i = 0; i < images.length; i++) {
      final file = images[i];
      final bytes = await file.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'images[$i]',
          bytes,
          filename: _imageUploadName(file, 'dish_$i'),
        ),
      );
    }

    final response = await _sendMultipart(request, 'Could not save dish.');
    final dishJson = response['dish'];
    if (dishJson is Map<String, dynamic>) {
      return SellerDish.fromJson(dishJson);
    }

    throw Optica2ApiException('Could not save dish.');
  }

  /// Updates a dish. New [images] replace existing photos when non-empty.
  Future<SellerDish> updateDish({
    required String phoneE164,
    required int dishId,
    required List<int> superCategoryIds,
    required int dishCategoryId,
    required int dishSubcategoryId,
    required String name,
    required String? description,
    required String? ingredients,
    required String? tags,
    required String? availabilityJson,
    required double price,
    required DishDiscountType discountType,
    double? discountValue,
    required bool isVeg,
    List<XFile> images = const [],
    List<int> addonIds = const [],
    int? sellerId,
  }) async {
    final request =
        http.MultipartRequest('POST', Optica2Config.sellerDishesUpdateUri());
    request.headers['Accept'] = 'application/json';
    if (Optica2Config.apiKey.isNotEmpty) {
      request.headers['X-Seller-Api-Key'] = Optica2Config.apiKey;
    }

    request.fields.addAll({
      'phone': phoneE164,
      'dish_id': dishId.toString(),
      'dish_category_id': dishCategoryId.toString(),
      'dish_subcategory_id': dishSubcategoryId.toString(),
      'name': name.trim(),
      'description': (description ?? '').trim(),
      'ingredients': (ingredients ?? '').trim(),
      'tags': (tags ?? '').trim(),
      if (availabilityJson != null && availabilityJson.isNotEmpty)
        'availability_json': availabilityJson,
      'price': price.toStringAsFixed(2),
      'discount_type': discountType.apiValue,
      'is_veg': isVeg ? '1' : '0',
    });
    if (sellerId != null) {
      request.fields['seller_id'] = sellerId.toString();
    }
    if (discountType != DishDiscountType.none && discountValue != null) {
      request.fields['discount_value'] = discountValue.toStringAsFixed(2);
    }
    _attachSuperCategoryIds(request, superCategoryIds);
    _attachAddonIds(request, addonIds);

    for (var i = 0; i < images.length; i++) {
      final file = images[i];
      final bytes = await file.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'images[$i]',
          bytes,
          filename: _imageUploadName(file, 'dish_$i'),
        ),
      );
    }

    final response = await _sendMultipart(request, 'Could not update dish.');
    final dishJson = response['dish'];
    if (dishJson is Map<String, dynamic>) {
      return SellerDish.fromJson(dishJson);
    }
    throw Optica2ApiException('Could not update dish.');
  }

  Future<SellerDish> setDishAvailability({
    required String phoneE164,
    required int dishId,
    required bool isAvailable,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{
      'phone': phoneE164,
      'dish_id': dishId,
      'is_available': isAvailable,
    };
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.sellerDishesAvailabilityUri(),
      body,
      errorFallback: 'Could not update availability.',
    );

    final dishJson = decoded['dish'];
    if (dishJson is Map<String, dynamic>) {
      return SellerDish.fromJson(dishJson);
    }
    throw Optica2ApiException('Could not update availability.');
  }

  Future<void> deleteDish({
    required String phoneE164,
    required int dishId,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{
      'phone': phoneE164,
      'dish_id': dishId,
    };
    if (sellerId != null) body['seller_id'] = sellerId;

    await _postJson(
      Optica2Config.sellerDishesDeleteUri(),
      body,
      errorFallback: 'Could not delete dish.',
    );
  }

  /// Lists add-ons for the vendor's kitchen.
  Future<List<SellerAddon>> fetchAddons({
    required String phoneE164,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{'phone': phoneE164};
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.sellerAddonsUri(),
      body,
      errorFallback: 'Could not load add-ons.',
    );

    final rawList = decoded['addons'];
    if (rawList is! List) return const [];

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(SellerAddon.fromJson)
        .toList();
  }

  Future<SellerAddon> createAddon({
    required String phoneE164,
    required String name,
    required double price,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{
      'phone': phoneE164,
      'name': name.trim(),
      'price': price.toStringAsFixed(2),
    };
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.sellerAddonsStoreUri(),
      body,
      errorFallback: 'Could not save add-on.',
    );

    final addonJson = decoded['addon'];
    if (addonJson is Map<String, dynamic>) {
      return SellerAddon.fromJson(addonJson);
    }
    throw Optica2ApiException('Could not save add-on.');
  }

  Future<SellerAddon> updateAddon({
    required String phoneE164,
    required int addonId,
    required String name,
    required double price,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{
      'phone': phoneE164,
      'addon_id': addonId,
      'name': name.trim(),
      'price': price.toStringAsFixed(2),
    };
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.sellerAddonsUpdateUri(),
      body,
      errorFallback: 'Could not update add-on.',
    );

    final addonJson = decoded['addon'];
    if (addonJson is Map<String, dynamic>) {
      return SellerAddon.fromJson(addonJson);
    }
    throw Optica2ApiException('Could not update add-on.');
  }

  Future<void> deleteAddon({
    required String phoneE164,
    required int addonId,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{
      'phone': phoneE164,
      'addon_id': addonId,
    };
    if (sellerId != null) body['seller_id'] = sellerId;

    await _postJson(
      Optica2Config.sellerAddonsDeleteUri(),
      body,
      errorFallback: 'Could not delete add-on.',
    );
  }

  Future<List<SellerCoupon>> fetchCoupons({
    required String phoneE164,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{'phone': phoneE164};
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.sellerCouponsUri(),
      body,
      errorFallback: 'Could not load coupons.',
    );

    final rawList = decoded['coupons'];
    if (rawList is! List) return const [];

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(SellerCoupon.fromJson)
        .toList();
  }

  Future<SellerCoupon> createCoupon({
    required String phoneE164,
    required String code,
    required String title,
    String? description,
    required DishDiscountType discountType,
    required double discountValue,
    double? minPurchaseAmount,
    double? maxDiscountableAmount,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{
      'phone': phoneE164,
      'code': code.trim(),
      'title': title.trim(),
      'discount_type': discountType.apiValue,
      'discount_value': discountValue.toStringAsFixed(2),
    };
    final trimmedDescription = description?.trim();
    if (trimmedDescription != null && trimmedDescription.isNotEmpty) {
      body['description'] = trimmedDescription;
    }
    if (minPurchaseAmount != null && minPurchaseAmount > 0) {
      body['min_purchase_amount'] = minPurchaseAmount.toStringAsFixed(2);
    }
    if (maxDiscountableAmount != null && maxDiscountableAmount > 0) {
      body['max_discountable_amount'] = maxDiscountableAmount.toStringAsFixed(2);
    }
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.sellerCouponsStoreUri(),
      body,
      errorFallback: 'Could not save coupon.',
    );

    final couponJson = decoded['coupon'];
    if (couponJson is Map<String, dynamic>) {
      return SellerCoupon.fromJson(couponJson);
    }
    throw Optica2ApiException('Could not save coupon.');
  }

  Future<SellerCoupon> updateCoupon({
    required String phoneE164,
    required int couponId,
    required String code,
    required String title,
    String? description,
    required DishDiscountType discountType,
    required double discountValue,
    double? minPurchaseAmount,
    double? maxDiscountableAmount,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{
      'phone': phoneE164,
      'coupon_id': couponId,
      'code': code.trim(),
      'title': title.trim(),
      'discount_type': discountType.apiValue,
      'discount_value': discountValue.toStringAsFixed(2),
    };
    final trimmedDescription = description?.trim();
    if (trimmedDescription != null && trimmedDescription.isNotEmpty) {
      body['description'] = trimmedDescription;
    }
    if (minPurchaseAmount != null && minPurchaseAmount > 0) {
      body['min_purchase_amount'] = minPurchaseAmount.toStringAsFixed(2);
    } else {
      body['min_purchase_amount'] = '';
    }
    if (maxDiscountableAmount != null && maxDiscountableAmount > 0) {
      body['max_discountable_amount'] = maxDiscountableAmount.toStringAsFixed(2);
    } else {
      body['max_discountable_amount'] = '';
    }
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.sellerCouponsUpdateUri(),
      body,
      errorFallback: 'Could not update coupon.',
    );

    final couponJson = decoded['coupon'];
    if (couponJson is Map<String, dynamic>) {
      return SellerCoupon.fromJson(couponJson);
    }
    throw Optica2ApiException('Could not update coupon.');
  }

  Future<SellerCoupon> setCouponActive({
    required String phoneE164,
    required int couponId,
    required bool isActive,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{
      'phone': phoneE164,
      'coupon_id': couponId,
      'is_active': isActive,
    };
    if (sellerId != null) body['seller_id'] = sellerId;

    final decoded = await _postJson(
      Optica2Config.sellerCouponsActiveUri(),
      body,
      errorFallback: 'Could not update coupon status.',
    );

    final couponJson = decoded['coupon'];
    if (couponJson is Map<String, dynamic>) {
      return SellerCoupon.fromJson(couponJson);
    }
    throw Optica2ApiException('Could not update coupon status.');
  }

  Future<void> deleteCoupon({
    required String phoneE164,
    required int couponId,
    int? sellerId,
  }) async {
    final body = <String, dynamic>{
      'phone': phoneE164,
      'coupon_id': couponId,
    };
    if (sellerId != null) body['seller_id'] = sellerId;

    await _postJson(
      Optica2Config.sellerCouponsDeleteUri(),
      body,
      errorFallback: 'Could not delete coupon.',
    );
  }

  static void _attachSuperCategoryIds(
    http.MultipartRequest request,
    List<int> superCategoryIds,
  ) {
    for (var i = 0; i < superCategoryIds.length; i++) {
      request.fields['super_category_ids[$i]'] = superCategoryIds[i].toString();
    }
  }

  static void _attachAddonIds(http.MultipartRequest request, List<int> addonIds) {
    for (var i = 0; i < addonIds.length; i++) {
      request.fields['addon_ids[$i]'] = addonIds[i].toString();
    }
  }

  Future<Map<String, dynamic>> _sendMultipart(
    http.MultipartRequest request,
    String errorFallback,
  ) async {
    http.Response response;
    try {
      final streamed =
          await _client.send(request).timeout(const Duration(seconds: 90));
      response = await http.Response.fromStream(streamed);
    } catch (e) {
      await _failUnreachable(e);
    }

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Optica2ApiException(
        body?['message'] as String? ??
            (body?['errors'] is Map
                ? _firstValidationError(body!['errors'] as Map)
                : null) ??
            errorFallback,
        statusCode: response.statusCode,
      );
    }

    return body ?? {};
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri,
    Map<String, dynamic> body, {
    required String errorFallback,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (Optica2Config.apiKey.isNotEmpty) {
      headers['X-Seller-Api-Key'] = Optica2Config.apiKey;
    }

    http.Response response;
    try {
      response = await _client
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      await _failUnreachable(e);
    }

    Map<String, dynamic>? decoded;
    try {
      final raw = jsonDecode(response.body);
      if (raw is Map<String, dynamic>) decoded = raw;
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Optica2ApiException(
        decoded?['message'] as String? ??
            (decoded?['errors'] is Map
                ? _firstValidationError(decoded!['errors'] as Map)
                : null) ??
            errorFallback,
        statusCode: response.statusCode,
      );
    }

    return decoded ?? {};
  }

  Future<Never> _failUnreachable([Object? _]) async {
    if (!_recoverHostOnFailure) {
      throw Optica2ApiException(Optica2Config.unreachableMessage());
    }
    await Optica2Config.tryRecoverHost();
    throw Optica2ApiException(Optica2Config.unreachableMessage());
  }

  /// Active OTP provider (Firebase vs MSG91) from admin SMS Gateway.
  Future<OtpConfig> fetchOtpConfig() async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Cache-Control': 'no-cache',
    };
    http.Response response;
    try {
      response = await _client
          .get(Optica2Config.otpConfigUri(), headers: headers)
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      await _failUnreachable();
    }

    Map<String, dynamic>? decoded;
    try {
      final raw = jsonDecode(response.body);
      if (raw is Map<String, dynamic>) decoded = raw;
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Optica2ApiException(
        userFacingApiMessage(
          decoded,
          fallback: 'Could not load OTP settings.',
          statusCode: response.statusCode,
        ),
        statusCode: response.statusCode,
      );
    }

    return OtpConfig.fromJson(decoded ?? {});
  }

  /// Sends OTP via MSG91 when that provider is selected in admin.
  Future<OtpSendResult> sendOtp(
    String phoneE164, {
    bool resend = false,
  }) async {
    final decoded = await _postOtp(
      Optica2Config.otpSendUri(),
      {
        'phone': toMsg91Mobile(phoneE164),
        if (resend) 'resend': 'true',
      },
      errorFallback: 'Could not send OTP.',
    );
    return OtpSendResult.fromJson(decoded);
  }

  /// Verifies OTP via MSG91 backend.
  Future<void> verifyOtp(
    String phoneE164,
    String otp, {
    String? requestId,
  }) async {
    final payload = <String, String>{
      'phone': toMsg91Mobile(phoneE164),
      'otp': otp.replaceAll(RegExp(r'\D'), ''),
    };
    final rid = requestId?.trim();
    if (rid != null && rid.isNotEmpty) {
      payload['request_id'] = rid;
    }

    await _postOtp(
      Optica2Config.otpVerifyUri(),
      payload,
      errorFallback: 'Invalid or expired code.',
    );
  }

  Future<Map<String, dynamic>> _postOtp(
    Uri uri,
    Map<String, String> body, {
    required String errorFallback,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    http.Response response;
    try {
      response = await _client
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      await _failUnreachable();
    }

    Map<String, dynamic>? decoded;
    try {
      final raw = jsonDecode(response.body);
      if (raw is Map<String, dynamic>) decoded = raw;
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Optica2ApiException(
        userFacingApiMessage(
          decoded,
          fallback: errorFallback,
          statusCode: response.statusCode,
        ),
        statusCode: response.statusCode,
      );
    }

    return decoded ?? {};
  }

  void close() => _client.close();
}
