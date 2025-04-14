import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../globals.dart';

class AuthService extends ChangeNotifier {
  String? _currentUser;

  String? get currentUser => _currentUser;

  AuthService() {
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUser = prefs.getString('vendorId');
    notifyListeners();
  }

  Future<void> login(String vendorId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vendorId', vendorId);
    _currentUser = vendorId;
    Globals.vendorId = vendorId;
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('vendorId');
    _currentUser = null;
    Globals.vendorId = null;
    notifyListeners();
  }
} 