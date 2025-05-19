import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import '../services/auth_service.dart';
import '../models/delivery_user.dart';

enum AuthStatus { unknown, unauthenticated, authenticating, otpSent, authenticated, needsSignup }

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  AuthStatus _status = AuthStatus.unknown;
  DeliveryUser? _currentUser;
  String? _errorMessage;
  String? _pendingPhoneNumber;

  AuthStatus get status => _status;
  DeliveryUser? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get pendingPhoneNumber => _pendingPhoneNumber;

  AuthProvider() {
    debugPrint("[AuthProvider] Initializing...");
    _initialize();
  }

  Future<void> _initialize() async {
    debugPrint("[AuthProvider] _initialize called.");
    await tryAutoLogin();
    debugPrint("[AuthProvider] _initialize finished.");
  }

  Future<bool> tryAutoLogin() async {
    debugPrint("[AuthProvider] tryAutoLogin started.");
    _status = AuthStatus.authenticating;
    notifyListeners();

    final accessToken = await _authService.getAccessToken();
    final refreshToken = await _authService.getRefreshToken();
    debugPrint("[AuthProvider] Tokens - Access: ${accessToken != null}, Refresh: ${refreshToken != null}");

    if (accessToken != null && refreshToken != null) {
      debugPrint("[AuthProvider] Tokens found, assuming authenticated (placeholder).");
      // TODO: Validate token and fetch user data
      _status = AuthStatus.authenticated;
    } else {
      debugPrint("[AuthProvider] No tokens found, setting unauthenticated.");
      _status = AuthStatus.unauthenticated;
    }
    debugPrint("[AuthProvider] tryAutoLogin finished. Final status: $_status");
    notifyListeners();
    return isAuthenticated;
  }

  Future<void> sendOtp(String phoneNumber) async {
    _errorMessage = null;
    // Set status internally but don't notify yet
    _status = AuthStatus.authenticating;
    debugPrint("[AuthProvider] sendOtp: Set status internally to authenticating (no notify yet)");

    debugPrint("[AuthProvider] sendOtp: Calling _authService.sendOtp for $phoneNumber");
    final result = await _authService.sendOtp(phoneNumber);
    debugPrint("[AuthProvider] sendOtp: API call finished. Success: ${result['success']}");

    if (result['success']) {
      _pendingPhoneNumber = phoneNumber;
      _status = AuthStatus.otpSent; // <-- Set final status to otpSent
      debugPrint("[AuthProvider] sendOtp: SUCCESS - Set final status to otpSent.");
    } else {
      _errorMessage = result['message'] ?? 'Failed to send OTP';
      _status = AuthStatus.unauthenticated;
      debugPrint("[AuthProvider] sendOtp: FAILED - Set final status to unauthenticated. Error: $_errorMessage");
    }
    debugPrint("[AuthProvider] sendOtp: Notifying listeners ONCE with final status: $_status");
    notifyListeners(); // <-- Notify ONCE
    debugPrint("[AuthProvider] sendOtp: DONE.");
  }

  Future<void> verifyOtp(String otp) async {
    if (_pendingPhoneNumber == null) {
      _errorMessage = "Phone number not set for verification";
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    _errorMessage = null;
    _status = AuthStatus.authenticating; // Show loading for verification
    debugPrint("[AuthProvider] verifyOtp: Set status to authenticating, notifying...");
    notifyListeners();

    debugPrint("[AuthProvider] verifyOtp: Calling _authService.verifyOtp for $_pendingPhoneNumber");
    final result = await _authService.verifyOtp(_pendingPhoneNumber!, otp);
    debugPrint("[AuthProvider] verifyOtp: API call finished. Success: ${result['success']}");

    if (result['success']) {
      final isNewUser = result['is_new_user'] as bool? ?? false;
      if (isNewUser) {
        _status = AuthStatus.needsSignup;
        debugPrint("[AuthProvider] verifyOtp: SUCCESS (New User) - Set status to needsSignup.");
      } else {
        if (result['user'] != null) {
           _currentUser = DeliveryUser.fromJson(result['user']);
           _status = AuthStatus.authenticated;
           debugPrint("[AuthProvider] verifyOtp: SUCCESS (Existing User) - Set status to authenticated.");
        } else {
             _errorMessage = "User data not found after verification.";
             _status = AuthStatus.unauthenticated;
             debugPrint("[AuthProvider] verifyOtp: FAILED (Missing User Data) - Set status to unauthenticated.");
             await _authService.clearTokens();
        }
        _pendingPhoneNumber = null;
      }
    } else {
      _errorMessage = result['message'] ?? 'OTP verification failed';
      _status = AuthStatus.unauthenticated; // Stay unauthenticated on failure
       debugPrint("[AuthProvider] verifyOtp: FAILED - Set status to unauthenticated. Error: $_errorMessage");
    }
    debugPrint("[AuthProvider] verifyOtp: Notifying listeners with final status: $_status");
    notifyListeners();
    debugPrint("[AuthProvider] verifyOtp: DONE.");
  }

  Future<void> register(String name, String? email) async {
     if (_pendingPhoneNumber == null) {
      _errorMessage = "Cannot register without a verified phone number";
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    _errorMessage = null;
    _status = AuthStatus.authenticating; // Show loading for registration
    debugPrint("[AuthProvider] register: Set status to authenticating, notifying...");
    notifyListeners();

    debugPrint("[AuthProvider] register: Calling _authService.register for $_pendingPhoneNumber");
    final result = await _authService.register(
      name: name,
      phoneNumber: _pendingPhoneNumber!,
      email: email,
    );
     debugPrint("[AuthProvider] register: API call finished. Success: ${result['success']}");

    if (result['success']) {
      if (result['user'] != null) {
         _currentUser = DeliveryUser.fromJson(result['user']);
         _status = AuthStatus.authenticated;
         _pendingPhoneNumber = null;
         debugPrint("[AuthProvider] register: SUCCESS - Set status to authenticated.");
      } else {
          _errorMessage = "User data not found after registration.";
          _status = AuthStatus.unauthenticated;
          debugPrint("[AuthProvider] register: FAILED (Missing User Data) - Set status to unauthenticated.");
          await _authService.clearTokens();
      }
    } else {
      _errorMessage = result['message'] ?? 'Registration failed';
      _status = AuthStatus.needsSignup; // Stay on signup screen on failure
      debugPrint("[AuthProvider] register: FAILED - Set status to needsSignup. Error: $_errorMessage");
    }
    debugPrint("[AuthProvider] register: Notifying listeners with final status: $_status");
    notifyListeners();
    debugPrint("[AuthProvider] register: DONE.");
  }

  Future<void> logout() async {
    debugPrint("[AuthProvider] logout: Clearing tokens and resetting state.");
    await _authService.clearTokens();
    _currentUser = null;
    _pendingPhoneNumber = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
