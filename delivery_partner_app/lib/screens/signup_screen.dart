import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
// Import screens for navigation (although AuthWrapper handles it)
import 'home_screen.dart';

class SignupScreen extends StatefulWidget {
  final String phoneNumber;
  const SignupScreen({super.key, required this.phoneNumber});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController(); // Optional
  final _formKey = GlobalKey<FormState>();
  // bool _isLoading = false; // Managed by AuthProvider

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _registerUser(AuthProvider authProvider) async {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text;
      final email = _emailController.text.trim(); // Trim whitespace

      await authProvider.register(
          name,
          email.isEmpty ? null : email, // Pass null if email is empty
      );

      // Navigation is handled by AuthWrapper based on provider status changes
      // Show success/error message here
      if (mounted) {
          if (authProvider.status == AuthStatus.authenticated) {
              ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Registration Successful!'), backgroundColor: Colors.green),
               );
              // Navigation to HomeScreen happens via AuthWrapper
          } else if (authProvider.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text(authProvider.errorMessage!), backgroundColor: Colors.red),
              );
          }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Registration')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView( // Use SingleChildScrollView for smaller screens
             child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.person_add_alt_1, size: 80, color: Colors.orange), // Added icon
                const SizedBox(height: 20),
                Text('Verified Phone: ${widget.phoneNumber}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                   textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email (Optional)',
                    border: OutlineInputBorder(),
                     prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                     // Optional: Basic email format validation
                     if (value != null && value.isNotEmpty && !value.contains('@')) {
                       return 'Please enter a valid email address';
                     }
                     return null;
                   },
                ),
                const SizedBox(height: 30),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    if (authProvider.status == AuthStatus.authenticating) {
                      return const CircularProgressIndicator();
                    } else {
                      return ElevatedButton(
                        onPressed: () => _registerUser(authProvider),
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15)),
                        child: const Text('Register'),
                      );
                    }
                  },
                ),
                // Display error messages
                Consumer<AuthProvider>(
                   builder: (context, authProvider, child) {
                      if (authProvider.status != AuthStatus.authenticating &&
                          authProvider.errorMessage != null) {
                         return Padding(
                           padding: const EdgeInsets.only(top: 15.0),
                           child: Text(
                             authProvider.errorMessage!,
                             style: const TextStyle(color: Colors.red),
                             textAlign: TextAlign.center,
                           ),
                         );
                      }
                      return const SizedBox.shrink();
                   }
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
