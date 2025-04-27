import 'dart:math';

import 'package:flutter/material.dart';
import '../authentication/login.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'FoodOnDoor Vendor',
          style: TextStyle(
              fontSize: 30,
              color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
              fontFamily: "Lobster"
          ),
        ),
        centerTitle: true,
      ),
      body: const LoginScreen(),
    );
  }
}
