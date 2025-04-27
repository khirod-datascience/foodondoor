import 'dart:async';

import 'package:flutter/material.dart';
import 'package:foodondoor_delivery/authentication/otp_screen.dart';
import 'package:foodondoor_delivery/mainScreens/home_screen.dart';
import 'package:foodondoor_delivery/global/global.dart';
import 'package:foodondoor_delivery/services/api_service.dart';

class MySplashScreen extends StatefulWidget {
  const MySplashScreen({super.key});

  @override
  State<MySplashScreen> createState() => _MySplashScreenState();
}

class _MySplashScreenState extends State<MySplashScreen> {
  ApiService apiService = ApiService();

  startTimer() async {
    Timer(const Duration(seconds: 3), () async {
      if (await apiService.isAuthenticated()) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => const HomeScreen()));
      } else {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => const OtpScreen()));
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
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.asset('assets/images/logo.png'),
            ),
            const SizedBox(
              height: 10,
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Column(
                children: const [
                  Text(
                    'Food on Door - Rider',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.black54,
                        fontSize: 36,
                        letterSpacing: 2),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Your Delivery Partner",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                        letterSpacing: 1),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    ));
  }
}
