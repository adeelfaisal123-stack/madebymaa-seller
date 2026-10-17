import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../seller_auth_prefs.dart';
import '../seller_session_prefs.dart';
import '../widgets/app_toast.dart';
import '../screens/register_seller_screen.dart';
import '../screens/seller_home_screen.dart';
import '../screens/seller_kyc_pending_screen.dart';
import '../models/seller_bank_details.dart';
import '../models/seller_document_kyc_info.dart';
import '../screens/seller_document_kyc_screen.dart';
import '../screens/seller_document_kyc_view_screen.dart';
import '../screens/seller_kyc_screen.dart';
import 'optica2_api.dart';

/// Routes sellers to home, KYC form, or KYC pending wait based on Optica2 DB status.
abstract final class SellerAuthNavigation {
  static Future<SellerPhoneCheckResult> checkPhone(
    Optica2Api api,
    String phoneE164,
  ) {
    return api.checkSellerPhone(phoneE164);
  }

  static Future<SellerPhoneCheckResult> probePhone(
    Optica2Api api,
    String phoneE164,
  ) {
    return api.probeSellerPhone(phoneE164);
  }

  static bool needsKycForm(SellerPhoneCheckResult result) => result.needsKycForm;

  static bool needsKitchenSetup(SellerPhoneCheckResult result) =>
      result.needsKitchenSetup;

  static bool isAwaitingKycApproval(SellerPhoneCheckResult result) =>
      result.isAwaitingAdminApproval && result.sellerId != null;

