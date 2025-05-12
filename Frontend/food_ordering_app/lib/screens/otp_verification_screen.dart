import 'package:flutter/material.dart';
// Purpose: Provides the UI for entering and verifying the OTP code.

import 'dart:async'; // <<< Import Timer
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/token_provider.dart';
import 'home_screen.dart';
import 'signup_screen.dart';
import '../utils/auth_storage.dart';
import '../utils/globals.dart' as globals;
import 'package:shared_preferences/shared_preferences.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber; // Pass the phone number from the previous screen

  const OtpVerificationScreen({Key? key, required this.phoneNumber}) : super(key: key);

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  // Timer state variables
  Timer? _timer;
  int _startSeconds = 300; // Set to 300 seconds (5 minutes) to match backend
  int _currentSeconds = 0;
  bool _canResend = false;
  DateTime? _otpRequestTime; // Track when OTP was requested

  @override
  void initState() {
    super.initState();
    _otpRequestTime = DateTime.now(); // Record when OTP was requested
    startTimer(); // Start the timer when the screen loads
    _checkExistingLogin(); // Check if already logged in
  }

  Future<void> _checkExistingLogin() async {
    debugPrint('============ OTP SCREEN INIT ============');
    debugPrint('Checking for existing login...');
    
    // Check global customer ID
    debugPrint('Global customer ID: ${globals.globalCustomerId}');
    
    // Check SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final storedCustomerId = prefs.getString('customer_id');
    debugPrint('Stored customer ID in preferences: $storedCustomerId');
    
    // Check auth token
    try {
      final token = await AuthStorage.getToken();
      debugPrint('Existing auth token: ${token != null ? "exists" : "not found"}');
    } catch (e) {
      debugPrint('Error checking auth token: $e');
    }
    
    debugPrint('Phone number from previous screen: ${widget.phoneNumber}');
    debugPrint('=======================================');
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel timer when screen is disposed
    _otpController.dispose();
    super.dispose();
  }

  void startTimer() {
    _currentSeconds = _startSeconds;
    _canResend = false; // Disable resend initially
    _otpRequestTime = DateTime.now(); // Record when OTP was requested
    debugPrint('OTP Timer started at: $_otpRequestTime');
    
    _timer?.cancel(); // Cancel any existing timer
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (Timer timer) {
        if (_currentSeconds == 0) {
          setState(() {
            timer.cancel();
            _canResend = true; // Enable resend
            debugPrint('OTP Timer expired at: ${DateTime.now()}');
            debugPrint('Total time elapsed: ${DateTime.now().difference(_otpRequestTime!).inSeconds} seconds');
          });
        } else {
          setState(() {
            _currentSeconds--;
            if (_currentSeconds % 10 == 0) { // Log every 10 seconds
              debugPrint('OTP Timer: $_currentSeconds seconds remaining');
            }
          });
        }
      },
    );
  }

  Future<void> _resendOtp() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('Resend OTP requested for ${widget.phoneNumber}');
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.sendOtp(widget.phoneNumber);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New OTP sent successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        startTimer(); // Restart the timer
        _otpController.clear(); // Clear the previous OTP
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send OTP. Please try again later.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) {
      setState(() {
        _error = 'Please enter a valid 6-digit OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('Verifying OTP after ${DateTime.now().difference(_otpRequestTime!).inSeconds} seconds');
      final resultData = await Provider.of<AuthProvider>(context, listen: false)
          .verifyOtp(widget.phoneNumber, _otpController.text);
      
      debugPrint('(OtpVerificationScreen) Received resultData from provider: $resultData');

      if (resultData != null) {
        if (resultData['status'] == 'SIGNUP_REQUIRED') {
          // Navigate to signup screen with the verified phone number
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SignupScreen(phoneNumber: widget.phoneNumber),
            ),
          );
          return;
        }

        final authToken = resultData['auth_token'];
        final refreshToken = resultData['refresh_token'];
        debugPrint('(OtpVerificationScreen) Extracted auth_token: $authToken, refresh_token: $refreshToken');

        if (authToken != null) {
          // Save tokens to persistent storage
          await AuthStorage.saveToken(authToken);
          if (refreshToken != null) {
            await AuthStorage.saveRefreshToken(refreshToken);
          }
          if (resultData['customer_id'] != null) {
            await AuthStorage.saveCustomerId(resultData['customer_id']!);
          }

          // Update in-memory TokenProvider
          Provider.of<TokenProvider>(context, listen: false).setTokens(
            accessToken: authToken,
            refreshToken: refreshToken ?? '',
          );

          // Verify the token was saved correctly
          final savedToken = await AuthStorage.getToken();
          debugPrint('(OtpVerificationScreen) Verifying save - token in storage: $savedToken');

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } else {
          setState(() {
            _error = 'Authentication failed. Please try again.';
          });
        }
      } else {
        setState(() {
          _error = 'Invalid OTP. Please try again.';
        });
      }
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      setState(() {
        _error = 'An error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Phone Number'),
        backgroundColor: Colors.orange.shade700,
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
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     Icon(Icons.phonelink_lock_outlined, size: 50, color: Colors.orange.shade700),
                     const SizedBox(height: 15),
                     Text(
                      'Enter Verification Code',
                       style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Enter the 6-digit code sent to\n${widget.phoneNumber}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                     ),
                    const SizedBox(height: 5),
                    Text(
                      'OTP expires in 5 minutes',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6, 
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, letterSpacing: 12, fontWeight: FontWeight.bold), // Enhanced style
                      decoration: InputDecoration(
                        // labelText: 'Enter OTP', // Removed label for cleaner look
                        hintText: '------', 
                        hintStyle: TextStyle(letterSpacing: 12, color: Colors.grey.shade300, fontSize: 24),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.orange.shade700, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        counterText: "", 
                      ),
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
                            onPressed: _verifyOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 4,
                            ),
                            child: const Text('Verify OTP', style: TextStyle(fontSize: 16)),
                          ),
                    const SizedBox(height: 20),
                    // Resend OTP Button/Text
                    TextButton(
                      onPressed: _canResend ? _resendOtp : null,
                      child: Text(
                        _canResend
                            ? 'Resend OTP'
                            : 'Resend OTP in ${_currentSeconds ~/ 60}:${(_currentSeconds % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: _canResend ? Colors.orange.shade700 : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
