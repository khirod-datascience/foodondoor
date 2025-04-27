import 'dart:math';

import 'package:flutter/material.dart';
import '../authentication/login.dart';
// import '../authentication/register.dart'; // No longer needed here

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  @override
  Widget build(BuildContext context) {
    // Removed DefaultTabController
    return Scaffold(
      appBar: AppBar(
        // Removed flexibleSpace with gradient
        automaticallyImplyLeading: false,
        title: const Text(
          'Food On Door', // Use consistent app name
          // Removed hardcoded TextStyle, will use AppBarTheme
        ),
        centerTitle: true,
        // Removed bottom TabBar
      ),
      // Removed Container with gradient background
      // Directly use Scaffold's background from theme
      body: const LoginScreen(),
    );
  }
}
