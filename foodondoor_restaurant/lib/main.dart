import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:foodondoor_restaurant/providers/auth_provider.dart';
import 'package:foodondoor_restaurant/providers/order_provider.dart';
import 'package:foodondoor_restaurant/providers/menu_provider.dart';
import 'package:foodondoor_restaurant/screens/splash_screen.dart';
import 'package:foodondoor_restaurant/utils/globals.dart' as globals; // Use alias
import 'services/simple_notification_service.dart'; // Keep notification service
import 'screens/dashboard_screen.dart'; // Keep DashboardScreen
import 'screens/login_signup_screen.dart'; // Keep LoginSignupScreen
import 'screens/order_details_screen.dart'; // Keep OrderDetailScreen
import 'screens/notifications_screen.dart'; // Keep NotificationsScreen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };
  
  debugPrint('================= VENDOR APP STARTING =================');
  
  // --- Crucial: Initialize Globals FIRST ---
  await globals.Globals.initialize();
  debugPrint('Globals initialization complete.');
  debugPrint('Initial Vendor ID: ${globals.globalVendorId}');
  debugPrint('Initial Token: ${globals.globalToken != null}');

  // Create AuthProvider instance - this will trigger _tryAutoLogin
  final authProvider = AuthProvider();
  // Wait for auto-login attempt to complete
  await authProvider.isInitializationComplete;
  debugPrint('AuthProvider initialization complete. Is Authenticated: ${authProvider.isAuthenticated}');

  // --- Initialize Notification Service AFTER checking login ---
  if (authProvider.isAuthenticated) {
    debugPrint('User is authenticated, initializing notifications...');
    try {
      // DO NOT await here, let it initialize in background
      SimpleNotificationService.instance.initialize(); 
      debugPrint('Notifications service initialization started.');
    } catch (e) {
      debugPrint('Error starting notifications service initialization: $e');
    }
  } else {
    debugPrint('User not authenticated, skipping notification service init.');
  }
  
  debugPrint('===============================================');

  runApp(
    MultiProvider(
      providers: [
        // Provide the created AuthProvider instance
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => MenuProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Food Delivery Vendor',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
      ),
      home: const SplashScreen(),
      onGenerateRoute: (settings) {
        // Handle route generation with parameters
        switch (settings.name) {
          case '/order-details':
            final args = settings.arguments as Map<String, dynamic>?;
            final orderId = args?['order_id'] as String?;
            if (orderId != null) {
              return MaterialPageRoute(
                builder: (context) => OrderDetailScreen(orderId: orderId),
              );
            }
            // Fallback if orderId is null (should not happen ideally)
            return MaterialPageRoute(
              builder: (context) => DashboardScreen(), 
            );
          
          case '/notifications':
            return MaterialPageRoute(
              builder: (context) => const NotificationsScreen(),
            );
            
          default:
            // Handle unknown routes
            return null;
        }
      },
    );
  }
}