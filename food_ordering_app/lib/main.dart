import 'package:flutter/material.dart';
// Purpose: Defines the main entry point and initializes the app.

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/orders_screen.dart'; // Add import for existing orders screen
import 'providers/auth_provider.dart';
import 'providers/home_provider.dart';
import 'providers/cart_provider.dart';
import 'utils/globals.dart';
import 'package:dio/dio.dart';
import 'config.dart';
import 'utils/auth_storage.dart';
import 'widgets/order_status_banner.dart';
import 'services/simple_notification_service.dart'; // Import our notification service

Future<String?> loadCurrentAddressId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('current_address_id');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  debugPrint('================= APP STARTING =================');
  
  // Initialize FCM notifications service
  debugPrint('Initializing notifications service...');
  try {
    await SimpleNotificationService.instance.initialize();
    debugPrint('Notifications service initialized successfully');
  } catch (e) {
    debugPrint('Error initializing notifications service: $e');
  }
  
  debugPrint('Testing authentication storage mechanisms...');

  // Test if auth storage is working properly
  try {
    final storageWorking = await AuthStorage.testStorage();
    debugPrint('Authentication storage test result: ${storageWorking ? "PASSED" : "FAILED"}');
  } catch (e) {
    debugPrint('Error testing storage: $e');
  }

  // Try to load customer_id from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final savedCustomerId = prefs.getString('customer_id');
  final fallbackToken = prefs.getString('auth_token_fallback');
  
  debugPrint('STARTUP: Checking saved login state');
  debugPrint('Saved customer_id: $savedCustomerId');
  debugPrint('Fallback token exists: ${fallbackToken != null}');
  
  if (savedCustomerId != null) {
    globalCustomerId = savedCustomerId;
    debugPrint('Loaded saved customer_id: $globalCustomerId');

    // Also check for saved token in AuthStorage
    try {
      final token = await AuthStorage.getToken();
      debugPrint('Authentication token loaded: ${token != null ? "Yes" : "No"}');
      
      if (token == null && fallbackToken != null) {
        debugPrint('Using fallback token from SharedPreferences');
        // Migrate the fallback token to AuthStorage
        await AuthStorage.saveToken(fallbackToken);
      }
    } catch (e) {
      debugPrint('Error loading authentication token: $e');
    }
  } else {
    debugPrint('No saved customer_id found - user is not logged in');
  }

  // Load saved address ID and attempt to fetch address details if logged in
  if (globalCustomerId != null) {
    final savedAddressId = await loadCurrentAddressId();
    if (savedAddressId != null) {
      // Attempt to fetch the full address details early
      try {
          final dio = Dio();
          
          // Add authentication token if available
          Map<String, dynamic> headers = {};
          try {
            final token = await AuthStorage.getToken();
            if (token != null) {
              headers['Authorization'] = 'Bearer $token';
              debugPrint('Added authorization header for address fetch');
            }
          } catch (e) {
            debugPrint('Error getting token for address fetch: $e');
          }
          
          final url = '${AppConfig.baseUrl}/addresses/$savedAddressId/'; // Endpoint for single address
          debugPrint('Attempting to pre-load address: $url');
          
          final response = await dio.get(
            url,
            options: headers.isNotEmpty ? Options(headers: headers) : null
          );
          
          if (response.statusCode == 200 && response.data is Map) {
             globalCurrentAddress = Map<String, dynamic>.from(response.data);
             debugPrint('Successfully pre-loaded address: ${globalCurrentAddress?['address_line1']}');
          } else {
             debugPrint('Failed to pre-load address, status: ${response.statusCode}');
          }
      } catch (e) {
         debugPrint('Error pre-loading address $savedAddressId: $e');
         // Don't block startup, address can be selected later
      }
    }
  }
  debugPrint('===============================================');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
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
      title: 'Food Delivery App',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
      ),
      home: globalCustomerId == null ? const LoginScreen() : const HomeScreen(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/restaurant-detail':
            final args = settings.arguments as Map<String, dynamic>?; // Allow null args
            final vendorId = args?['vendor_id'] as String?; // Safely get vendor_id as String?
            
            if (vendorId != null && vendorId.isNotEmpty) {
              debugPrint('Navigating to MenuScreen with vendorId: $vendorId');
              // Pass vendorId to the restaurantId parameter of MenuScreen
              return MaterialPageRoute(builder: (context) => MenuScreen(restaurantId: vendorId)); 
            } else {
              // Handle error: ID is missing or invalid
              debugPrint('Error: vendor_id is null or empty for /restaurant-detail');
              // Redirect to home or show an error page
              return MaterialPageRoute(builder: (context) => const HomeScreen()); // Or an ErrorScreen
            }
          
          case '/order-details':
            // Temporarily redirect to orders screen until we have an OrderDetailsScreen
            debugPrint('OrderDetailsScreen is not implemented yet, redirecting to orders');
            return MaterialPageRoute(builder: (context) => const OrdersScreen());
            
          case '/orders':
            return MaterialPageRoute(builder: (context) => const OrdersScreen());
            
          case '/notifications':
            // Temporarily redirect to home screen until we have a NotificationsScreen
            debugPrint('NotificationsScreen is not implemented yet, redirecting to home');
            return MaterialPageRoute(builder: (context) => const HomeScreen());
            
          default:
            // Handle unknown routes, maybe redirect to home
            return MaterialPageRoute(builder: (context) => const HomeScreen());
        }
      },
      // Keep existing routes if they don't need argument handling
      routes: {
         // '/login': (context) => const LoginScreen(), // Example if you have simple routes
         // Add other simple routes here
      },
    );
  }
}
