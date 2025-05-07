import 'package:flutter/material.dart';
import 'package:foodondoor_vendor_app/src/features/auth/services/auth_service.dart';
import 'package:foodondoor_vendor_app/src/utils/secure_storage_service.dart';

enum AuthStatus {
  initial,
  unauthenticated,
  authenticating,
  awaitingOtp,
  otpVerificationFailed,
  needsProfileSetup,
  registering,
  registrationFailed,
  authenticated
}

class AuthProvider with ChangeNotifier {
  final AuthService _authService;

  AuthStatus _status = AuthStatus.initial;
  String? _phoneNumber;
  String? _errorMessage;

  AuthProvider(this._authService) { 
    _checkAuthStatus();
  }

  AuthStatus get status => _status;
  String? get phoneNumber => _phoneNumber;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  void _setStatus(AuthStatus newStatus) {
    _status = newStatus;
    notifyListeners();
  }

  Future<void> _checkAuthStatus() async {
    _setStatus(AuthStatus.authenticating);
    String? token = await _authService.getAccessToken();
    if (token != null && token.isNotEmpty) {
      _setStatus(AuthStatus.authenticated);
    } else {
      _setStatus(AuthStatus.unauthenticated);
    }
  }

  Future<bool> sendOtp(String phoneNumber) async {
    _errorMessage = null; 
    print("[AuthProvider] sendOtp called for $phoneNumber");
    _status = AuthStatus.authenticating;
    _phoneNumber = null; 
    notifyListeners();

    final success = await _authService.sendOtp(phoneNumber);
    if (success) {
      _phoneNumber = phoneNumber; 
      _status = AuthStatus.awaitingOtp; 
      print("[AuthProvider] sendOtp successful, awaiting OTP for $_phoneNumber");
      notifyListeners();
      return true;
    } else {
      _status = AuthStatus.unauthenticated; 
      _errorMessage = 'Failed to send OTP. Please try again.';
      print("[AuthProvider] sendOtp failed");
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp(String phoneNumber, String otpCode) async {
    _errorMessage = null; 
    print("[AuthProvider] verifyOtp called for $phoneNumber with OTP $otpCode");
    if (_status != AuthStatus.awaitingOtp) {
      print("[AuthProvider] verifyOtp called in incorrect state: $_status");
      _errorMessage = 'Please request an OTP first.';
      return false;
    }

    _status = AuthStatus.authenticating;
    notifyListeners();

    final result = await _authService.verifyOtp(phoneNumber, otpCode);

    switch (result['type']) {
      case 'login':
        _status = AuthStatus.authenticated;
        _errorMessage = null;
        _phoneNumber = null; 
        print("[AuthProvider] verifyOtp resulted in LOGIN");
        notifyListeners();
        return true;
      case 'signup':
        _status = AuthStatus.needsProfileSetup;
        _errorMessage = null;
        _phoneNumber = null; 
        print("[AuthProvider] verifyOtp resulted in SIGNUP (needs profile)");
        notifyListeners();
        return true;
      case 'error':
      default:
        _status = AuthStatus.awaitingOtp; 
        _errorMessage = result['message'] ?? 'OTP verification failed.';
        print("[AuthProvider] verifyOtp resulted in ERROR: $_errorMessage");
        notifyListeners();
        return false;
    }
  }

  Future<bool> completeRegistration(Map<String, dynamic> profileData) async {
    _errorMessage = null; 
    print("[AuthProvider] completeRegistration called with data: $profileData");
    if (_status != AuthStatus.needsProfileSetup) {
      print("[AuthProvider] completeRegistration called in incorrect state: $_status");
      _errorMessage = "Cannot complete registration at this time.";
      _setStatus(AuthStatus.registrationFailed); 
      notifyListeners();
      return false;
    }

    _status = AuthStatus.authenticating; 
    notifyListeners();

    final success = await _authService.registerVendor(profileData);

    if (success) {
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      _phoneNumber = null; 
      print("[AuthProvider] completeRegistration successful, now authenticated.");
      notifyListeners();
      return true;
    } else {
      _status = AuthStatus.needsProfileSetup; 
      _errorMessage = 'Failed to complete registration. Please check details and try again.';
      _phoneNumber = null; 
      print("[AuthProvider] completeRegistration failed.");
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.clearTokens();
    _phoneNumber = null;
    _setStatus(AuthStatus.unauthenticated);
  }
}
