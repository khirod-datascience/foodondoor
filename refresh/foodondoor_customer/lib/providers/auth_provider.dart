import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../utils/auth_storage.dart';

class AuthProvider extends ChangeNotifier {
  final Dio _dio = Dio();

  String? _customerId;
  String? get customerId => _customerId;
  String? _token;
  String? get token => _token;
  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? _currentAddress;
  Map<String, dynamic>? get currentAddress => _currentAddress;

  AuthProvider() {
    _loadAuthState();
  }

  Future<void> _loadAuthState() async {
    _token = await AuthStorage.getToken();
    _customerId = await AuthStorage.getCustomerId();
    _isAuthenticated = _token != null && _customerId != null;
    notifyListeners();
  }

  Future<bool> sendOtp(String phoneNumber) async {
    try {
      final response = await _dio.post(
        '${AppConfig.baseUrl}/send-otp/',
        data: {'phone': phoneNumber},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, String?>?> verifyOtp(String phoneNumber, String otp) async {
    try {
      final response = await _dio.post(
        '${AppConfig.baseUrl}/verify-otp/',
        data: {'phone': phoneNumber, 'otp': otp},
      );
      if (response.statusCode != 200) return null;
      final data = response.data as Map<String, dynamic>;
      final customerId = data['customer_id']?.toString();
      String? token;
      for (final key in ['auth_token', 'token', 'access_token', 'jwt', 'authentication_token', 'id_token']) {
        if (data.containsKey(key) && data[key] != null) {
          token = data[key].toString();
          break;
        }
      }
      if (token != null && customerId != null) {
        await AuthStorage.saveToken(token);
        await AuthStorage.saveCustomerId(customerId);
        _token = token;
        _customerId = customerId;
        _isAuthenticated = true;
        notifyListeners();
        return {'customer_id': customerId, 'auth_token': token};
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  void setCurrentAddress(Map<String, dynamic> address) {
    _currentAddress = address;
    notifyListeners();
  }

  Future<void> logout() async {
    await AuthStorage.deleteToken();
    await AuthStorage.deleteCustomerId();
    _token = null;
    _customerId = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}