import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import '../providers/auth_provider.dart';
// Import screens for navigation
import 'signup_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class OTPScreen extends StatefulWidget {
  final String phoneNumber;
  const OTPScreen({super.key, required this.phoneNumber});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isVerifying = false; // Local state to prevent double taps

  @override
  void dispose() {
    debugPrint("[OTPScreen] Disposing");
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp(AuthProvider authProvider) async {
    if (_isVerifying) {
        debugPrint("[OTPScreen] _verifyOtp: Already verifying, returning.");
        return;
    }
    if (_formKey.currentState!.validate()) {
      final otp = _otpController.text;
      debugPrint("[OTPScreen] _verifyOtp: Form valid, setting _isVerifying = true");
      setState(() => _isVerifying = true);

      debugPrint("[OTPScreen] _verifyOtp: Calling authProvider.verifyOtp with OTP: $otp");
      await authProvider.verifyOtp(otp);
      debugPrint("[OTPScreen] _verifyOtp: authProvider.verifyOtp finished. Status: ${authProvider.status}");

      // Navigation is handled by AuthWrapper
      // Show snackbar for errors ONLY if verification didn't succeed (auth or signup)
      if (mounted) {
          if (authProvider.errorMessage != null &&
              authProvider.status != AuthStatus.authenticated &&
              authProvider.status != AuthStatus.needsSignup) {
             debugPrint("[OTPScreen] _verifyOtp: Error detected, showing SnackBar.");
             ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text(authProvider.errorMessage!), backgroundColor: Colors.red),
              );
          }
          // Reset local loading state regardless of outcome
          debugPrint("[OTPScreen] _verifyOtp: Resetting _isVerifying = false");
          setState(() => _isVerifying = false);
      }
    } else {
       // If form invalid, ensure loading is false
        if (_isVerifying) {
           debugPrint("[OTPScreen] _verifyOtp: Form invalid, resetting _isVerifying = false");
           setState(() => _isVerifying = false);
        }
    }
  }

  // TODO: Implement _resendOtp function
  // Future<void> _resendOtp(AuthProvider authProvider) async {
  //    print("Resending OTP to ${widget.phoneNumber}");
  //    await authProvider.sendOtp(widget.phoneNumber);
  //    if (mounted) {
  //      ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text(authProvider.errorMessage ?? 'OTP Resent')),
  //      );
  //    }
  // }

  @override
  Widget build(BuildContext context) {
    // Access provider once for actions
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Listen to provider status for error messages or general auth state changes
    final currentStatus = context.select((AuthProvider p) => p.status);
    final errorMessage = context.select((AuthProvider p) => p.errorMessage);
    debugPrint("[OTPScreen] build called. Status: $currentStatus, _isVerifying: $_isVerifying");

    // Show loading indicator if locally verifying OR provider is authenticating
    bool showOverallLoading = _isVerifying || currentStatus == AuthStatus.authenticating;

    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('Enter the 6-digit OTP sent to\n${widget.phoneNumber}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 20),
              TextFormField(
                controller: _otpController,
                decoration: const InputDecoration(
                  labelText: 'OTP',
                  border: OutlineInputBorder(),
                  counterText: "", // Hide the default counter
                ),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6, // Assuming a 6-digit OTP
                enabled: !showOverallLoading, // Disable if loading
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the OTP';
                  }
                  if (value.length != 6 || int.tryParse(value) == null) {
                     return 'OTP must be 6 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              showOverallLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: CircularProgressIndicator(),
                  )
                : ElevatedButton(
                    onPressed: () => _verifyOtp(authProvider),
                    child: const Text('Verify OTP'),
                  ),
              // Resend OTP Button (Placeholder)
              // TextButton(
              //   onPressed: showOverallLoading ? null : () => _resendOtp(authProvider),
              //   child: const Text('Resend OTP'),
              // ),
              // Display error messages (use listened values)
              if (!showOverallLoading && errorMessage != null)
                 Padding(
                   padding: const EdgeInsets.only(top: 10.0),
                   child: Text(
                     errorMessage,
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
