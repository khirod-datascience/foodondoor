import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Vendor notification channel (must match backend channel_id)
  static const AndroidNotificationChannel vendorChannel = AndroidNotificationChannel(
    'vendor_notifications', // id (must match backend)
    'Vendor Notifications', // title
    description: 'Channel for vendor delivery notifications',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound('vendor_delivery_ring'), // no .wav extension
  );

  final AndroidNotificationChannel _channel = const AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );

  /// Call this in main() after Firebase.initializeApp()
  Future<void> init() async {
    await _initLocalNotifications();
    await _requestPermission();
    await _setupFCMListeners();
    await _printTokenForDebug(); // remove in production
  }

  /// Initialize flutter_local_notifications
  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(settings);

    // Create Android notification channels
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(vendorChannel);
  }

  /// Ask user for notification permissions (especially on iOS and Android 13+)
  Future<void> _requestPermission() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint("🚫 Notifications permission denied.");
    } else {
      debugPrint("✅ Notifications permission granted: ${settings.authorizationStatus}");
    }
  }

  /// Listen for all FCM message types
  Future<void> _setupFCMListeners() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("📥 FCM Foreground: ${message.notification?.title}");
      _showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("📲 App opened from notification: ${message.notification?.title}");
      // Navigate or handle logic
    });

    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint("🚀 App launched via notification: ${initialMessage.notification?.title}");
      // Navigate or handle logic
    }

    // FCM token refresh listener
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      debugPrint("🔁 FCM token refreshed: $newToken");
      // Save this token to your backend
    });
  }

  /// Display a local notification for foreground FCM message
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // Use vendor channel if backend sent vendor_notifications channel_id
    final androidChannelId = message.android?.notification?.channelId;
    final useVendorChannel = androidChannelId == vendorChannel.id;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          useVendorChannel ? vendorChannel.id : _channel.id,
          useVendorChannel ? vendorChannel.name : _channel.name,
          channelDescription: useVendorChannel ? vendorChannel.description : _channel.description,
          importance: useVendorChannel ? Importance.max : Importance.high,
          priority: Priority.high,
          sound: useVendorChannel ? vendorChannel.sound : null,
        ),
        iOS: IOSNotificationDetails(
          sound: useVendorChannel ? 'vendor_delivery_ring.wav' : null,
        ),
      ),
    );
  }

  /// Fetch and return FCM token
  Future<String?> getFcmToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      return token;
    } catch (e) {
      debugPrint("❌ Failed to get FCM token: $e");
      return null;
    }
  }

  /// Debug helper to print token in console
  Future<void> _printTokenForDebug() async {
    final token = await getFcmToken();
    debugPrint("📱 FCM Token: $token");
  }
}
