import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foodondoor_restaurant/utils/globals.dart';

class AuthService extends ChangeNotifier {
  String? _vendorId;
  String? _authToken;

  String? get vendorId => _vendorId;
  String? get authToken => _authToken;

  AuthService() {
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    try {
      await Globals.initialize();
      _vendorId = Globals.vendorId;
      _authToken = Globals.authToken;
      debugPrint('(AuthService) Loaded credentials: Vendor ID: ${_vendorId}');
      notifyListeners();
    } catch (e) {
      debugPrint('(AuthService) Error loading credentials: $e');
    }
  }

  Future<void> login(String vendorId, String authToken) async {
    try {
      await Globals.saveVendorCredentials(vendorId, authToken);
      _vendorId = vendorId;
      _authToken = authToken;
      debugPrint('(AuthService) Login: Saved vendorId and token.');
      notifyListeners();
    } catch (e) {
      debugPrint('(AuthService) Error during login: $e');
    }
  }

  Future<void> logout() async {
    try {
      await Globals.clearVendorCredentials();
      _vendorId = null;
      _authToken = null;
      debugPrint('(AuthService) Logout: Cleared credentials.');
      notifyListeners();
    } catch (e) {
      debugPrint('(AuthService) Error during logout: $e');
    }
  }
}