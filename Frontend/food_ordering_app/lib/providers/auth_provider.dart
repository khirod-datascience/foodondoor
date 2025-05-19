import 'package:flutter/material.dart';
// Purpose: Handles user authentication state and OTP verification logic.

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../utils/globals.dart';
import '../utils/auth_storage.dart';
import 'package:provider/provider.dart';
import 'token_provider.dart';

class AuthProvider extends ChangeNotifier {
  final Dio _dio = Dio();

  Future<bool> sendOtp(String phoneNumber) async {
    try {
      debugPrint('Sending OTP request...');
      debugPrint('Phone Number: $phoneNumber');
      debugPrint('API Endpoint: ${AppConfig.baseUrl}/send-otp/');

      final response = await _dio.post(
        '${AppConfig.baseUrl}/send-otp/',
        data: {'phone': phoneNumber}, // Updated key to 'phone'
      );

      debugPrint('Response Status Code: ${response.statusCode}');
      debugPrint('Response Data: ${response.data}');

      return true;
    } catch (e) {
      debugPrint('Error sending OTP: $e');
      if (e is DioException) {
        debugPrint('DioException Details:');
        debugPrint('Request Data: ${e.requestOptions.data}');
        debugPrint('Response Data: ${e.response?.data}');
        debugPrint('Response Status Code: ${e.response?.statusCode}');
      }
      return false;
    }
  }

  Future<Map<String, String?>?> verifyOtp(String phoneNumber, String otp) async {
    try {
      debugPrint('==== OTP VERIFICATION API CALL ====');
      debugPrint('Verifying OTP...');
      debugPrint('Phone Number: $phoneNumber');
      debugPrint('OTP: $otp');
      debugPrint('API Endpoint: ${AppConfig.baseUrl}/verify-otp/');

      final response = await _dio.post(
        '${AppConfig.baseUrl}/verify-otp/',
        data: {'phone': phoneNumber, 'otp': otp}, // Fixed order of parameters
      );

      debugPrint('Response Status Code: ${response.statusCode}');
      debugPrint('Response Data: ${response.data}');

      if (response.statusCode != 200) {
        debugPrint('OTP verification failed with status: ${response.statusCode}');
        return null;
      }

      if (response.data is! Map) {
        debugPrint('Unexpected response format: ${response.data.runtimeType}');
        return null;
      }

      final responseData = response.data as Map<String, dynamic>;
      debugPrint('Response Keys: ${responseData.keys.toList()}');
      
      // Debug output for all auth-related fields
      for (final key in responseData.keys) {
        if (key.contains('token') || key.contains('auth') || key.contains('customer')) {
          debugPrint('Auth-related key: $key = ${responseData[key]}');
        }
      }
      
      // Extract refresh token if present
      String? refreshToken;
      final possibleRefreshKeys = ['refresh_token', 'refresh'];
      for (final key in possibleRefreshKeys) {
        if (responseData.containsKey(key) && responseData[key] != null) {
          refreshToken = responseData[key].toString();
          debugPrint('Found refresh token in response with key: $key');
          break;
        }
      }
      
      if (responseData['is_signup'] == true) {
        debugPrint('OTP verification succeeded - signup required');
        return {'status': 'SIGNUP_REQUIRED'}; 
      }

      final customerId = responseData['customer_id']?.toString();
      if (customerId == null) {
        debugPrint('OTP verified but customer_id missing in response');
        return null;
      }

      // Look for token with different possible keys
      String? token;
      final possibleTokenKeys = ['auth_token', 'token', 'access_token', 'jwt', 'authentication_token', 'id_token'];
      
      for (final key in possibleTokenKeys) {
        if (responseData.containsKey(key) && responseData[key] != null) {
          token = responseData[key].toString();
          debugPrint('Found token in response with key: $key');
          break;
        }
      }

      if (token == null) {
        debugPrint('No valid token found in response');
        return null;
      }

      // Save token and customer ID immediately
      await AuthStorage.saveAccessToken(token);
      debugPrint('Attempting to save refresh token: $refreshToken');
      if (refreshToken != null) {
        await AuthStorage.saveRefreshToken(refreshToken);
        debugPrint('Refresh token saved via AuthStorage.saveRefreshToken');
      } else {
        debugPrint('No refresh token to save!');
        debugPrint('RESPONSE DATA:');
        debugPrint(responseData.toString());
      }

      globalCustomerId = customerId;

      final dataToReturn = {
        'customer_id': customerId,
        'auth_token': token,
        'refresh_token': refreshToken, // Always include refresh token if present
      };
      debugPrint('(AuthProvider) Returning from verifyOtp: $dataToReturn'); 
      debugPrint('Auth token length: ${token.length}');
      debugPrint('================================');
      return dataToReturn;

    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      if (e is DioException) {
        debugPrint('DioException Details:');
        debugPrint('Request Data: ${e.requestOptions.data}');
        debugPrint('Response Data: ${e.response?.data}');
        debugPrint('Response Status Code: ${e.response?.statusCode}');
      }
      debugPrint('================================');
      return null;
    }
  }

  Future<bool> isAuthenticated() async {
    // First check if we have a customer ID
    if (globalCustomerId == null) {
      debugPrint('(AuthProvider) Not authenticated: No customer ID');
      return false;
    }
    
    // Then check if we have a token
    final token = await AuthStorage.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('(AuthProvider) Not authenticated: No auth token');
      return false;
    }
    
    // Since validate-token endpoint doesn't exist, we'll consider the token valid
    // if we have both customer ID and token
    debugPrint('(AuthProvider) Token validation: Valid (skipping backend validation)');
    return true;
  }

  Future<void> logout() async {
    debugPrint('Logging out user...');
    
    // Clear local data
    await AuthStorage.deleteToken();
    globalCustomerId = null;
    debugPrint('Logout complete - user data cleared');
    
    // Notify listeners about the change
    notifyListeners();
  }
}