  static void openKyc(
    BuildContext context, {
    required int sellerId,
    required String phoneE164,
    bool resumeToHomeOnComplete = false,
  }) {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => SellerKycScreen(
          sellerId: sellerId,
          phoneE164: phoneE164,
          resumeToHomeOnComplete: resumeToHomeOnComplete,
        ),
      ),
      (route) => false,
    );
  }

  static void openKycPending(
    BuildContext context, {
    required int sellerId,
    required String phoneE164,
    String? message,
  }) {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => SellerKycPendingScreen(
          sellerId: sellerId,
          phoneE164: phoneE164,
          message: message,
        ),
      ),
      (route) => false,
    );
  }

  static void openRegister(
    BuildContext context, {
    required String phoneE164,
  }) {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => RegisterSellerScreen(
          phoneE164: phoneE164,
          phoneVerified: true,
        ),
      ),
      (route) => false,
    );
  }

  static void openKitchenSetup(
    BuildContext context, {
    required String phoneE164,
    required int sellerId,
  }) {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => RegisterSellerScreen(
          phoneE164: phoneE164,
          phoneVerified: true,
          kitchenSetupOnly: true,
          sellerId: sellerId,
        ),
      ),
      (route) => false,
    );
  }

  static Future<void> openDocumentKyc(
    BuildContext context, {
    required String phoneE164,
    SellerDocumentKycStatusKind initialStatus =
        SellerDocumentKycStatusKind.notSubmitted,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SellerDocumentKycScreen(
          phoneE164: phoneE164,
          initialStatus: initialStatus,
        ),
      ),
    );
  }

  /// Upload flow or read-only view — same routing as Profile → KYC status.
  static Future<void> openDocumentKycFlow(
    BuildContext context, {
    required String phoneE164,
    required SellerDocumentKycStatusKind status,
    SellerDocumentKycInfo? documentKyc,
  }) async {
    final info = documentKyc ??
        SellerDocumentKycInfo(status: status, hasUploads: false);
    final shouldUpload = !info.canViewDocuments ||
        info.status == SellerDocumentKycStatusKind.notSubmitted;

    if (shouldUpload) {
      await openDocumentKyc(
        context,
        phoneE164: phoneE164,
        initialStatus: status,
      );
    } else {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SellerDocumentKycViewScreen(documentKyc: info),
        ),
      );
    }
  }

  static void openHome(
    BuildContext context, {
    bool skipKycGuard = false,
  }) {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => SellerHomeScreen(skipKycGuard: skipKycGuard),
      ),
      (route) => false,
    );
  }

  static void routeFromCheck(
    BuildContext context,
    SellerPhoneCheckResult result,
    String phoneE164, {
    bool resumeKycToHome = false,
  }) {
    if (needsKycForm(result)) {
      openKyc(
        context,
        sellerId: result.sellerId!,
        phoneE164: phoneE164,
        resumeToHomeOnComplete: resumeKycToHome,
      );
      return;
    }

    if (isAwaitingKycApproval(result)) {
      openKycPending(
        context,
        sellerId: result.sellerId!,
        phoneE164: phoneE164,
        message: result.message,
      );
      return;
    }

    if (result.canLogin) {
      openHome(context);
    }
  }

  static Future<void> _persistSession(
    String phoneE164,
    SellerPhoneCheckResult result,
  ) async {
    await SellerAuthPrefs.markOtpVerified(phoneE164: phoneE164);
    if (result.sellerId != null) {
      await SellerSessionPrefs.saveSellerId(result.sellerId!);
    }
  }

  /// After Firebase OTP for a new (unregistered) number → register, then pending.
  static Future<void> routeToRegisterAfterOtp(
    BuildContext context,
    String phoneE164,
  ) async {
    await SellerAuthPrefs.markOtpVerified(phoneE164: phoneE164);
    if (!context.mounted) return;
    openRegister(context, phoneE164: phoneE164);
  }

  /// After Firebase sign-in, sends user to register, KYC, pending wait, or home.
  static Future<void> routeAfterFirebaseAuth(
    BuildContext context,
    Optica2Api api,
    String phoneE164, {
    bool forceRegistration = false,
  }) async {
    final result = forceRegistration
        ? SellerPhoneCheckResult(
            exists: false,
            canLogin: false,
            kycPending: false,
            kycAwaitingApproval: false,
            kitchenSetupPending: false,
            kycStatus: SellerKycStatusKind.notRegistered,
            documentKycStatus: SellerDocumentKycStatusKind.notSubmitted,
            documentKyc: null,
            bankDetails: const SellerBankDetails(),
            message: 'Not registered',
            phoneE164: phoneE164,
          )
        : await probePhone(api, phoneE164);
    if (!context.mounted) return;

    if (result.isNotRegistered) {
      await routeToRegisterAfterOtp(context, phoneE164);
      return;
    }

    await _persistSession(phoneE164, result);

    if (needsKycForm(result) ||
        isAwaitingKycApproval(result)) {
      routeFromCheck(context, result, phoneE164, resumeKycToHome: true);
      return;
    }

    if (result.canLogin) {
      openHome(context);
      return;
    }

    await _signOutFully();
    if (!context.mounted) return;
    AppToast.danger(context, result.message);
  }

  /// Cold start / return visit when OTP was already completed (SharedPreferences).
  static Future<void> routeFromSavedSession(
    BuildContext context,
    Optica2Api api,
    String phoneE164,
  ) async {
    final result = await probePhone(api, phoneE164);
    if (!context.mounted) return;

    if (result.isNotRegistered) {
      openRegister(context, phoneE164: phoneE164);
      return;
    }

    if (result.sellerId != null) {
      await SellerSessionPrefs.saveSellerId(result.sellerId!);
    }

    if (needsKycForm(result) ||
        isAwaitingKycApproval(result)) {
      routeFromCheck(context, result, phoneE164, resumeKycToHome: true);
      return;
    }

    if (result.canLogin) {
      openHome(context);
      return;
    }

    await _signOutFully();
    if (!context.mounted) return;
    AppToast.danger(context, result.message);
  }

  /// Splash: build next screen from saved phone (Firebase optional).
  static Future<Widget?> destinationForSavedPhone(
    Optica2Api api,
    String phoneE164,
  ) async {
    try {
      final result = await probePhone(api, phoneE164);
      if (result.isNotRegistered) {
        return RegisterSellerScreen(
          phoneE164: phoneE164,
          phoneVerified: true,
        );
      }
      if (result.sellerId != null) {
        await SellerSessionPrefs.saveSellerId(result.sellerId!);
      }
      if (needsKycForm(result)) {
        return SellerKycScreen(
          sellerId: result.sellerId!,
          phoneE164: phoneE164,
          resumeToHomeOnComplete: true,
        );
      }
      if (isAwaitingKycApproval(result)) {
        return SellerKycPendingScreen(
          sellerId: result.sellerId!,
          phoneE164: phoneE164,
          message: result.message,
        );
      }
      if (result.canLogin) {
        return const SellerHomeScreen();
      }
      await _signOutFully();
    } catch (_) {
      // Keep prefs; user can retry from login if API is down.
    }
    return null;
  }

  /// Splash when Firebase session still exists.
  static Future<Widget?> destinationForSignedInUser(Optica2Api api) async {
    final user = FirebaseAuth.instance.currentUser;
    final phone = user?.phoneNumber;
    if (phone == null || phone.isEmpty) {
      return null;
    }

    return destinationForSavedPhone(api, phone);
  }

  static Future<void> _signOutFully() async {
    await SellerAuthPrefs.clear();
    await SellerSessionPrefs.clear();
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Firebase may not be initialized (e.g. setup screen).
    }
  }

  /// Sign out from profile / settings.
  static Future<void> signOut() => _signOutFully();
}
