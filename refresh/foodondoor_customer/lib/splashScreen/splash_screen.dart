import 'dart:async';

import 'package:flutter/material.dart';
import '../authentication/auth_screen.dart';
import '../mainScreens/home_screen.dart';
import '../services/api_service.dart';

class MySplashScreen extends StatefulWidget {
  const MySplashScreen({super.key});

  @override
  State<MySplashScreen> createState() => _MySplashScreenState();
}

class _MySplashScreenState extends State<MySplashScreen> {
  final ApiService _apiService = ApiService();

  startTimer() {
    Timer(const Duration(seconds: 2), () async {
      bool isValidToken = await _apiService.checkAuthStatus();

      if (!mounted) return;

      if (isValidToken) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()));
      } else {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AuthScreen()));
      }
    });
  }

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  @override
  Widget build(BuildContext context) {
    // Use Theme colors
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = theme.primaryColor;
    final Color backgroundColor = theme.scaffoldBackgroundColor;
    final Color textColor = theme.textTheme.bodyMedium?.color ?? Colors.black; // Fallback

    return Material(
      // Use scaffoldBackgroundColor from the theme
      color: backgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.asset('assets/images/welcome.png'),
            ),
            const SizedBox(
              height: 10,
            ),
            Padding(
              padding: const EdgeInsets.all(18.0), // Adjusted padding
              child: Column(
                children: [
                  Text(
                    'Order Food Online With iFood', // Consider changing iFood if brand is FoodOnDoor
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: primaryColor, // Use theme's primary color
                      fontSize: 22, // Slightly larger
                      fontFamily: "Train",
                      fontWeight: FontWeight.bold, // Make it bolder
                      letterSpacing: 2, // Adjusted spacing
                    ),
                  ),
                  const SizedBox(height: 8), // Spacing between texts
                  Text(
                    "World's Largest & No.1 Food Delivery App",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor, // Use theme's default text color
                      fontSize: 18, // Adjusted size
                      fontFamily: "Signatra",
                      letterSpacing: 2, // Adjusted spacing
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
