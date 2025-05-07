import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // Import for kDebugMode
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:foodondoor_vendor_app/src/constants/api_constants.dart';

class AuthService {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  static const _accessTokenKey = 'accessToken';
  static const _refreshTokenKey = 'refreshToken';
  static const _signupTokenKey = 'signupToken'; // Key for signup token

  // Flag to prevent multiple concurrent refresh attempts
  bool _isRefreshing = false;

  // Callback to notify AuthProvider about authentication failure
  final VoidCallback? onAuthFailure;

  AuthService(this._dio, this._secureStorage, {this.onAuthFailure}) {
    _dio.interceptors.add(QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add the access token to the header if available
        final accessToken = await getAccessToken();
        if (accessToken != null && accessToken.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $accessToken';
          if (kDebugMode) {
            print('[Dio Interceptor] Added auth token to request: ${options.path}');
          }
        }
        return handler.next(options); // Continue
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          if (kDebugMode) {
            print('[Dio Interceptor] Received 401 error for path: ${e.requestOptions.path}');
          }

          // Prevent multiple refresh calls if multiple requests fail concurrently
          if (!_isRefreshing) {
            _isRefreshing = true;
            try {
              final newAccessToken = await _refreshToken();
              if (newAccessToken != null) {
                if (kDebugMode) {
                  print('[Dio Interceptor] Token refresh successful. Retrying request.');
                }
                // Update the failed request's header
                e.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
                // Retry the request with the new token
                final response = await _dio.fetch(e.requestOptions);
                _isRefreshing = false;
                return handler.resolve(response);
              } else {
                // Refresh failed (e.g., refresh token expired)
                if (kDebugMode) {
                  print('[Dio Interceptor] Token refresh failed. Logging out.');
                }
                await clearTokens();
                onAuthFailure?.call(); // Notify AuthProvider
                _isRefreshing = false;
                return handler.reject(DioException(
                  requestOptions: e.requestOptions,
                  response: e.response,
                  type: e.type,
                  error: 'Token refresh failed, user logged out.',
                ));
              }
            } catch (refreshError) {
              if (kDebugMode) {
                print('[Dio Interceptor] Error during token refresh: $refreshError. Logging out.');
              }
              await clearTokens();
              onAuthFailure?.call(); // Notify AuthProvider
              _isRefreshing = false;
              return handler.reject(DioException(
                requestOptions: e.requestOptions,
                response: e.response,
                type: e.type,
                error: 'Exception during token refresh, user logged out: $refreshError',
              ));
            }
          } else {
            // If already refreshing, just wait for the refresh to complete or fail
            // This part might need more robust handling (e.g., waiting on a Future)
            // For simplicity, we reject subsequent 401s while refreshing
            if (kDebugMode) {
              print('[Dio Interceptor] Already refreshing token. Rejecting subsequent 401 for ${e.requestOptions.path}');
            }
            return handler.reject(e);
          }

        } // End if 401
        return handler.next(e); // Forward other errors
      },
    ));
  }

  // --- Token Storage ---
  Future<void> _storeTokens(String accessToken, String refreshToken) async {
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: _refreshTokenKey);
  }

  Future<void> clearTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await clearSignupToken(); // Also clear signup token on general clear/logout
    print('Access, Refresh, and Signup tokens cleared.');
  }

  // --- Signup Token Handling ---
  Future<String?> getSignupToken() async {
    return await _secureStorage.read(key: _signupTokenKey);
  }

  Future<void> clearSignupToken() async {
    await _secureStorage.delete(key: _signupTokenKey);
    print('Signup token cleared.');
  }

  // --- Token Refresh ---
  Future<String?> _refreshToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      print('[AuthService _refreshToken] No refresh token found.');
      return null;
    }

    try {
      print('[AuthService _refreshToken] Attempting to refresh token...');
      final response = await _dio.post(
        ApiConstants.refreshTokenUrl, // Make sure this constant points to your refresh endpoint
        data: {'refresh': refreshToken},
        options: Options(headers: {'Authorization': null}), // Don't send expired access token for refresh
      );

      if (response.statusCode == 200 && response.data?['access'] != null) {
        final newAccessToken = response.data!['access'];
        // Store the new access token (refresh token usually remains the same or is rotated)
        await _secureStorage.write(key: _accessTokenKey, value: newAccessToken);
        print('[AuthService _refreshToken] Token refresh successful. New access token stored.');
        return newAccessToken;
      } else {
        print('[AuthService _refreshToken] Failed to refresh token. Status: ${response.statusCode}, Data: ${response.data}');
        return null;
      }
    } on DioException catch (e) {
      // Handle Dio specific errors, especially if refresh endpoint itself returns 401 (invalid refresh token)
      print('[AuthService _refreshToken] DioError during token refresh: ${e.response?.statusCode} - ${e.message}');
      return null;
    } catch (e) {
      print('[AuthService _refreshToken] Unknown error during token refresh: $e');
      return null;
    }
  }

  // --- API Calls ---
  /// Sends a request to the backend to send an OTP to the given phone number.
  Future<bool> sendOtp(String phoneNumber) async {
    try {
      final response = await _dio.post(
        ApiConstants.sendOtpUrl,
        data: {
          'phone_number': phoneNumber,
          'user_type': 'vendor', // *** Important: Set user_type to vendor ***
        },
      );
      // Log the response details regardless of status code
      print('[AuthService sendOtp] Response Status Code: ${response.statusCode}');
      print('[AuthService sendOtp] Response Data: ${response.data}');

      // Check for success (adjust if backend uses different codes)
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      // Log Dio-specific errors
      print('[AuthService sendOtp] DioError: ${e.response?.statusCode} - ${e.response?.data ?? e.message}');
      return false;
    } catch (e) {
      // Log any other unexpected errors
      print('[AuthService sendOtp] Unexpected Error: $e');
      return false;
    }
  }

  /// Verifies the OTP entered by the user.
  /// Returns a map indicating the result type ('login', 'signup', or 'error')
  /// and relevant data (tokens or error message).
  Future<Map<String, String?>> verifyOtp(String phoneNumber, String otpCode) async {
    try {
      final response = await _dio.post(
        ApiConstants.verifyOtpUrl,
        data: {
          'phone_number': phoneNumber,
          'otp_code': otpCode,
          'user_type': 'vendor', // Add user type for vendor app
        },
      );

      if (response.statusCode == 200) {
        final accessToken = response.data?['access'];
        final refreshToken = response.data?['refresh'];
        final signupToken = response.data?['signup_token'];

        if (accessToken != null && refreshToken != null) {
          // Login successful
          await _storeTokens(accessToken, refreshToken);
          await clearSignupToken(); // Clear any potential leftover signup token
          print('Login successful, tokens stored.');
          return {'type': 'login', 'access': accessToken, 'refresh': refreshToken};
        } else if (signupToken != null && signupToken.isNotEmpty) {
          // Signup flow: OTP verified, profile needed
          await _secureStorage.write(key: _signupTokenKey, value: signupToken);
          await _secureStorage.delete(key: _accessTokenKey);
          await _secureStorage.delete(key: _refreshTokenKey);
          print('Signup OTP verified, signup token stored.');
          final storedToken = await _secureStorage.read(key: _signupTokenKey);
          print('[AuthService verifyOtp] Stored signup token. Value read back: $storedToken');
          return {'type': 'signup'};
        } else {
          print('Verify OTP Error: Tokens or signup token missing in response. Data: ${response.data}');
          return {'type': 'error', 'message': 'Invalid response from server.'};
        }
      } else {
        print('Verify OTP Error: Status code ${response.statusCode}, Data: ${response.data}');
        return {'type': 'error', 'message': 'Server error during OTP verification.'};
      }
    } on DioException catch (e) {
      print('DioError verifying OTP: ${e.response?.statusCode} - ${e.response?.data ?? e.message}');
      return {'type': 'error', 'message': e.response?.data?['detail'] ?? 'Network error during OTP verification.'};
    } catch (e) {
      print('Unexpected error verifying OTP: $e');
      return {'type': 'error', 'message': 'An unexpected error occurred.'};
    }
  }

  /// Registers the vendor after OTP verification for signup.
  /// Sends profile data along with the signup token to the backend.
  /// Stores access and refresh tokens upon successful registration.
  /// Returns true on success, false on failure.
  Future<bool> registerVendor(Map<String, dynamic> profileData) async {
    final signupToken = await getSignupToken();
    if (signupToken == null) {
      print('Vendor Registration Error: Signup token not found.');
      return false; // Or throw an exception
    }

    try {
      print('Attempting vendor registration with signup token...');
      // Combine profile data with the signup token for the request body
      final requestData = {
        ...profileData,
        'signup_token': signupToken, // Send signup token in the body
      };

      final response = await _dio.post(
        ApiConstants.vendorRegisterUrl, // Use the new vendor registration URL
        data: requestData,
        // Remove Authorization header, token is now in body
        // options: Options(
        //   headers: {
        //     'Authorization': 'Bearer $signupToken',
        //   },
        // ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final accessToken = response.data?['access'];
        final refreshToken = response.data?['refresh'];

        if (accessToken != null && refreshToken != null) {
          await _storeTokens(accessToken, refreshToken);
          await clearSignupToken(); // Important: Clear signup token after successful registration
          print('Vendor registered successfully. Access/Refresh tokens stored.');
          return true;
        } else {
          print('Vendor Registration Error: Access/Refresh tokens missing in response. Data: ${response.data}');
          return false;
        }
      } else {
        print('Vendor Registration Error: Status code ${response.statusCode}, Data: ${response.data}');
        return false;
      }
    } on DioException catch (e) {
      print('DioError during vendor registration: ${e.response?.statusCode} - ${e.response?.data ?? e.message}');
      return false;
    } catch (e) {
      print('Unexpected error during vendor registration: $e');
      return false;
    }
  }

  /// Fetches the authenticated vendor's profile data.
  /// Returns a Map<String, dynamic> with profile data on success, or null on failure.
  Future<Map<String, dynamic>?> getVendorProfile() async {
    final accessToken = await getAccessToken();
    if (accessToken == null) {
      print('Get Vendor Profile Error: No access token found.');
      // Optionally trigger token refresh or logout here
      return null;
    }

    try {
      print('Fetching vendor profile...');
      final response = await _dio.get(
        ApiConstants.vendorProfileUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response.statusCode == 200) {
        print('Vendor profile fetched successfully.');
        return response.data as Map<String, dynamic>;
      } else {
        print('Get Vendor Profile Error: Status code ${response.statusCode}, Data: ${response.data}');
        return null;
      }
    } on DioException catch (e) {
      print('DioError fetching vendor profile: ${e.response?.statusCode} - ${e.response?.data ?? e.message}');
      // Handle specific errors like 401 Unauthorized (token expired?)
      if (e.response?.statusCode == 401) {
        // TODO: Implement token refresh logic here
        print('Access token potentially expired. Need refresh mechanism.');
      }
      return null;
    } catch (e) {
      print('Unexpected error fetching vendor profile: $e');
      return null;
    }
  }

  /// Clears stored tokens (access, refresh, signup).
  Future<void> logout() async {
    await clearTokens();
    print('AuthService: Logout called, all tokens cleared.');
    // Note: AuthProvider handles the status change notification
  }

  /// Completes the vendor registration process.
  Future<Map<String, dynamic>> completeRegistration(Map<String, String> profileData) async {
    print('[AuthService completeRegistration] Attempting to retrieve signup token...'); // Log before read
    // Retrieve the signup token from storage
    final signupToken = await _secureStorage.read(key: _signupTokenKey);
    print('[AuthService completeRegistration] Result of getSignupToken: $signupToken'); // Log after read

    if (signupToken == null || signupToken.isEmpty) {
      print('[AuthService completeRegistration] Error: Signup token is null or empty.'); // Log error case
      throw Exception('Signup token not found.');
    }
    print('[AuthService] Retrieved signup token for registration header: $signupToken'); // Add log
    try {
      print('[AuthService] Attempting registration with token: $signupToken and data: $profileData'); // Add log
      final response = await _dio.post(
        ApiConstants.vendorRegisterUrl,
        data: profileData,
        options: Options(
          headers: {
            'Authorization': 'Token $signupToken',
          },
        ),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final accessToken = response.data?['access'];
        final refreshToken = response.data?['refresh'];

        if (accessToken != null && refreshToken != null) {
          await _storeTokens(accessToken, refreshToken);
          await clearSignupToken(); // Important: Clear signup token after successful registration
          print('Vendor registered successfully. Access/Refresh tokens stored.');
          return {'type': 'success', 'access': accessToken, 'refresh': refreshToken};
        } else {
          print('Vendor Registration Error: Access/Refresh tokens missing in response. Data: ${response.data}');
          throw Exception('Failed to complete registration: ${response.data['error'] ?? 'Unknown error'}');
        }
      } else {
        print('Vendor Registration Error: Status code ${response.statusCode}, Data: ${response.data}');
        throw Exception('Failed to complete registration: ${response.data['error'] ?? 'Unknown error'}');
      }
    } on DioException catch (e) {
      print('DioError during vendor registration: ${e.response?.statusCode} - ${e.response?.data ?? e.message}');
      throw Exception(e.response?.data['error'] ?? 'Network error during registration.');
    } catch (e) {
      print('Unexpected error during vendor registration: $e');
      throw Exception('An unexpected error occurred during registration.');
    }
  }
}
