import 'dart:convert';
import 'dart:io'; // For Platform checks if needed later

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:http/http.dart' as http; // Remove http import
import 'package:path_provider/path_provider.dart'; // Needed for PersistCookieJar storage path
import 'package:path/path.dart' as p; // For joining paths

import '../global/global.dart'; // Import global variables
import 'package:foodondoor_customer/models/address.dart'; // Import Address model

class ApiService {
  static const String _baseUrl = kDebugMode
      ? 'http://192.168.225.54:8000/customer'
      // ?'http://192.168.62.184:8000/customer' // Use your actual dev IP with path
      : 'http://127.0.0.1:8000/customer'; // Replace with deployed URL if needed

  final _storage = const FlutterSecureStorage();
  late Dio _dio;
  late CookieJar _cookieJar;

  // Provide a static getter for token to sync with AuthProvider
  static Future<String?> getToken() async {
    return await const FlutterSecureStorage().read(key: 'auth_token');
  }

  // --- Initialization ---
  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10), // Example timeouts
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
    ));

    // Initialize Cookie Jar (using PersistCookieJar for persistence)
    // Note: For web, cookie handling might differ. Consider conditional logic if targeting web.
    _cookieJar = CookieJar(); // Start with in-memory Jar
    _initializeCookieJar(); // Asynchronously initialize persistent jar

    // Add Interceptors
    _dio.interceptors.add(CookieManager(_cookieJar));
    _dio.interceptors.add(_AuthInterceptor(_storage)); // Custom interceptor for Bearer token
    _dio.interceptors.add(LogInterceptor(responseBody: true, requestBody: true)); // Optional: for debugging
  }

  Future<void> _initializeCookieJar() async {
    // Use PersistCookieJar for automatic cookie persistence across app sessions
    // Requires path_provider
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      String appDocPath = appDocDir.path;
      final cookiePath = p.join(appDocPath, ".cookies");
      _cookieJar = PersistCookieJar(
        ignoreExpires: true,
        storage: FileStorage(cookiePath),
      );
      // Re-add the interceptor with the persistent jar
      _dio.interceptors.removeWhere((interceptor) => interceptor is CookieManager);
      _dio.interceptors.insert(0, CookieManager(_cookieJar)); // Ensure it runs early
      debugPrint("Initialized persistent cookie storage at: $cookiePath");
    } catch (e) {
      debugPrint("Error initializing persistent cookie storage: $e. Using in-memory cookies.");
      // Fallback to in-memory if path_provider fails (e.g., specific platforms)
      _cookieJar = CookieJar();
      _dio.interceptors.removeWhere((interceptor) => interceptor is CookieManager);
      _dio.interceptors.insert(0, CookieManager(_cookieJar));
    }
  }

  // --- Token Management (remains the same) ---
  Future<String?> _getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<void> storeToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
    debugPrint("Token stored securely.");
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: 'auth_token');
    await (_cookieJar as PersistCookieJar).deleteAll(); // Clear cookies on logout
    await sharedPreferences?.remove('uid');
    await sharedPreferences?.remove('name');
    await sharedPreferences?.remove('email');
    await sharedPreferences?.remove('phone');
    debugPrint("Token and cookies deleted securely and user details cleared.");
  }

  Future<bool> hasToken() async {
    final token = await _getToken();
    return token != null && token.isNotEmpty;
  }

  /// Checks if the stored authentication token is still valid by pinging the backend.
  /// If the token is invalid (401), it deletes the token from storage.
  /// Returns true if the token is valid, false otherwise.
  Future<bool> checkAuthStatus() async {
    // First, check if a token exists locally to avoid unnecessary API call
    if (!await hasToken()) {
      debugPrint("Auth Check: No local token found.");
      return false;
    }

    try {
      // Use the existing 'get' method which includes auth headers and handles responses.
      // The '/api/check-auth/' path is relative to the baseUrl '/customer'
      await get('/api/check-auth/', includeAuth: true);
      // If the 'get' call completes without throwing, the token is valid (2xx status)
      debugPrint("Auth Check: Token is valid.");
      return true;
    } on DioException catch (e) {
      // Check specifically for 401 Unauthorized
      if (e.response?.statusCode == 401) {
        debugPrint("Auth Check: Token is invalid (401). Deleting token.");
        await deleteToken(); // Clear the invalid token
        return false;
      }
      // Handle other Dio-related errors (network, server errors other than 401)
      debugPrint("Auth Check: Failed due to DioException - ${e.message}");
      // Optionally, you could inspect e.type for specific DioExceptionTypes
      return false;
    } catch (e) {
      // Handle any other unexpected errors
      debugPrint("Auth Check: Failed due to unexpected error - $e");
      return false;
    }
  }

  // Store both access and refresh tokens
  Future<void> storeTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: 'auth_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
    debugPrint("Tokens stored securely.");
  }

  Future<String?> _getRefreshToken() async {
    return await _storage.read(key: 'refresh_token');
  }

  // --- Token Refresh Logic ---
  Future<bool> _refreshToken() async {
    final refreshToken = await _getRefreshToken();
    if (refreshToken == null) return false;
    try {
      final response = await _dio.post(
        '/customer_auth/token/refresh/',
        data: {'refresh': refreshToken},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      if (response.statusCode == 200 && response.data['access'] != null) {
        await _storage.write(key: 'auth_token', value: response.data['access']);
        debugPrint('Access token refreshed.');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Token refresh failed: $e');
      await deleteToken();
      return false;
    }
  }

  // --- Core HTTP Methods using Dio ---
  Future<Map<String, dynamic>> get(String endpoint, {bool includeAuth = true}) async {
    try {
      final response = await _dio.get(
        endpoint,
        options: Options(extra: {'includeAuth': includeAuth}),
      );
      return _handleResponse(response, endpoint);
    } on DioException catch (e) {
      // If token expired, try to refresh and retry once
      if (e.response?.statusCode == 401 && _isTokenExpiredError(e)) {
        final refreshed = await _refreshToken();
        if (refreshed) {
          final retryResponse = await _dio.get(
            endpoint,
            options: Options(extra: {'includeAuth': includeAuth}),
          );
          return _handleResponse(retryResponse, endpoint);
        }
      }
      return _handleDioException(e, endpoint);
    } catch (e) {
      debugPrint('API GET Error ($endpoint): $e');
      return {'success': false, 'error': 'Unexpected error: $e'};
    }
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data, {bool includeAuth = true}) async {
    try {
      final response = await _dio.post(
        endpoint,
        data: data,
        options: Options(extra: {'includeAuth': includeAuth}),
      );
      return _handleResponse(response, endpoint);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 && _isTokenExpiredError(e)) {
        final refreshed = await _refreshToken();
        if (refreshed) {
          final retryResponse = await _dio.post(
            endpoint,
            data: data,
            options: Options(extra: {'includeAuth': includeAuth}),
          );
          return _handleResponse(retryResponse, endpoint);
        }
      }
      return _handleDioException(e, endpoint);
    } catch (e) {
      debugPrint('API POST Error ($endpoint): $e');
      return {'success': false, 'error': 'Unexpected error: $e'};
    }
  }

  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data, {bool includeAuth = true}) async {
    try {
      final response = await _dio.put(
        endpoint,
        data: data,
        options: Options(extra: {'includeAuth': includeAuth}),
      );
      return _handleResponse(response, endpoint);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 && _isTokenExpiredError(e)) {
        final refreshed = await _refreshToken();
        if (refreshed) {
          final retryResponse = await _dio.put(
            endpoint,
            data: data,
            options: Options(extra: {'includeAuth': includeAuth}),
          );
          return _handleResponse(retryResponse, endpoint);
        }
      }
      return _handleDioException(e, endpoint);
    } catch (e) {
      debugPrint('API PUT Error ($endpoint): $e');
      return {'success': false, 'error': 'Unexpected error: $e'};
    }
  }

  Future<Map<String, dynamic>> delete(String endpoint, {Map<String, dynamic>? data, bool includeAuth = true}) async {
    try {
      final response = await _dio.delete(
        endpoint,
        data: data,
        options: Options(extra: {'includeAuth': includeAuth}),
      );
      return _handleResponse(response, endpoint);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 && _isTokenExpiredError(e)) {
        final refreshed = await _refreshToken();
        if (refreshed) {
          final retryResponse = await _dio.delete(
            endpoint,
            data: data,
            options: Options(extra: {'includeAuth': includeAuth}),
          );
          return _handleResponse(retryResponse, endpoint);
        }
      }
      return _handleDioException(e, endpoint);
    } catch (e) {
      debugPrint('API DELETE Error ($endpoint): $e');
      return {'success': false, 'error': 'Unexpected error: $e'};
    }
  }

  // Helper to check if error is token expired
  bool _isTokenExpiredError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString().toLowerCase().contains('token has expired');
    }
    return false;
  }

  // --- Response and Error Handling ---

  Map<String, dynamic> _handleResponse(Response response, String endpoint) {
    final responseData = response.data;
    final statusCode = response.statusCode ?? 0;

    // Dio typically throws DioException for non-2xx status codes,
    // but we handle successful responses here.
    if (statusCode >= 200 && statusCode < 300) {
      if (responseData is Map<String, dynamic>) {
        // Existing map response
        responseData['success'] = true;
        responseData['statusCode'] = statusCode;
        return responseData;
      } else if (responseData == null || (responseData is String && responseData.isEmpty)) {
        // Handle empty successful response (e.g., 204 No Content)
        return {'success': true, 'statusCode': statusCode};
      } else {
        // Handle non-map successful response (e.g., list, string)
        return {'success': true, 'statusCode': statusCode, 'data': responseData};
      }
    } else {
      // This part might be less likely reached if DioException handles errors
      debugPrint('API Error Response (_handleResponse) ($endpoint): $statusCode - $responseData');
      return {
        'success': false,
        'error': 'API Error: $statusCode',
        'statusCode': statusCode,
        'details': responseData,
      };
    }
  }

  Map<String, dynamic> _handleDioException(DioException e, String endpoint) {
    debugPrint('API DioException ($endpoint): ${e.type} - ${e.message}');
    int? statusCode = e.response?.statusCode;
    dynamic errorData = e.response?.data;
    String errorMessage = 'Network error';

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        errorMessage = 'Connection timeout';
        break;
      case DioExceptionType.badResponse:
        errorMessage = 'Server error: $statusCode';
        break;
      case DioExceptionType.cancel:
        errorMessage = 'Request cancelled';
        break;
      case DioExceptionType.connectionError:
         errorMessage = 'Connection error. Check network.';
         break;
      case DioExceptionType.unknown:
      default:
        errorMessage = 'An unknown error occurred: ${e.message}';
        break;
    }

    final result = {
      'success': false,
      'error': errorMessage,
      'statusCode': statusCode ?? 0,
    };

    // Try to include details from the response body if available
    if (errorData is Map<String, dynamic>) {
      result['details'] = errorData;
      // Extract a more specific message if backend provides one (common pattern)
      if (errorData.containsKey('detail')) {
         result['error'] = errorData['detail'].toString();
      } else if (errorData.containsKey('message')) {
         result['error'] = errorData['message'].toString();
      }
    } else if (errorData is String && errorData.isNotEmpty) {
       result['details'] = errorData;
    }

    return result;
  }

  // --- Cart Specific Methods (use new core methods) ---

  Future<Map<String, dynamic>> getCart() async {
    return await get('/api/cart/', includeAuth: true);
  }

  Future<Map<String, dynamic>> addToCart(String itemId, int quantity) async {
    return await post(
      '/api/cart/add/',
      {'item_id': itemId, 'quantity': quantity},
      includeAuth: true,
    );
  }

  Future<Map<String, dynamic>> removeFromCart(String itemId) async {
    return await delete('/api/cart/item/$itemId/', includeAuth: true);
  }

  Future<Map<String, dynamic>> updateCartItemQuantity(String itemId, int quantity) async {
    return await put(
      '/api/cart/item/$itemId/',
      {'quantity': quantity},
      includeAuth: true,
    );
  }

  Future<Map<String, dynamic>> clearCart() async {
    return await delete('/api/cart/', includeAuth: true);
  }

  // --- Authentication Helpers (use new core methods) ---

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    // Auth is not included for sending OTP
    return await post('/customer_auth/send-otp/', {'phone': phone}, includeAuth: false);
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    // Auth is not included for verifying OTP
    // CookieManager will automatically handle the session cookie received here
    return await post('/customer_auth/verify-otp/', {'phone': phone, 'otp': otp}, includeAuth: false);
  }

  Future<Map<String, dynamic>> registerCustomer(String name, String email) async {
    // Auth token is not included, but CookieManager sends the session cookie
    // received from verifyOtp automatically.
    return await post(
      '/customer_auth/register/', 
      {'name': name, 'email': email},
      includeAuth: false // No bearer token needed, session cookie is used
    );
  }

  // Method to get the auth token
  Future<String?> _getAuthToken() async {
    return await _storage.read(key: 'auth_token');
  }

  // Method to fetch customer addresses
  Future<List<Address>> getCustomerAddresses() async {
    final String? token = await _getAuthToken();
    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    try {
      final response = await _dio.get(
        '/api/addresses/',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      debugPrint('Get Addresses Status Code: [32m${response.statusCode}[0m');
      debugPrint('Get Addresses Response Body: [36m${response.data}[0m');

      if (response.statusCode == 200) {
        List<dynamic> body = response.data;
        List<Address> addresses = body
            .map((dynamic item) => Address.fromJson(item as Map<String, dynamic>))
            .toList();
        return addresses;
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh
        final refreshed = await _refreshToken();
        if (refreshed) {
          // Retry once after refreshing token
          return await getCustomerAddresses();
        } else {
          // Logout and throw
          await deleteToken();
          throw Exception('Session expired. Please login again.');
        }
      } else {
        String errorMessage = 'Failed to load addresses. Status code: ${response.statusCode}';
        try {
          Map<String, dynamic> errorBody = response.data;
          errorMessage = errorBody['message'] ?? errorBody['detail'] ?? errorMessage;
        } catch (e) {
          debugPrint("Error parsing error response: $e");
        }
        throw Exception(errorMessage);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Token expired, try to refresh
        final refreshed = await _refreshToken();
        if (refreshed) {
          // Retry once after refreshing token
          return await getCustomerAddresses();
        } else {
          // Logout and throw
          await deleteToken();
          throw Exception('Session expired. Please login again.');
        }
      }
      debugPrint('Failed to load addresses: ${e.message}');
      throw Exception('Failed to load addresses: ${e.message}');
    }
  }

  // Add Address method (will be needed for SaveAddressScreen later)
  Future<Map<String, dynamic>> addAddress(Map<String, dynamic> addressData) async {
    final String? token = await _getAuthToken();
    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await _dio.post(
      '/api/addresses/', // Endpoint for adding address (fixed)
      data: addressData,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    debugPrint('Add Address Status Code: [32m${response.statusCode}[0m');
    debugPrint('Add Address Response Body: [36m${response.data}[0m');

    if (response.statusCode == 201) {
      return response.data;
    } else {
      String errorMessage = 'Failed to add address. Status code: ${response.statusCode}';
      try {
        Map<String, dynamic> errorBody = response.data;
        errorMessage = errorBody['message'] ?? errorBody['detail'] ?? errorMessage;
      } catch (e) {
        debugPrint("Error parsing error response: $e");
      }
      throw Exception(errorMessage);
    }
  }
}

// --- Custom Interceptor for Authorization Header ---
class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;

  _AuthInterceptor(this._storage);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Check if auth should be included for this request (passed via options.extra)
    final bool includeAuth = options.extra['includeAuth'] ?? false;

    if (includeAuth) {
      final token = await _storage.read(key: 'auth_token');
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
        debugPrint("Auth Interceptor: Added Bearer token.");
      } else {
         debugPrint("Auth Interceptor: No token found for auth request.");
      }
    }
    super.onRequest(options, handler);
  }
}