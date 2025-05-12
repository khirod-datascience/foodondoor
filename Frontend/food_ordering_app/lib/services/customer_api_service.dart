import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/auth_storage.dart';
import '../config.dart';

class CustomerApiService {
  // Reverse geocode: POST /reverse-geocode/ with lat/lng
  static Future<http.Response> reverseGeocode({required double latitude, required double longitude}) async {
    final url = AppConfig.baseUrl + '/reverse-geocode/';
    final headers = await _headers();
    final body = jsonEncode({
      'latitude': latitude,
      'longitude': longitude,
    });
    return await http.post(Uri.parse(url), headers: headers, body: body);
  }

  // Helper to get headers with JWT
  static Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await AuthStorage.getToken();
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Profile
  static Future<http.Response> getProfile(String customerId) async {
    return await http.get(Uri.parse(AppConfig.baseUrl + '/$customerId/'), headers: await _headers());
  }
  static Future<http.Response> updateProfile(String customerId, Map<String, dynamic> data) async {
    return await http.put(Uri.parse(AppConfig.baseUrl + '/$customerId/'), headers: await _headers(), body: jsonEncode(data));
  }
  static Future<http.Response> deleteProfile(String customerId) async {
    return await http.delete(Uri.parse(AppConfig.baseUrl + '/$customerId/'), headers: await _headers());
  }
  // FCM Token
  static Future<http.Response> registerFcmToken(String customerId, String fcmToken) async {
    return await http.post(Uri.parse(AppConfig.baseUrl + '/fcm-token/'),
      headers: await _headers(),
      body: jsonEncode({'customer_id': customerId, 'fcm_token': fcmToken}),
    );
  }
  // Orders List (all orders for logged-in customer)
  static Future<http.Response> getOrders({String? customerId}) async {
    final token = await AuthStorage.getToken();
    return await http.post(
      Uri.parse(AppConfig.baseUrl + '/my-orders/'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: customerId != null ? jsonEncode({'customer_id': customerId}) : null,
    );
  }

  // Token Refresh
  static Future<http.Response> refreshToken(String refreshToken) async {
    return await http.post(
      Uri.parse(AppConfig.baseUrl + '/token/refresh/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refreshToken}),
    );
  }

  // Order Tracking
  static Future<http.Response> getOrderTracking(String orderNumber) async {
    return await http.get(Uri.parse(AppConfig.baseUrl + '/orders/$orderNumber/track/'), headers: await _headers());
  }
  static Future<http.Response> getOrderStatus(String orderNumber) async {
    return await http.get(Uri.parse(AppConfig.baseUrl + '/orders/$orderNumber/status/'), headers: await _headers());
  }
  // Payment
  static Future<http.Response> createPayment(double amount) async {
    return await http.post(Uri.parse(AppConfig.baseUrl + '/payment/create/'),
      headers: await _headers(),
      body: jsonEncode({'amount': amount}),
    );
  }
  static Future<http.Response> verifyPayment(Map<String, dynamic> data) async {
    return await http.post(Uri.parse(AppConfig.baseUrl + '/payment/verify/'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
  }
  // Wallet
  static Future<http.Response> getWallet() async {
    return await http.get(Uri.parse(AppConfig.baseUrl + '/wallet/'), headers: await _headers());
  }
  // Transactions
  static Future<http.Response> getTransactions() async {
    return await http.get(Uri.parse(AppConfig.baseUrl + '/transactions/'), headers: await _headers());
  }
  // Promotions
  static Future<http.Response> getPromotions() async {
    return await http.get(Uri.parse(AppConfig.baseUrl + '/promotions/'), headers: await _headers());
  }
  // Ratings
  static Future<http.Response> submitRating(Map<String, dynamic> data) async {
    return await http.post(Uri.parse(AppConfig.baseUrl + '/ratings/'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
  }
  // Notifications
  static Future<http.Response> getNotifications() async {
    return await http.get(Uri.parse(AppConfig.baseUrl + '/notifications/'), headers: await _headers());
  }
  // Support Chat
  static Future<http.Response> getSupportMessages() async {
    return await http.get(Uri.parse(AppConfig.baseUrl + '/support/'), headers: await _headers());
  }
  static Future<http.Response> sendSupportMessage(String message) async {
    return await http.post(Uri.parse(AppConfig.baseUrl + '/support/'),
      headers: await _headers(),
      body: jsonEncode({'message': message}),
    );
  }
}
