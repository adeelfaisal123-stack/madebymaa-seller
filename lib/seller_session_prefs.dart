import 'package:shared_preferences/shared_preferences.dart';

/// Cached seller id after Optica2 phone check (for kitchen status API).
abstract final class SellerSessionPrefs {
  static const sellerIdKey = 'seller_id';

  static Future<int?> sellerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(sellerIdKey);
  }

  static Future<void> saveSellerId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(sellerIdKey, id);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(sellerIdKey);
  }
}
