import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../authentication/auth_screen.dart';
import '../global/global.dart';

import '../mainScreens/home_screen.dart';

class MySplashScreen extends StatefulWidget {
  const MySplashScreen({Key? key}) : super(key: key);

  @override
  State<MySplashScreen> createState() => _MySplashScreenState();
}

class _MySplashScreenState extends State<MySplashScreen> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  // Use the same key as ApiService
  static const String _tokenKey = 'vendor_auth_token';

  startTimer() async {
    String? token;
    try {
      token = await _secureStorage.read(key: _tokenKey);
      print("Retrieved token: $token");
    } catch (e) {
      print("Error reading token: $e");
      token = null;
    }

    Timer(const Duration(seconds: 1), () async {
      if (token != null && token.isNotEmpty) {
        bool isValid = true;

        if (isValid) {
          sharedPreferences?.setString('auth_token', token);
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (c) => const HomeScreen()));
        } else {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (c) => const AuthScreen()));
        }
      } else {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (c) => const AuthScreen()));
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
    return Material(
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Image.asset("assets/images/splash.jpg"),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.all(18.0),
                child: Text(
                  "Welcome to FoodOnDoor",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 40,
                    fontFamily: "Signatra",
                    letterSpacing: 3,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              CircularProgressIndicator(
                 valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
