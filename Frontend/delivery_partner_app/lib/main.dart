import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'package:firebase_messaging/firebase_messaging.dart'; // Import Firebase Messaging

import 'providers/auth_provider.dart';
import 'providers/order_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/signup_screen.dart';
import 'services/notification_service.dart';

// Make main async
void main() async {
  print("--- main() started ---");
  WidgetsFlutterBinding.ensureInitialized();
  print("--- WidgetsFlutterBinding initialized ---");

  try {
    print("--- Initializing Firebase... ---");
    await Firebase.initializeApp();
    print("--- Firebase initialized SUCCESSFULLY ---");
  } catch (e) {
    print("--- Firebase initialization FAILED: $e ---");
    // Optionally handle the error, e.g., show an error screen
    runApp(MaterialApp(home: Scaffold(body: Center(child: Text("Firebase Init Failed: $e")))));
    return; // Exit main if Firebase fails
  }

  // Set the background message handler *after* Firebase init and *before* runApp
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  print("--- Background handler set ---");

  print("--- Calling runApp()... ---");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use MultiProvider to provide multiple providers
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        // OrderProvider depends on AuthProvider (implicitly via ApiHelper)
        // If OrderProvider needed direct access to AuthProvider state, use ChangeNotifierProxyProvider
        ChangeNotifierProvider(create: (context) => OrderProvider()),
      ],
      child: MaterialApp(
        title: 'Delivery Partner App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange), // Example theme
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        home: const AuthWrapper(), // Use a wrapper to decide the initial screen
        // Define routes for navigation (optional but good practice)
        routes: {
          '/login': (context) => const LoginScreen(),
          '/otp': (context) => const OTPScreen(phoneNumber: ''), // Placeholder, pass number during navigation
          '/signup': (context) => const SignupScreen(phoneNumber: ''), // Placeholder, pass number during navigation
          '/home': (context) => const HomeScreen(),
        },
      ),
    );
  }
}

// Widget to handle switching between Auth screens and Home screen
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final NotificationService _notificationService = NotificationService();
  bool _notificationsInitialized = false;

  @override
  Widget build(BuildContext context) {
    // Use Consumer to react to auth changes
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        debugPrint("[AuthWrapper] Building with status: ${authProvider.status}");

        switch (authProvider.status) {
          case AuthStatus.unknown:
          case AuthStatus.authenticating:
            debugPrint("[AuthWrapper] Showing Loading Indicator");
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          case AuthStatus.otpSent:
             debugPrint("[AuthWrapper] Showing OTPScreen");
             // Directly show OTPScreen when OTP has been sent
             // Ensure pendingPhoneNumber is not null before showing
             final phone = authProvider.pendingPhoneNumber;
             return phone != null
                ? OTPScreen(phoneNumber: phone)
                : const LoginScreen(); // Fallback if number somehow missing
          case AuthStatus.unauthenticated:
             debugPrint("[AuthWrapper] Showing LoginScreen");
             _notificationsInitialized = false;
             return const LoginScreen();
          case AuthStatus.needsSignup:
             debugPrint("[AuthWrapper] Showing SignupScreen");
             _notificationsInitialized = false;
             final phone = authProvider.pendingPhoneNumber;
             return phone != null
                ? SignupScreen(phoneNumber: phone)
                : const LoginScreen(); // Fallback
          case AuthStatus.authenticated:
            debugPrint("[AuthWrapper] Showing HomeScreen, Initializing Notifications/Orders: $_notificationsInitialized");
            if (!_notificationsInitialized) {
               debugPrint("[AuthWrapper] Running post-frame callback for init");
               WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) { // Check if widget is still mounted
                     debugPrint("[AuthWrapper] Initializing Notifications");
                     _notificationService.initialize(context);
                     debugPrint("[AuthWrapper] Refreshing All Order Lists");
                     Provider.of<OrderProvider>(context, listen: false).refreshAllLists();
                  }
               });
               _notificationsInitialized = true;
            }
            return const HomeScreen();
        }
      },
    );
  }
}

// Define the background handler function at the top level (outside any class)
// Ensure this matches the function signature expected by onBackgroundMessage
@pragma('vm:entry-point') // Required for release mode
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you need to initialize Firebase again here (e.g., for other services),
  // ensure it's done.
  // await Firebase.initializeApp(); // Often needed here too
  print("Handling a background message: ${message.messageId}");
  print('Message data: ${message.data}');
  // Add any background handling logic here
}
