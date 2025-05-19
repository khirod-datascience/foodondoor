import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';
import '../providers/auth_provider.dart'; // For delivery user ID

class SimpleNotificationService {
  SimpleNotificationService._internal();
  static final SimpleNotificationService instance = SimpleNotificationService._internal();

  // Notification stream
  final StreamController<Map<String, dynamic>> _notificationController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get notifications => _notificationController.stream;

  // Initialize notification service (FCM setup etc.)
  Future<void> initialize({String? deliveryUserId}) async {
    try {
      // Get FCM token
      String? token = await FirebaseMessaging.instance.getToken();
      debugPrint('[SimpleNotificationService] FCM token: $token');
      // Send to backend if deliveryUserId exists
      if (token != null && deliveryUserId != null) {
        await sendFcmTokenToBackend(token, deliveryUserId);
      }
      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        if (deliveryUserId != null) {
          sendFcmTokenToBackend(newToken, deliveryUserId);
        }
      });
    } catch (e) {
      debugPrint('[SimpleNotificationService] Error initializing FCM: $e');
    }
  }

  Future<void> sendFcmTokenToBackend(String token, String deliveryUserId) async {
    final url = Uri.parse('${AppConfig.deliveryApiBaseUrl}/fcm-token/update/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fcm_token': token, 'delivery_user_id': deliveryUserId}),
      );
      debugPrint('[SimpleNotificationService] Sent FCM token to backend. Status: \\${response.statusCode}');
    } catch (e) {
      debugPrint('[SimpleNotificationService] Failed to send FCM token: $e');
    }
  }

  // Dispose the stream controller
  void dispose() {
    _notificationController.close();
  }
}
