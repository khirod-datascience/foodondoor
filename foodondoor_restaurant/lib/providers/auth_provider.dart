import 'dart:async'; // Import async
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../services/simple_notification_service.dart';
import '../utils/globals.dart' as globals; // Import globals

class AuthProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _token;
  String? _vendorId;
  String? _errorMessage;
  // Completer to signal when auto-login attempt is done
  final Completer<void> _initCompleter = Completer<void>();

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null && _vendorId != null;
  String? get token => _token;
  String? get vendorId => _vendorId;
  String? get errorMessage => _errorMessage;
  // Public future to wait for initialization
  Future<void> get isInitializationComplete => _initCompleter.future;

  AuthProvider() {
    _tryAutoLogin();
  }

  Future<bool> _tryAutoLogin() async {
    // Don't set _isLoading here, let splash handle visuals
    // notifyListeners();
    bool loggedIn = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('auth_token');
      final savedVendorId = prefs.getString('vendor_id');
      debugPrint('(AuthProvider) Trying auto-login. Token: ${savedToken != null}, VendorID: $savedVendorId');

      if (savedToken != null && savedVendorId != null) {
        _token = savedToken;
        _vendorId = savedVendorId;
        globals.globalToken = savedToken; // Update global token
        globals.globalVendorId = savedVendorId; // Update global vendor ID
        loggedIn = true;
        // No need to notifyListeners here, main waits for completer
      }
    } catch (e) {
      print('Error auto-logging in: $e');
    } finally {
       // Signal that initialization attempt is complete regardless of success
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
       debugPrint('(AuthProvider) Auto-login attempt finished. Logged in: $loggedIn');
    }

    // We don't need loading state or notifyListeners here for auto-login
    // _isLoading = false;
    // notifyListeners();
    return loggedIn;
  }

  // Send OTP to vendor phone number
  Future<bool> sendOtp(String phone) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/auth/vendor/send-otp/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );
      
      final responseData = jsonDecode(response.body);
      
      _isLoading = false;
      // Keep listeners notified about loading state change
      notifyListeners(); 
      
      if (response.statusCode == 200) {
        print('OTP sent successfully to $phone');
        return true;
      } else {
        _errorMessage = responseData['message'] ?? 'Failed to send OTP';
        // No need to notifyListeners again for error, already done
        return false;
      }
    } catch (e) {
      _errorMessage = 'An error occurred: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Verify OTP and login vendor
  Future<bool> verifyOtp(String phone, String otp) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/auth/vendor/verify-otp/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'otp': otp,
        }),
      );
      
      final responseData = jsonDecode(response.body);
      debugPrint('(AuthProvider.verifyOtp) API Response: $responseData'); // Log API response
      
      if (response.statusCode == 200) {
        _token = responseData['token'];
        _vendorId = responseData['vendor_id'];
        
        debugPrint('(AuthProvider.verifyOtp) Login success. Got VendorID: $_vendorId, Token: ${_token != null}');
        
        // *** Crucial: Save credentials ***
        debugPrint('(AuthProvider.verifyOtp) Attempting to save credentials...');
        await globals.Globals.saveVendorCredentials(_vendorId!, _token!); 
        debugPrint('(AuthProvider.verifyOtp) Credentials save call finished.');
        
        // Re-initialize notifications on successful login
        // DO NOT await here, let it initialize in background
        debugPrint('(AuthProvider.verifyOtp) Initializing notification service...');
        SimpleNotificationService.instance.initialize(); 
        debugPrint('(AuthProvider.verifyOtp) Notification service initialization started.');
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = responseData['message'] ?? 'OTP verification failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'An error occurred: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Clear device token on server
      await SimpleNotificationService.instance.clearDeviceToken();
      
      // *** Crucial: Clear credentials ***
      await globals.Globals.clearVendorCredentials();
      
      _token = null;
      _vendorId = null;
    } catch (e) {
      print('Error logging out: $e');
    } finally {
       _isLoading = false;
       notifyListeners(); // Ensure listeners are notified even on error
    }
  }
  
  // Clear any error messages
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}