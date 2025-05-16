import 'package:flutter/material.dart';
// Purpose: Provides the UI for new user registration after OTP verification.

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import '../config.dart';
import '../utils/auth_storage.dart';
import '../utils/globals.dart' as globals;
import 'dart:convert';
import 'package:http/http.dart' as http;

class SignupScreen extends StatefulWidget {
  final String phoneNumber; // Pass the phone number from the previous screen

  const SignupScreen({Key? key, required this.phoneNumber}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _signup() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        debugPrint('(SignupScreen) Sending signup request with phone: ${widget.phoneNumber}');
        final response = await http.post(
          Uri.parse('${AppConfig.baseUrl}/signup/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'phone': widget.phoneNumber,
            'name': _nameController.text,
            'email': _emailController.text,
          }),
        );

        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('(SignupScreen) Received responseData from API: $responseData');

        if (response.statusCode == 200 || response.statusCode == 201) {
          final authToken = responseData['auth_token'] as String?;
          debugPrint('(SignupScreen) Extracted auth_token from responseData: $authToken');

          if (authToken != null) {
            await AuthStorage.saveAuthToken(authToken);
            final customerId = responseData['customer_id'] as String?;
            if (customerId != null) {
              await AuthStorage.saveCustomerId(customerId);
            }
            // Save phone and email for silent login
            await AuthStorage.savePhone(widget.phoneNumber);
            await AuthStorage.saveEmail(_emailController.text);
            
            // Verify the token was saved correctly
            final savedToken = await AuthStorage.getAuthToken();
            debugPrint('(SignupScreen) Verified saved token: $savedToken');
            
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            }
          } else {
            setState(() {
              _error = 'Authentication failed. Please try again.';
            });
          }
        } else {
          setState(() {
            _error = responseData['error']?.toString() ?? 'Signup failed. Please try again.';
          });
        }
      } catch (e) {
        setState(() {
          _error = e.toString();
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'), 
        backgroundColor: Colors.orange.shade700, // Match theme
        foregroundColor: Colors.white, 
        elevation: 0,
      ),
      // Add gradient background matching LoginScreen
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade200, Colors.orange.shade500],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30.0),
            child: Form(
              key: _formKey,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Almost there!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 10),
                       Text(
                        'Complete your profile details',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                       ),
                       const SizedBox(height: 30),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline, color: Colors.orange.shade700),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                           filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined, color: Colors.orange.shade700),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                           filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 25),
                      _isLoading
                          ? CircularProgressIndicator(color: Colors.orange.shade700)
                          : ElevatedButton(
                              onPressed: _signup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 4,
                              ),
                              child: const Text('Sign Up', style: TextStyle(fontSize: 16)),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
