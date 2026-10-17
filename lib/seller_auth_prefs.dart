import 'package:shared_preferences/shared_preferences.dart';

/// Persists seller OTP completion so login is required only once per device.
abstract final class SellerAuthPrefs {
  static const otpVerifiedKey = 'seller_otp_verified';
  static const phoneE164Key = 'seller_phone_e164';

  static Future<bool> isOtpVerified() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(otpVerifiedKey) ?? false;
  }

  static Future<String?> phoneE164() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(phoneE164Key);
  }

  /// Call after Firebase OTP succeeds.
  static Future<void> markOtpVerified({required String phoneE164}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(otpVerifiedKey, true);
    await prefs.setString(phoneE164Key, phoneE164);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(otpVerifiedKey);
    await prefs.remove(phoneE164Key);
  }
}
