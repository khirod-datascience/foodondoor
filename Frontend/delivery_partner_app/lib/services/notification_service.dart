import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart'; // For BuildContext if needed for navigation/dialogs

// Placeholder for handling notification tap
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, like Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  // await Firebase.initializeApp(); // Ensure initialized if needed

  print("Handling a background message: ${message.messageId}");
  print('Message data: ${message.data}');
  // TODO: Implement background message handling (e.g., update local state, show notification)
}

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize(BuildContext? context) async {
     print("Initializing NotificationService...");
     // Request permissions (iOS and web)
     NotificationSettings settings = await _firebaseMessaging.requestPermission(
       alert: true,
       announcement: false,
       badge: true,
       carPlay: false,
       criticalAlert: false,
       provisional: false,
       sound: true,
     );

     print('User granted permission: ${settings.authorizationStatus}');

     // Get the FCM token
     String? token = await _firebaseMessaging.getToken();
     print("Firebase Messaging Token: $token");
     // TODO: Send this token to your backend server to associate it with the logged-in user

     // Handle token refresh
     _firebaseMessaging.onTokenRefresh.listen((newToken) {
       print("FCM Token Refreshed: $newToken");
       // TODO: Send the new token to your backend
     });

     // Handle messages received while the app is in the foreground
     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
       print('Got a message whilst in the foreground!');
       print('Message data: ${message.data}');

       if (message.notification != null) {
         print('Message also contained a notification: ${message.notification}');
         // TODO: Show a local notification/snackbar/dialog
         // Example: Use overlay or a dialog to show the message
         if (context != null) {
            _showForegroundNotificationDialog(context, message);
         }
       }
        // TODO: Potentially refresh order lists if the message indicates a new order
     });

      // Handle notification tap when app is opened from terminated state
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
         if (message != null) {
            print('App opened from terminated state by notification: ${message.data}');
             // TODO: Handle navigation based on message data (e.g., open specific order)
             _handleNotificationTap(context, message);
         }
      });

     // Handle notification tap when app is opened from background state
     FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
       print('App opened from background state by notification: ${message.data}');
        // TODO: Handle navigation based on message data
       _handleNotificationTap(context, message);
     });

     // Set the background message handler
     FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  }

  // Example: Show a simple dialog for foreground messages
   void _showForegroundNotificationDialog(BuildContext context, RemoteMessage message) {
      showDialog(
         context: context,
         builder: (context) => AlertDialog(
            title: Text(message.notification?.title ?? 'New Notification'),
            content: Text(message.notification?.body ?? 'You have a new message.'),
            actions: [
               TextButton(
                  child: const Text('Dismiss'),
                  onPressed: () => Navigator.of(context).pop(),
               ),
               // Optionally add an action based on the notification data
               if (message.data['order_id'] != null) // Example check
                  TextButton(
                     child: const Text('View Order'),
                     onPressed: () {
                        Navigator.of(context).pop();
                        // TODO: Navigate to OrderDetailScreen(orderId: message.data['order_id'])
                        print("Navigate to order: ${message.data['order_id']}");
                     },
                  ),
            ],
         ),
      );
   }

   // Central handler for notification taps
    void _handleNotificationTap(BuildContext? context, RemoteMessage message) {
      // Example: Navigate if context is available and order_id exists
      if (context != null && message.data['order_id'] != null) {
          final orderId = message.data['order_id'] as String;
          // TODO: Navigate to OrderDetailScreen(orderId: orderId);
           print("Handle tap: Navigate to order: $orderId");
           // Example using Navigator.pushNamed if routes are set up
           // Navigator.pushNamed(context, '/order-details', arguments: orderId);
      }
    }
}
