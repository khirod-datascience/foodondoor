import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../utils/auth_storage.dart';

// Handle background messages when the app is in the background
// This must be a top-level function (not a class method)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized
  await Firebase.initializeApp();
  
  // Don't show UI here, just process the message
  print("Handling background message: ${message.messageId}");
  print("Background notification data: ${message.data}");
}

class SimpleNotificationService {
  static final SimpleNotificationService _instance = SimpleNotificationService._internal();
  static SimpleNotificationService get instance => _instance;
  
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final StreamController<RemoteMessage> _messageStreamController = StreamController.broadcast();
  
  Stream<RemoteMessage> get messageStream => _messageStreamController.stream;
  
  // Store for navigation when notification is tapped
  RemoteMessage? _initialMessage;
  RemoteMessage? _messageOpenedApp;
  
  // Private constructor
  SimpleNotificationService._internal();
  
  // Initialize Firebase and notification permissions
  Future<void> initialize() async {
    try {
      // Initialize Firebase
      await Firebase.initializeApp();
      
      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Request permission on iOS
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      print('User granted permission: ${settings.authorizationStatus}');
      
      // Get initial message (app opened from terminated state)
      _initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (_initialMessage != null) {
        print('App opened from terminated state with message: ${_initialMessage!.messageId}');
        _messageStreamController.add(_initialMessage!);
      }
      
      // Handle messages when app is in foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Foreground message received: ${message.notification?.title}');
        _messageStreamController.add(message);
      });
      
      // Handle when app is opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('App opened from background state with message: ${message.messageId}');
        _messageOpenedApp = message;
        _messageStreamController.add(message);
      });
      
      // Get the token
      String? token = await _messaging.getToken();
      if (token != null) {
        print('FCM Token: $token');
        // Send token to server
        await _sendTokenToServer(token);
      }
      
      // Listen for token refreshes
      _messaging.onTokenRefresh.listen((String token) {
        print('FCM Token refreshed: $token');
        _sendTokenToServer(token);
      });
      
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }
  
  // Send token to your backend server
  Future<void> _sendTokenToServer(String token) async {
    try {
      // Get customer ID
      final customerId = await AuthStorage.getCustomerId();
      if (customerId == null) {
        print('Cannot send FCM token: Customer ID not found');
        return;
      }
      
      // Get auth token
      final authToken = await AuthStorage.getToken();
      
      // Send the token to your backend
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/update-fcm-token/'),
        headers: {
          'Content-Type': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'customer_id': customerId,
          'fcm_token': token,
          'device_type': 'customer_app'
        }),
      );
      
      if (response.statusCode == 200) {
        print('FCM token sent to server successfully');
      } else {
        print('Failed to send FCM token to server: ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('Error sending FCM token to server: $e');
    }
  }
  
  // Delete FCM token on logout
  Future<void> deleteToken() async {
    try {
      await _sendTokenDeleteRequest();
      await _messaging.deleteToken();
      print('FCM token deleted successfully');
    } catch (e) {
      print('Error deleting FCM token: $e');
    }
  }
  
  // Send token delete request to server
  Future<void> _sendTokenDeleteRequest() async {
    try {
      final customerId = await AuthStorage.getCustomerId();
      final authToken = await AuthStorage.getToken();
      final fcmToken = await _messaging.getToken();
      
      if (customerId == null || fcmToken == null) {
        print('Cannot delete FCM token: Missing customer ID or FCM token');
        return;
      }
      
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/delete-fcm-token/'),
        headers: {
          'Content-Type': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'customer_id': customerId,
          'fcm_token': fcmToken,
        }),
      );
      
      if (response.statusCode == 200) {
        print('FCM token deletion notified to server');
      } else {
        print('Failed to notify server about FCM token deletion: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending FCM token deletion to server: $e');
    }
  }
  
  // Show in-app notification for foreground messages
  void showInAppNotification(BuildContext context, RemoteMessage message) {
    if (message.notification != null) {
      final notification = message.notification!;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.title ?? 'New Notification',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (notification.body != null)
                Text(notification.body!),
            ],
          ),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'VIEW',
            onPressed: () {
              // Handle notification tap
              _handleNotificationTap(context, message);
            },
          ),
        ),
      );
    }
  }
  
  // Handle notification tap based on the data
  void _handleNotificationTap(BuildContext context, RemoteMessage message) {
    // Extract data from the message
    final data = message.data;
    
    // Example: Navigate based on notification type
    if (data.containsKey('type')) {
      final type = data['type'];
      
      switch (type) {
        case 'order_update':
          if (data.containsKey('order_id')) {
            // Navigate to order details page
            Navigator.pushNamed(
              context, 
              '/order-details',
              arguments: {'order_id': data['order_id']},
            );
          }
          break;
          
        case 'new_offer':
          // Navigate to offers page
          Navigator.pushNamed(context, '/offers');
          break;
          
        default:
          // Default navigation
          Navigator.pushNamed(context, '/notifications');
      }
    } else {
      // Default navigation if no type specified
      Navigator.pushNamed(context, '/notifications');
    }
  }
  
  // Check if app was opened from a notification
  bool get wasOpenedFromNotification => _initialMessage != null || _messageOpenedApp != null;
  
  // Get the message that opened the app
  RemoteMessage? get openingMessage => _messageOpenedApp ?? _initialMessage;
  
  // Handle app opened from notification
  void handleAppOpenedFromNotification(BuildContext context) {
    if (wasOpenedFromNotification && openingMessage != null) {
      Future.delayed(Duration.zero, () {
        _handleNotificationTap(context, openingMessage!);
      });
      
      // Clear the messages to prevent duplicate handling
      _initialMessage = null;
      _messageOpenedApp = null;
    }
  }
  
  // Dispose resources
  void dispose() {
    _messageStreamController.close();
  }
} 