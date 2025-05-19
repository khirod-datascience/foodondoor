import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../config.dart';
import 'DetailsFormScreen.dart';
import 'dashboard_screen.dart';
import 'package:foodondoor_restaurant/utils/globals.dart'; // Import the global file
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences
import '../services/simple_notification_service.dart'; // Import FCM notification service

class LoginSignupScreen extends StatefulWidget {
  @override
  _LoginSignupScreenState createState() => _LoginSignupScreenState();
}

class _LoginSignupScreenState extends State<LoginSignupScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isOTPSent = false;
  int _remainingTime = 60;
  Timer? _otpTimer;

  void _startOTPTimer() {
    setState(() {
      _remainingTime = 60;
    });
    _otpTimer?.cancel();
    _otpTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _otpTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    try {
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/auth/send-otp/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': _phoneController.text}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _isOTPSent = true;
          _startOTPTimer();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("OTP sent to your phone!")),
        );
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Failed to send OTP!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Network error: Unable to send OTP!")),
      );
    }
  }

  Future<void> _verifyOTP() async {
    try {
      print("Starting OTP verification...");
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/auth/verify-otp/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': _phoneController.text,
          'otp': _otpController.text,
        }),
      );

      print("Response status code: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('OTP verify response: ' + response.body);
        // Defensive parsing with null checks and correct keys
        final isSignup = responseData['is_signup'] as bool? ?? false;
        final vendorId = responseData['vendorId'] as String?;
        final token = responseData['token'] as String?;
        final refreshToken = responseData['refreshToken'] as String?;

        if (vendorId != null && vendorId.isNotEmpty) {
          // Store using unified keys and central logic
          await Globals.saveVendorCredentials(vendorId, token ?? '');
          await Globals.initialize(); // Reload static variables after saving
          final prefs = await SharedPreferences.getInstance();
          // Also store the refresh token if present
          if (refreshToken != null && refreshToken.isNotEmpty) {
            await prefs.setString('refresh_token', refreshToken);
            print("Stored refresh_token: $refreshToken");
          }
          print("Stored vendor_id: $vendorId");
          print("Stored auth_token: $token");
          // Trigger FCM token update for vendor after login/signup
          await SimpleNotificationService.instance.initialize(vendorId: vendorId);
        } else {
          print('ERROR: vendorId is null or empty in OTP response');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? 'Login successful')),
        );

        if (isSignup) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DetailsFormScreen(
                phoneNumber: _phoneController.text,
                vendorId: vendorId ?? '', // Defensive: pass empty string if null
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardScreen(),
            ),
          );
        }
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Invalid OTP!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    } catch (e) {
      print("Exception caught: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Network error: Unable to verify OTP!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Login/Signup"),
        backgroundColor: Colors.orange,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade100, Colors.orange.shade300],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Welcome to Vendor App",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "Phone Number",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              SizedBox(height: 16),
              if (_isOTPSent)
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Enter OTP",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isOTPSent ? _verifyOTP : _sendOTP,
                child: Text(_isOTPSent ? "Verify OTP" : "Send OTP"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  textStyle: TextStyle(fontSize: 18),
                ),
              ),
              SizedBox(height: 16),
              if (_isOTPSent && _remainingTime > 0)
                Text(
                  "Resend OTP in $_remainingTime seconds",
                  style: TextStyle(color: Colors.orange.shade800),
                ),
              if (_isOTPSent && _remainingTime == 0)
                ElevatedButton(
                  onPressed: _sendOTP,
                  child: Text("Resend OTP"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    textStyle: TextStyle(fontSize: 18),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}