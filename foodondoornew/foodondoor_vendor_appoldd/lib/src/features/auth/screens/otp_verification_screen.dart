import 'package:flutter/material.dart';
import 'package:foodondoor_vendor_app/src/features/auth/providers/auth_provider.dart'; // Adjusted import
import 'package:foodondoor_vendor_app/src/features/home/screens/home_screen.dart'; // Adjusted import
import 'package:provider/provider.dart';

class OtpVerificationScreen extends StatefulWidget {
  static const routeName = '/otp-verification';

  final String phoneNumber;

  const OtpVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final otp = _otpController.text.trim();

    final success = await authProvider.verifyOtp(widget.phoneNumber, otp);

    // Navigation is handled by the Consumer<AuthProvider> in main.dart based on status change
    if (!success && mounted) { // Only show error if verifyOtp failed
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage != null && authProvider.errorMessage!.isNotEmpty
              ? authProvider.errorMessage!
              : 'Failed to verify OTP. Please check the code and try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    // final isLoading = authProvider.status == AuthStatus.loading;
    final isLoading = authProvider.status == AuthStatus.authenticating;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Vendor OTP'), // Adjusted title
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Enter the 6-digit OTP sent to ${widget.phoneNumber}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _otpController,
                  decoration: const InputDecoration(
                    labelText: 'OTP Code',
                    hintText: 'Enter the 6-digit code',
                    prefixIcon: Icon(Icons.password),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the OTP';
                    }
                    if (value.trim().length != 6) {
                      return 'OTP must be 6 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _submit,
                        child: const Text('Verify OTP'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
