import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_signup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'globals.dart'; // Make sure to import globals.dart
import 'package:firebase_core/firebase_core.dart';
import 'screens/notifications_screen.dart';
import 'screens/order_details_screen.dart';
import 'services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final prefs = await SharedPreferences.getInstance();
  
  try {
    final storedVendorId = prefs.getString('vendorId');
    print("Stored vendorId: $storedVendorId");
    
    if (storedVendorId != null && storedVendorId.isNotEmpty) {
      Globals.vendorId = storedVendorId;
      print("Loaded vendorId: ${Globals.vendorId}");
    } else {
      print("No valid vendorId found in SharedPreferences");
    }
  } catch (e) {
    print("Error loading vendorId: $e");
    await prefs.remove('vendorId');
  }

  print("Final vendorId value: ${Globals.vendorId}");
  
  // Ensure vendorId is properly set before running the app
  if (Globals.vendorId == null) {
    print("Warning: vendorId is null before app start");
  }
  
  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(MyApp(notificationService: notificationService));
}

class MyApp extends StatelessWidget {
  final NotificationService notificationService;

  const MyApp({Key? key, required this.notificationService}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'Vendor App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: Consumer<AuthService>(
          builder: (context, authService, _) {
            return authService.currentUser != null
                ? HomeScreen()
                : LoginScreen();
          },
        ),
        onGenerateRoute: (settings) {
          if (settings.name == '/notifications') {
            return MaterialPageRoute(builder: (context) => NotificationsScreen());
          } else if (settings.name == '/order_details') {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => OrderDetailsScreen(order: args),
            );
          }
          return null;
        },
      ),
    );
  }
}