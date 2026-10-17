import 'package:shared_preferences/shared_preferences.dart';

/// Tracks last Optica2 base URL so devs can see when en0 IP sync changed it.
abstract final class Optica2ApiPrefs {
  static const baseUrlKey = 'optica2_api_base_url';

  static Future<String?> lastBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(baseUrlKey);
  }

  /// Returns true if the URL changed from the previous launch.
  static Future<bool> saveBaseUrlIfChanged(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(baseUrlKey);
    await prefs.setString(baseUrlKey, baseUrl);
    return previous != null && previous != baseUrl;
  }

  static Future<void> clearSavedBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(baseUrlKey);
  }
}
