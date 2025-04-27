import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../global/global.dart'; // For sharedPreferences
import '../mainScreens/home_screen.dart';
import '../services/api_service.dart'; // Assuming ApiService exists
import '../widgets/loading_dialog.dart';
import 'register.dart'; // Import the next screen

class OtpScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpScreen({super.key, required this.phoneNumber});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  TextEditingController otpController = TextEditingController();
  bool _isLoading = false;
  final ApiService _apiService = ApiService();
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _resendSeconds = 60;
    });
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds > 0) {
        setState(() {
          _resendSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _resendOtp() async {
    setState(() { _isLoading = true; });
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => LoadingDialog(message: "Resending OTP..."));
    try {
      final response = await _apiService.sendOtp(widget.phoneNumber);
      Navigator.pop(context);
      if (response['success'] == true || response.containsKey('debug_otp')) {
        Fluttertoast.showToast(msg: "OTP resent successfully.");
        _startResendTimer();
      } else {
        Fluttertoast.showToast(msg: "Error: ${response['error'] ?? 'Failed to resend OTP'}");
      }
    } catch (e) {
      Navigator.pop(context);
      Fluttertoast.showToast(msg: "Error: ${e.toString()}");
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _verifyOtp() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => LoadingDialog(message: "Verifying OTP..."));

      try {
        final response = await _apiService.verifyOtp(widget.phoneNumber, otpController.text.trim());
        Navigator.pop(context); // Dismiss loading

        if (response['success'] == true || (response.containsKey('message') && response['message'] == 'Please complete signup')) { // Check for success or signup message
          if (response['is_signup'] == true) {
            // Navigate to RegisterScreen (was MinimalSignupScreen)
             Fluttertoast.showToast(msg: "OTP Verified. Please complete signup.");
             Navigator.pushReplacement(
               context,
               MaterialPageRoute(builder: (c) => RegisterScreen(phone: widget.phoneNumber)), // Use correct class name
             );
          } else {
            // Login Success
            if (response.containsKey('auth_token')) {
               await _apiService.storeToken(response['auth_token']);
               // Store user details if present
               if (response.containsKey('user')) {
                 final userData = response['user'] as Map<String, dynamic>;
                 await sharedPreferences!.setString("uid", userData['user_id']?.toString() ?? '');
                 await sharedPreferences!.setString("name", userData['full_name'] ?? '');
                 await sharedPreferences!.setString("email", userData['email'] ?? '');
                 await sharedPreferences!.setString("phone", userData['phone'] ?? widget.phoneNumber);
               } else {
                 await sharedPreferences!.setString("uid", response['user_id']?.toString() ?? '');
                 await sharedPreferences!.setString("phone", widget.phoneNumber);
               }
               Fluttertoast.showToast(msg: "Login Successful.");
               Navigator.pushReplacement(
                 context,
                 MaterialPageRoute(builder: (c) => const HomeScreen()),
               );
            } else {
               setState(() { _isLoading = false; });
               Fluttertoast.showToast(msg: "Login failed: Missing token or user data.");
            }
          }
        } else {
           setState(() { _isLoading = false; });
           Fluttertoast.showToast(msg: "Error: ${response['error'] ?? 'Invalid OTP or verification failed'}");
        }
      } catch (e) {
        Navigator.pop(context); // Dismiss loading on error
        setState(() { _isLoading = false; });
        Fluttertoast.showToast(msg: "Error: ${e.toString()}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text("Verify OTP", style: Theme.of(context).appBarTheme.titleTextStyle), centerTitle: true, elevation: 0),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Enter OTP sent to ${widget.phoneNumber}",
                  textAlign: TextAlign.center,
                  // Apply theme text style
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.textTheme.bodyMedium?.color),
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6, // Typical OTP length
                  style: const TextStyle(fontSize: 24, letterSpacing: 10),
                  decoration: const InputDecoration(
                    hintText: "------",
                    counterText: "", // Hide the counter
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the OTP';
                    }
                    if (value.length != 6) {
                       return 'OTP must be 6 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  // Remove explicit style to inherit from theme
                  // style: ElevatedButton.styleFrom(
                  //     backgroundColor: Colors.cyan,
                  //     padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  //     textStyle: const TextStyle(fontSize: 18)),
                  child: _isLoading
                      ? const SizedBox(child: CircularProgressIndicator(color: Colors.white), height: 24, width: 24)
                      // Use Text widget directly to allow theme's ElevatedButton style to control text style
                      : const Text("Verify OTP"),
                ),
                 const SizedBox(height: 20),
                 TextButton(
                    onPressed: (_resendSeconds > 0 || _isLoading) ? null : _resendOtp,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.primaryColor,
                    ),
                    child: Text(_resendSeconds > 0 ? "Resend OTP ($_resendSeconds s)" : "Resend OTP?"),
                 )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
