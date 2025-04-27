import 'package:flutter/material.dart';
import 'package:foodondoor_delivery/mainScreens/home_screen.dart';
import 'package:foodondoor_delivery/services/api_service.dart';
import 'package:foodondoor_delivery/widgets/progress_bar.dart';
import 'package:foodondoor_delivery/widgets/error_Dialog.dart';

class RegistrationScreen extends StatefulWidget {
  final String phoneNumber; // Receive phone number from OtpScreen

  const RegistrationScreen({super.key, required this.phoneNumber});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  // Add controllers for any other required fields (e.g., vehicle details?)
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return; // Don't proceed if form is invalid
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Prepare data for registration
    Map<String, dynamic> registrationData = {
      'phone_number': widget.phoneNumber, // Crucial: Include the verified phone number
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim().toLowerCase(),
      // Add other fields as required by your backend serializer
    };

    try {
      final result = await _apiService.registerRider(registrationData);

      if (result['success'] == true) {
        // Registration successful, navigate to home
        // Token is already stored by ApiService
         Navigator.pushAndRemoveUntil(
           context,
           MaterialPageRoute(builder: (context) => const HomeScreen()),
           (route) => false, // Remove all previous routes
         );
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Registration failed.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Registration'),
        automaticallyImplyLeading: false, // No back button, must complete
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Welcome! Please provide a few details to get started.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // Name Input
              TextFormField(
                controller: _nameController,
                keyboardType: TextInputType.name,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
                enabled: !_isLoading,
              ),

              const SizedBox(height: 20),

              // Email Input
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  // Basic email validation
                  if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
                enabled: !_isLoading,
              ),

              // Add other required fields here (e.g., Vehicle Type dropdown)

              const SizedBox(height: 30),

              // Loading Indicator
              if (_isLoading)
                Center(child: circularProgress()),

              // Error Message
              if (_errorMessage != null && !_isLoading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Register Button
              if (!_isLoading)
                ElevatedButton(
                  onPressed: _register,
                  child: const Text('Register & Login'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
