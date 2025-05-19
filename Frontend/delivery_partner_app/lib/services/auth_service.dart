import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

class AuthService {
  // Use the consolidated delivery API base URL
  final String _baseUrl = AppConfig.deliveryApiBaseUrl;
  final _storage = const FlutterSecureStorage();

  // --- Keys for Secure Storage ---
  final String _accessTokenKey = 'access_token';
  final String _refreshTokenKey = 'refresh_token';

  // --- Token Management Methods ---

  Future<void> _storeTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  // --- API Call Methods ---

  Future<Map<String, dynamic>> sendOtp(String phoneNumber) async {
    try {
      // Endpoint path is relative to _baseUrl
      final response = await http.post(
        Uri.parse('$_baseUrl/otp/send/'), // Calls /api/delivery/otp/send/
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_number': phoneNumber}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': 'OTP sent successfully'};
      } else {
        print('Send OTP Error: ${response.statusCode} ${response.body}');
        String message = 'Failed to send OTP';
        try {
          final decodedBody = jsonDecode(response.body);
          message = decodedBody['message'] ?? message;
        } catch (_) {}
        return {'success': false, 'message': message};
      }
    } catch (e) {
       print('Send OTP Exception: $e');
       return {'success': false, 'message': 'An error occurred while sending OTP.'};
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String phoneNumber, String otp) async {
     try {
        final response = await http.post(
          Uri.parse('$_baseUrl/otp/verify/'), // Calls /api/delivery/otp/verify/
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone_number': phoneNumber, 'otp': otp}),
        );

        if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final accessToken = data['access'];
            final refreshToken = data['refresh'];
            final isNewUser = data['is_new_user'] ?? false;
            final user = data['user'];

            if (!isNewUser && (accessToken == null || refreshToken == null)) {
                 print('Verify OTP Error: Tokens not found for existing user.');
                 return {'success': false, 'message': 'Verification failed: Invalid response from server.'};
            }

            if (!isNewUser && accessToken != null && refreshToken != null) {
                 await _storeTokens(accessToken: accessToken, refreshToken: refreshToken);
            }
            // Return all relevant data
            return {'success': true, 'is_new_user': isNewUser, 'user': user, 'access': accessToken, 'refresh': refreshToken};

        } else {
             print('Verify OTP Error: ${response.statusCode} ${response.body}');
             String message = 'Invalid OTP or verification failed';
             try {
               final decodedBody = jsonDecode(response.body);
               message = decodedBody['message'] ?? message;
             } catch (_) {}
             return {'success': false, 'message': message};
        }
     } catch (e) {
        print('Verify OTP Exception: $e');
        return {'success': false, 'message': 'An error occurred during verification.'};
     }
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String phoneNumber,
    String? email,
  }) async {
     try {
        final response = await http.post(
          Uri.parse('$_baseUrl/register/'), // Calls /api/delivery/register/
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
              'phone_number': phoneNumber,
              'name': name,
              if (email != null && email.isNotEmpty) 'email': email,
          }),
        );

         if (response.statusCode == 200 || response.statusCode == 201) {
            final data = jsonDecode(response.body);
            final accessToken = data['access'];
            final refreshToken = data['refresh'];
            final user = data['user'];

            if (accessToken != null && refreshToken != null) {
                await _storeTokens(accessToken: accessToken, refreshToken: refreshToken);
                // Return all relevant data
                return {'success': true, 'user': user, 'access': accessToken, 'refresh': refreshToken};
            } else {
                print('Register Error: Tokens not found in response');
                return {'success': false, 'message': 'Registration failed: Invalid response'};
            }
        } else {
            print('Register Error: ${response.statusCode} ${response.body}');
            String message = 'Registration failed';
             try {
               final decodedBody = jsonDecode(response.body);
               message = decodedBody['message'] ?? message;
               if (decodedBody['errors'] is Map) {
                  message += ": ${decodedBody['errors']}";
               }
             } catch (_) {}
            return {'success': false, 'message': message};
        }
     } catch (e) {
         print('Register Exception: $e');
         return {'success': false, 'message': 'An error occurred during registration.'};
     }
  }

  // TODO: Implement refreshToken method if backend supports it
  // Future<bool> refreshToken() async { ... }

  // TODO: Implement logout API call if backend has an endpoint for it
  // Future<void> logoutApiCall() async { ... }

}
