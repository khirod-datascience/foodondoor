import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:foodondoor_vendor_app/src/features/auth/providers/auth_provider.dart';
import 'package:foodondoor_vendor_app/src/features/auth/services/auth_service.dart';
import 'package:foodondoor_vendor_app/src/utils/validators.dart'; // Assuming validators exist

class RegistrationScreen extends StatefulWidget {
  static const routeName = '/register';
  final String signupToken; // Passed from main.dart routing

  const RegistrationScreen({required this.signupToken, super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _businessNameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _businessNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return; // Validation failed
    }
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    // NOTE: AuthService.registerVendor internally retrieves the signupToken from storage
    // We just need to pass the profile data.
    final profileData = {
      'email': _emailController.text.trim(),
      'business_name': _businessNameController.text.trim(),
      // 'fcm_token': 'some_token' // TODO: Implement FCM token retrieval later
    };

    bool success = await authService.registerVendor(profileData);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        // Navigation is handled by the Consumer<AuthProvider> in main.dart
        // when the status changes to authenticated after registration.
        print('Registration successful. AuthProvider state change will trigger navigation.');
      } else {
        // Use error message from AuthService if available
        // final errorMessage = authService.lastError ?? 'Registration failed. Please try again.';
        // TODO: Expose lastError from AuthService or handle errors better
        final errorMessage = 'Registration failed. Please try again.'; 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use theme from main.dart
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Vendor Registration'),
        // Prevent navigating back if registration is required
        // automaticallyImplyLeading: false, 
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
                  'Please provide your business details to complete registration.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 30),
                
                // Business Name
                TextFormField(
                  controller: _businessNameController,
                  decoration: const InputDecoration(
                    labelText: 'Business Name',
                    hintText: 'Enter your restaurant/store name',
                    prefixIcon: Icon(Icons.storefront),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your business name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Email
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'Enter your email address',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.validateEmail, // Use a validator util
                ),
                const SizedBox(height: 30),

                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        style: theme.elevatedButtonTheme.style?.copyWith(
                          padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 15, horizontal: 40))
                        ),
                        onPressed: _submit,
                        child: const Text('Register'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
