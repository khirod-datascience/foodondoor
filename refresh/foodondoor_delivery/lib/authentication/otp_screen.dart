import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatters
import 'package:foodondoor_delivery/mainScreens/home_screen.dart';
import 'package:foodondoor_delivery/services/api_service.dart';
import 'package:foodondoor_delivery/widgets/progress_bar.dart'; // Assuming you have this
import 'package:foodondoor_delivery/widgets/error_Dialog.dart'; // Corrected import path casing
import 'registration_screen.dart'; // Import registration screen
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _apiService = ApiService();

  bool _isLoading = false;
  bool _isOtpSent = false;
  String? _errorMessage;
  String _phoneNumber = ''; // Store the number used to request OTP

  // Function to request OTP
  Future<void> _requestOtp() async {
    if (_phoneController.text.isEmpty || _phoneController.text.length < 10) {
      setState(() {
        _errorMessage = 'Please enter a valid 10-digit phone number.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _phoneNumber = _phoneController.text; // Store the number
    });

    try {
      final result = await _apiService.requestOtp(_phoneNumber);
      if (result['success'] == true) {
        setState(() {
          _isOtpSent = true;
          _errorMessage = null; // Clear previous errors
        });
        // Optionally show a success message (e.g., using a snackbar)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP sent successfully!'), backgroundColor: Colors.green),
        );
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to send OTP.';
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

  // Function to verify OTP
  Future<void> _verifyOtp() async {
    if (_otpController.text.isEmpty || _otpController.text.length < 4) { // Assuming OTP length
      setState(() {
        _errorMessage = 'Please enter a valid OTP.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _apiService.verifyOtp(_phoneNumber, _otpController.text);

      if (result['success'] == true) {
        if (result['is_new_user'] == true) {
          // Navigate to Registration Screen, passing the phone number
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => RegistrationScreen(phoneNumber: _phoneNumber)),
          );
        } else {
          // Existing user, navigate to home
          print("Existing user detected. Navigating to Home Screen.");
          // Save user data to SharedPreferences before navigating
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('uid', result['user']['id']);
          await prefs.setString('name', result['user']['name'] ?? ''); // Handle potential null name
          await prefs.setString('email', result['user']['email'] ?? ''); // Handle potential null email
          await prefs.setString('photoUrl', result['user']['profile_picture_url'] ?? ''); // Handle null photoUrl
          // Assume phone number is already stored if needed, or store it:
          // await prefs.setString('phone', _phoneNumber);

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false, // Remove all previous routes
          );
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'OTP verification failed.';
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
        title: Text(_isOtpSent ? 'Verify OTP' : 'Login / Register'),
        automaticallyImplyLeading: _isOtpSent, // Show back button only on OTP verification step
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Placeholder for Logo
            // Image.asset('assets/images/logo.png', height: 100),
            const SizedBox(height: 40),

            // Phone Number Input
            if (!_isOtpSent)
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10, // Assuming 10-digit numbers
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixText: '+91 ',
                  counterText: "", // Hide the counter
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                enabled: !_isLoading,
              ),

            // OTP Input
            if (_isOtpSent)
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6, // Assuming 6-digit OTP
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Enter OTP',
                  counterText: "",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                enabled: !_isLoading,
              ),

            const SizedBox(height: 20),

            // Loading Indicator
            if (_isLoading)
              Center(child: circularProgress()), // Use your progress bar widget

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

            // Buttons
            if (!_isLoading)
              _isOtpSent
                  ? ElevatedButton(
                      onPressed: _verifyOtp,
                      child: const Text('Verify & Login'),
                    )
                  : ElevatedButton(
                      onPressed: _requestOtp,
                      child: const Text('Send OTP'),
                    ),

            // Option to change number if OTP is sent
            if (_isOtpSent && !_isLoading)
              TextButton(
                onPressed: () {
                  setState(() {
                    _isOtpSent = false;
                    _otpController.clear();
                    _errorMessage = null;
                  });
                },
                child: const Text('Change Phone Number?'),
              ),
          ],
        ),
      ),
    );
  }
}
