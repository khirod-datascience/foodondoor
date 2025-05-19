import 'dart:async';
import 'package:flutter/foundation.dart';

/// SimpleNotificationService: Singleton for notification handling (stub for FCM/local notifications)
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:foodondoor_restaurant/utils/globals.dart' as globals;
import '../config.dart';

class SimpleNotificationService {
  SimpleNotificationService._internal();
  static final SimpleNotificationService instance = SimpleNotificationService._internal();

  // Notification stream
  final StreamController<Map<String, dynamic>> _notificationController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get notifications => _notificationController.stream;

  // Initialize notification service (FCM setup etc.)
  Future<void> initialize({String? vendorId}) async {
    try {
      // Prefer passed vendorId, else use Globals.vendorId
      String? id = vendorId ?? globals.Globals.vendorId;
      debugPrint('[SimpleNotificationService] Initializing with vendorId: '
        '\u001b[1m$id\u001b[0m (passed: $vendorId, Globals.vendorId: \u001b[1m${globals.Globals.vendorId}\u001b[0m)');
      String? token = await FirebaseMessaging.instance.getToken();
      debugPrint('[SimpleNotificationService] FCM token: $token');
      if (token != null && id != null) {
        await sendFcmTokenToBackend(token, id);
      } else {
        debugPrint('[SimpleNotificationService] Vendor ID or FCM token is null!');
      }
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        if (id != null) {
          sendFcmTokenToBackend(newToken, id);
        }
      });
    } catch (e) {
      debugPrint('[SimpleNotificationService] Error initializing FCM: $e');
    }
  }

  Future<void> sendFcmTokenToBackend(String token, String vendorId) async {
    final url = Uri.parse('${Config.baseUrl}/auth/vendors/$vendorId/fcm-token/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fcm_token': token}),
      );
      debugPrint('[SimpleNotificationService] Sent FCM token to backend. Status: \\${response.statusCode}');
    } catch (e) {
      debugPrint('[SimpleNotificationService] Failed to send FCM token: $e');
    }
  }

  // Clear device token (logout etc.)
  Future<void> clearDeviceToken() async {
    // TODO: Implement token clearing logic
    debugPrint('[SimpleNotificationService] Device token cleared (stub).');
  }

  // Refresh notifications (fetch from backend)
  Future<void> refreshNotifications() async {
    final vendorId = globals.Globals.vendorId;
    if (vendorId == null) {
      debugPrint('[SimpleNotificationService] Cannot fetch notifications: vendorId is null');
      return;
    }
    final url = Uri.parse('${Config.baseUrl}/auth/vendors/$vendorId/notifications/');
    try {
      final response = await http.get(url, headers: {'Content-Type': 'application/json'});
      debugPrint('[SimpleNotificationService] Fetch notifications status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final List<dynamic> notifications = jsonDecode(response.body);
        for (final notif in notifications) {
          _notificationController.add({
            'title': notif['title'] ?? '',
            'body': notif['body'] ?? '',
            'timestamp': notif['created_at'] ?? DateTime.now().toIso8601String(),
            'id': notif['id'] ?? '',
            'is_read': notif['is_read'] ?? false,
          });
        }
      } else {
        debugPrint('[SimpleNotificationService] Failed to fetch notifications: ${response.body}');
      }
    } catch (e) {
      debugPrint('[SimpleNotificationService] Error fetching notifications: $e');
    }
  }

  // Dispose the stream controller
  void dispose() {
    _notificationController.close();
  }
}
