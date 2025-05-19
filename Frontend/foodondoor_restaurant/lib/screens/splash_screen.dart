import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
// Remove unused imports if SimpleNotificationService and Globals are not needed here
// import '../services/simple_notification_service.dart';
// import '../utils/globals.dart'; 
import 'login_signup_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    _checkLoginAndNavigate();
  }

  Future<void> _checkLoginAndNavigate() async {
    // Wait a bit for appearance and for AuthProvider to potentially auto-login
    await Future.delayed(const Duration(seconds: 2)); 

    if (!mounted) return; // Check if widget is still mounted

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Check authentication status from AuthProvider
    if (authProvider.isAuthenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => DashboardScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => LoginSignupScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Simple splash screen UI - no need for _isInitialized state
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo or App name
            const Text(
              'FoodOnDoor',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Vendor App',
              style: TextStyle(
                fontSize: 18,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(color: Colors.deepOrange),
          ],
        ),
      ),
    );
  }
} 