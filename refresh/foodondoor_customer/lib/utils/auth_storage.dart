// Helper for storing/retrieving auth token and customer id
import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const String _tokenKey = 'auth_token';
  static const String _customerIdKey = 'customer_id';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<void> saveCustomerId(String customerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customerIdKey, customerId);
  }

  static Future<String?> getCustomerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customerIdKey);
  }

  static Future<void> deleteCustomerId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_customerIdKey);
  }
}
