import 'package:flutter/material.dart';
import 'package:foodondoor_vendor_app/src/features/auth/providers/auth_provider.dart'; // Adjusted import
import 'package:foodondoor_vendor_app/src/features/auth/screens/otp_verification_screen.dart'; // Adjusted import
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final phone = _phoneController.text.trim();

    final success = await authProvider.sendOtp(phone);

    // Navigation is now handled by the Consumer<AuthProvider> in main.dart based on status change
    // Remove the explicit navigation call here:
    // if (success && mounted) {
    //   Navigator.of(context).pushReplacementNamed(OtpVerificationScreen.routeName);
    // }

    if (!success && mounted) { // Only show error if sendOtp failed
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage != null ? authProvider.errorMessage! : 'Failed to send OTP. Please check your connection.'),
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
        title: const Text('Vendor Login - Phone'), // Adjusted title
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Enter your registered phone number to receive an OTP.', // Adjusted text
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'Enter your 10-digit phone number',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your phone number';
                    }
                    if (value.trim().length != 10) { 
                      return 'Please enter a valid 10-digit phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _submit,
                        child: const Text('Send OTP'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
