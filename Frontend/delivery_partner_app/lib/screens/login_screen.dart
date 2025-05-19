import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import '../providers/auth_provider.dart';
import 'otp_screen.dart'; // Import OTPScreen for navigation

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSendingOtp = false; // Local state for button loading

  @override
  void dispose() {
    debugPrint("[LoginScreen] Disposing");
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp(AuthProvider authProvider) async {
    if (_isSendingOtp) {
      debugPrint("[LoginScreen] _sendOtp: Already sending, returning.");
      return;
    }
    if (_formKey.currentState!.validate()) {
      debugPrint("[LoginScreen] _sendOtp: Form valid, setting _isSendingOtp = true");
      setState(() => _isSendingOtp = true);
      final phoneNumber = _phoneController.text;

      debugPrint("[LoginScreen] _sendOtp: Calling authProvider.sendOtp for $phoneNumber");
      // Call the provider method
      await authProvider.sendOtp(phoneNumber);
      debugPrint("[LoginScreen] _sendOtp: authProvider.sendOtp finished. Status: ${authProvider.status}, Error: ${authProvider.errorMessage}");

      // Check status *after* the await completes
      // AuthWrapper will handle navigation based on otpSent status
      if (mounted) {
        if (authProvider.status == AuthStatus.otpSent) {
           debugPrint("[LoginScreen] _sendOtp: SUCCESS - AuthWrapper will handle navigation.");
           // NO NAVIGATION HERE - Let AuthWrapper handle it.
           // Navigator.pushReplacement(
           //   context,
           //   MaterialPageRoute(builder: (ctx) => OTPScreen(phoneNumber: phoneNumber)),
           // );
           // return; // Don't need return if not navigating
        } else if (authProvider.errorMessage != null) {
          // Show error ONLY if status is not otpSent (otherwise AuthWrapper handles screen)
          debugPrint("[LoginScreen] _sendOtp: FAILED - Showing SnackBar.");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(authProvider.errorMessage!), backgroundColor: Colors.red),
          );
        }
        // Reset local loading state
        debugPrint("[LoginScreen] _sendOtp: Resetting _isSendingOtp = false");
        setState(() => _isSendingOtp = false);
      }
    } else {
      // If form is invalid, ensure loading state is false
      if (_isSendingOtp) {
           debugPrint("[LoginScreen] _sendOtp: Form invalid, resetting _isSendingOtp = false");
           setState(() => _isSendingOtp = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("[LoginScreen] build called.");
    // Use Provider.of to get the provider instance for the button
    // and also to listen for status changes for the general loading state
    final authProvider = Provider.of<AuthProvider>(context);
    // Show loading if provider is in initial authenticating state OR if we are locally sending OTP
    bool showOverallLoading = authProvider.status == AuthStatus.authenticating || _isSendingOtp;
    debugPrint("[LoginScreen] Builder: _isSendingOtp=$_isSendingOtp, Provider Status=${authProvider.status}, showOverallLoading=$showOverallLoading");

    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Partner Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'e.g., 9876543210',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                enabled: !showOverallLoading, // Disable field while loading
                validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    if (!RegExp(r'^[0-9]{10}$').hasMatch(value)) {
                      return 'Please enter a valid 10-digit phone number';
                    }
                    return null;
                },
              ),
              const SizedBox(height: 20),
              // Show loading indicator OR the button
              showOverallLoading
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: const CircularProgressIndicator(),
                    )
                  : ElevatedButton(
                      onPressed: () => _sendOtp(authProvider), // Pass the provider
                      child: const Text('Send OTP'),
                    ),
              // Display error messages ONLY when not loading and error exists
              if (!showOverallLoading && authProvider.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(
                    authProvider.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
