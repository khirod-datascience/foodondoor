import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../global/global.dart'; // Assuming global.dart exists for sharedPreferences

class ApiService {
  // --- Singleton Pattern Setup ---
  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  // --- Private internal constructor ---
  ApiService._internal() {
     _initializeDio();
     _initializeCookieJar().then((_) {
        // Ensure interceptors are added *after* cookie jar is potentially initialized
        _dio.interceptors.add(CookieManager(_cookieJar));
        _dio.interceptors.add(_AuthInterceptor(_storage)); // For Bearer token
        _dio.interceptors.add(LogInterceptor(responseBody: true, requestBody: true)); // Debugging
        debugPrint("ApiService Singleton Initialized with Interceptors.");
     });
  }
  // --- End Singleton Setup ---

  // Base URL for the VENDOR backend
  static const String _baseUrl = kDebugMode
      ? 'http://192.168.225.54:8000/vendor_auth' // Use vendor auth prefix
      : 'http://127.0.0.1:8000/vendor_auth'; // Adjust for production

  final _storage = const FlutterSecureStorage();
  late Dio _dio;
  late CookieJar _cookieJar;

  // --- Initialization (Called from constructor) ---
  void _initializeDio() { // Renamed from constructor logic
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
    ));
    _cookieJar = CookieJar(); // Start with in-memory Jar for Dio init
  }

  Future<void> _initializeCookieJar() async {
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      String cookiePath = p.join(appDocDir.path, ".vendor_cookies");
      // Use the same instance variable _cookieJar
      _cookieJar = PersistCookieJar(
        ignoreExpires: true,
        storage: FileStorage(cookiePath),
      );
      // Remove any default CookieManager added during init if necessary (though order should handle it)
      // _dio.interceptors.removeWhere((interceptor) => interceptor is CookieManager);
      // Insert *before* other interceptors if needed, or rely on constructor order
      // _dio.interceptors.insert(0, CookieManager(_cookieJar));
      debugPrint("Initialized persistent vendor cookie storage at: $cookiePath");
    } catch (e) {
      debugPrint("Error initializing persistent vendor cookie storage: $e. Using in-memory cookies.");
      _cookieJar = CookieJar(); // Fallback to in-memory
      // Ensure fallback is also used by Dio
      // _dio.interceptors.removeWhere((interceptor) => interceptor is CookieManager);
      // _dio.interceptors.insert(0, CookieManager(_cookieJar));
    }
  }

  // --- Token Management ---
  Future<String?> _getToken() async {
    // Use a different key for vendor token to avoid conflicts
    return await _storage.read(key: 'vendor_auth_token');
  }

  Future<void> storeToken(String token) async {
    await _storage.write(key: 'vendor_auth_token', value: token);
    debugPrint("Vendor token stored securely.");
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: 'vendor_auth_token');
    // Clear vendor-specific cookies
    if (_cookieJar is PersistCookieJar) {
        await (_cookieJar as PersistCookieJar).deleteAll();
    }
    // Clear vendor details from sharedPreferences if stored there
    await sharedPreferences?.remove('vendor_uid'); // Example key
    await sharedPreferences?.remove('vendor_name'); // Example key
    await sharedPreferences?.remove('vendor_email'); // Example key
    debugPrint("Vendor token & cookies deleted, user details cleared.");
  }

  Future<bool> hasToken() async {
    final token = await _getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> storeRefreshToken(String token) async {
    await _storage.write(key: 'vendor_refresh_token', value: token);
    debugPrint("Vendor refresh token stored securely.");
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: 'vendor_refresh_token');
  }

  // --- Core HTTP Methods using Dio (Generic) ---
  Future<Map<String, dynamic>> _request(
      Future<Response<dynamic>> Function() requestFunction, String endpoint) async {
    try {
      final response = await requestFunction();
      return _handleResponse(response, endpoint);
    } on DioException catch (e) {
      return _handleDioException(e, endpoint);
    } catch (e) {
      debugPrint('API Request Error ($endpoint): $e');
      return {'success': false, 'error': 'Unexpected error: $e'};
    }
  }

  Future<Map<String, dynamic>> get(String endpoint, {bool includeAuth = true}) async {
    return _request(() => _dio.get(
          endpoint,
          options: Options(extra: {'includeAuth': includeAuth}),
        ), endpoint);
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data, {bool includeAuth = true}) async {
    return _request(() => _dio.post(
          endpoint,
          data: data,
          options: Options(extra: {'includeAuth': includeAuth}),
        ), endpoint);
  }

   Future<Map<String, dynamic>> patch(String endpoint, Map<String, dynamic> data, {bool includeAuth = true}) async {
     return _request(() => _dio.patch(
           endpoint,
           data: data,
           options: Options(extra: {'includeAuth': includeAuth}),
         ), endpoint);
   }

  // Add PUT, DELETE if needed, similar structure...

  // --- Response and Error Handling (Same as Customer App) ---
   Map<String, dynamic> _handleResponse(Response response, String endpoint) {
    // ... (Same logic as customer ApiService._handleResponse) ...
     final responseData = response.data;
     final statusCode = response.statusCode ?? 0;

     if (statusCode >= 200 && statusCode < 300) {
       if (responseData is Map<String, dynamic>) {
         responseData['success'] = true;
         responseData['statusCode'] = statusCode;
         return responseData;
       } else if (responseData == null || (responseData is String && responseData.isEmpty)) {
         return {'success': true, 'statusCode': statusCode};
       } else {
         return {'success': true, 'statusCode': statusCode, 'data': responseData};
       }
     } else {
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
    // ... (existing code) ...
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
         errorMessage = 'Server error: $statusCode'; // Default message for bad response
         // --- BEGIN MODIFICATION ---
         // Attempt to extract more specific error from response body
         if (errorData is Map<String, dynamic>) {
            if (errorData.containsKey('detail')) {
               errorMessage = errorData['detail'].toString();
            } else if (errorData.containsKey('message')) {
               errorMessage = errorData['message'].toString();
            } else if (errorData.containsKey('error')) { // Check for 'error' key
               errorMessage = errorData['error'].toString();
            } else if (statusCode == 400) {
                // Try to concatenate field-specific errors for 400 responses
                List<String> errors = [];
                errorData.forEach((key, value) {
                   if (value is List && value.isNotEmpty) {
                      errors.add('$key: ${value.join(', ')}');
                   } else if (value is String) {
                       errors.add('$key: $value');
                   }
                });
                if (errors.isNotEmpty) {
                   errorMessage = errors.join('\n');
                } else {
                   errorMessage = 'Bad request ($statusCode)'; // Fallback for 400
                }
            } else {
               errorMessage = 'Server error ($statusCode)'; // General server error
            }
         } else if (errorData is String && errorData.isNotEmpty) {
            errorMessage = errorData; // Use string response directly if available
         }
        // --- END MODIFICATION ---
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

     // Keep adding details if available, but primary error message is set above
     if (errorData != null) {
        result['details'] = errorData;
     }
     // Removed redundant error message setting from details here
     // if (errorData is Map<String, dynamic>) { ... }

     return result;
   }

  // --- Vendor Specific Authentication Methods ---

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    // Endpoint path should match auth_app/urls.py relative to base URL
    return await post('/vendor/send-otp/', {'phone': phone}, includeAuth: false);
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp, {String? fcmToken}) async {
    final data = {'phone': phone, 'otp': otp};
    if (fcmToken != null && fcmToken.isNotEmpty) {
      data['fcm_token'] = fcmToken;
    }
    // CookieManager handles session cookie automatically
    return await post('/vendor/verify-otp/', data, includeAuth: false);
  }

  // --- Image Upload ---
  Future<Map<String, dynamic>> uploadImage(File imageFile) async {
    const String endpoint = '/upload-image/'; // Endpoint relative to base URL
    try {
      String fileName = imageFile.path.split('/').last;
      FormData formData = FormData.fromMap({
        "image": await MultipartFile.fromFile(imageFile.path, filename: fileName),
      });

      final response = await _dio.post(
        endpoint,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data', // Important for file uploads
            // Auth header will be added by the interceptor
          },
          extra: {'includeAuth': true}, // Ensure token is included
        ),
      );
      return _handleResponse(response, endpoint);
    } on DioException catch (e) {
      return _handleDioException(e, endpoint);
    } catch (e) {
      debugPrint('API Request Error ($endpoint): $e');
      return {'success': false, 'error': 'Unexpected error during image upload: $e'};
    }
  }

  Future<Map<String, dynamic>> registerVendor(Map<String, dynamic> vendorData) async {
    // Example vendorData: {'restaurant_name': '...', 'address': '...', 'email': '...', 'image_path': '...', ...}
    // Registration should happen *after* successful image upload
    return await post('/vendor/register/', vendorData, includeAuth: false); // Use session auth from OTP verification
  }

  // --- Add other vendor-specific methods as needed ---
  // e.g., getMenus, getItems, updateOrderStatus, getProfile, etc.
  // Remember to use includeAuth: true for protected endpoints.

 Future<Map<String, dynamic>> updateOrderStatus(String orderNumber, String newStatus) async {
    return await patch(
      '/vendor/orders/$orderNumber/', // Matches urls.py
      {'status': newStatus},
      includeAuth: true,
    );
  }

}

// --- Custom Interceptor for Authorization Header (Vendor) ---
class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;

  _AuthInterceptor(this._storage);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final bool includeAuth = options.extra['includeAuth'] ?? false;

    if (includeAuth) {
      final token = await _storage.read(key: 'vendor_auth_token');
       // --- Add more debugging ---
      debugPrint("[_AuthInterceptor] Checking for token. includeAuth=$includeAuth");
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
        debugPrint("[_AuthInterceptor] Token found and added to header: Bearer ${token.substring(0, 10)}...");
      } else {
         debugPrint("[_AuthInterceptor] No token found for auth request.");
      }
    }
     // Print headers just before sending the request
     // debugPrint("[_AuthInterceptor] Final Headers: ${options.headers}");
    super.onRequest(options, handler);
  }
} 