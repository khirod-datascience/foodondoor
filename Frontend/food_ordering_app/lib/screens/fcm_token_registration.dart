import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/customer_api_service.dart';

class FcmTokenRegistration extends StatefulWidget {
  final String customerId;
  const FcmTokenRegistration({Key? key, required this.customerId}) : super(key: key);
  @override
  State<FcmTokenRegistration> createState() => _FcmTokenRegistrationState();
}

class _FcmTokenRegistrationState extends State<FcmTokenRegistration> {
  String? token;
  bool registering = false;
  String? message;

  Future<void> _registerToken() async {
    setState(() { registering = true; });
    token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      final response = await CustomerApiService.registerFcmToken(widget.customerId, token!);
      message = response.statusCode == 200 ? 'FCM Token registered!' : 'Registration failed';
    }
    setState(() { registering = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: registering ? null : _registerToken,
          child: Text('Register FCM Token'),
        ),
        if (registering) CircularProgressIndicator(),
        if (message != null) Text(message!),
      ],
    );
  }
}
