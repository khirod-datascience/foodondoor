import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // for kDebugMode
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // For image upload content type

// Define function signature type for HTTP methods
typedef HttpRequestFunction = Future<http.Response> Function(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
});

class ApiService {
  // Replace with your actual backend IP/domain and port
  static const String _baseUrl = kDebugMode
      ? 'http://192.168.225.54:8000' // Android Emulator default localhost
      // ? 'http://192.168.1.YOUR_IP:8000' // Your local network IP
      : 'https://your-production-domain.com'; // Your production URL

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  // Standardized keys for vendor tokens
  static const String _vendorAuthTokenKey = 'vendor_auth_token';
  static const String _vendorRefreshTokenKey = 'vendor_refresh_token';

  // --- Authentication ---

  Future<Map<String, dynamic>> registerVendor(Map<String, dynamic> data) async {
    final url = Uri.parse('$_baseUrl/vendor_auth/vendor/register/');
    debugPrint('POST $url');
    debugPrint('Data: $data');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Registration Error: $e');
      return {'error': 'Network error during registration: $e'};
    }
  }

  Future<Map<String, dynamic>> loginVendor(String email, String password, String? fcmToken) async {
    final url = Uri.parse('$_baseUrl/vendor_auth/vendor/login/');
    final Map<String, String?> data = {'email': email, 'password': password};
    if (fcmToken != null && fcmToken.isNotEmpty) {
      data['fcm_token'] = fcmToken;
    }
    debugPrint('POST $url');
    debugPrint('Data: ${jsonEncode(data)}');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      // Log the raw response body before handling
      debugPrint('Login Response Status: ${response.statusCode}');
      debugPrint('Login Response Body: ${response.body}');

      Map<String, dynamic> responseBody = _handleResponse(response);

      // Store tokens using dedicated methods if login successful
      if (response.statusCode >= 200 && response.statusCode < 300 && responseBody.containsKey('access')) {
        String? tokenValue = responseBody['access'];
        String? refreshTokenValue = responseBody['refresh']; // Assuming refresh token is also returned

        if (tokenValue != null) {
          await storeToken(tokenValue);
        }
        if (refreshTokenValue != null) {
          await storeRefreshToken(refreshTokenValue);
        }
      } else {
        debugPrint('Token *not* found or error in login response. Status: ${response.statusCode}');
      }
      return responseBody;
    } catch (e) {
      debugPrint('Login Error: $e');
      return {'error': 'Network error during login: $e'};
    }
  }

  Future<void> logoutVendor() async {
    await deleteToken();
    debugPrint('Logged out, token deleted.');
  }

  // --- Token Management ---
  Future<String?> _getToken() async {
    // Use the standardized key
    return await _secureStorage.read(key: _vendorAuthTokenKey);
  }

  Future<void> storeToken(String token) async {
    await _secureStorage.write(key: _vendorAuthTokenKey, value: token);
    debugPrint("Vendor auth token stored securely.");
  }

  // Added method to store refresh token
  Future<void> storeRefreshToken(String refreshToken) async {
    await _secureStorage.write(key: _vendorRefreshTokenKey, value: refreshToken);
    debugPrint("Vendor refresh token stored securely.");
  }

  Future<void> deleteToken() async {
    await _secureStorage.delete(key: _vendorAuthTokenKey); // Use standardized key
    await _secureStorage.delete(key: _vendorRefreshTokenKey); // Delete refresh token too
    debugPrint("Vendor tokens deleted.");
  }

  // --- Token Refresh ---
  Future<bool> _refreshToken() async {
    debugPrint("Attempting to refresh vendor token...");
    final refreshToken = await _secureStorage.read(key: _vendorRefreshTokenKey); // Use standardized key

    if (refreshToken == null) {
      debugPrint("Refresh failed: No vendor refresh token found.");
      return false;
    }

    // Assuming standard SimpleJWT refresh endpoint
    final url = Uri.parse('$_baseUrl/vendor_auth/token/refresh/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );

      debugPrint('Token Refresh Response Status: ${response.statusCode}');
      debugPrint('Token Refresh Response Body: ${response.body}');

      Map<String, dynamic> responseBody = _handleResponse(response);

      if (response.statusCode == 200 && responseBody.containsKey('access')) {
        String? newToken = responseBody['access'];
        if (newToken != null) {
          await storeToken(newToken); // Store the new token
          // Optionally, update the refresh token if a new one is provided
          if (responseBody.containsKey('refresh')) {
            await storeRefreshToken(responseBody['refresh']);
          }
          debugPrint("Vendor token refreshed successfully.");
          return true;
        } else {
          debugPrint("Refresh failed: New access token was null.");
          return false;
        }
      } else {
         debugPrint("Refresh failed: Status code ${response.statusCode}.");
        // Consider deleting invalid refresh token if status is 401/403
        if (response.statusCode == 401 || response.statusCode == 403) {
            await _secureStorage.delete(key: _vendorRefreshTokenKey); // Use standardized key
            await _secureStorage.delete(key: _vendorAuthTokenKey); // Use standardized key
            debugPrint("Deleted invalid vendor refresh/access tokens.");
        }
        return false;
      }
    } catch (e) {
      debugPrint("Refresh failed: Network error: $e");
      return false;
    }
  }

  // --- Image Upload ---

  // Reverted: Does NOT include Authentication by default (for registration and potentially menus if endpoint allows)
  Future<Map<String, dynamic>> uploadImage(File imageFile) async {
    // Endpoint for uploading images
    final url = Uri.parse('$_baseUrl/vendor_auth/vendor/upload-image/');
    // REMOVED token reading
    debugPrint('POST $url (uploading image - NO AUTH)');
    // REMOVED token check

    try {
      var request = http.MultipartRequest('POST', url);

      // REMOVED adding authentication header
      // request.headers.addAll(_getAuthHeaders(token));

      // Add the file
      request.files.add(await http.MultipartFile.fromPath(
        'image', // Field name expected by Django backend
        imageFile.path,
        contentType: MediaType('image', imageFile.path.split('.').last ?? 'jpeg'),
      ));

      // Send the request
      debugPrint('Sending multipart request for image upload...');
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      debugPrint('Received response for image upload.');

      return _handleResponse(response);
    } catch (e) {
      debugPrint('Image Upload Error: $e');
      return {'error': 'Network error during image upload: $e'};
    }
  }

 // New method to create a menu item via POST request
  Future<Map<String, dynamic>> createMenu(Map<String, dynamic> menuData) async {
     const String endpoint = '/vendor_auth/vendor/menus/';
     debugPrint('Attempting to create menu...');
     return await post(endpoint, menuData);
  }

  // Method to get the list of menus for the logged-in vendor
  Future<Map<String, dynamic>> getMenus() async {
    const String endpoint = '/vendor_auth/vendor/menus/'; // Same endpoint, GET request
    debugPrint('Attempting to fetch menus...');
    return await get(endpoint);
  }

  // Method to get items for a specific menu
  Future<Map<String, dynamic>> getItemsForMenu(String menuId) async {
    // Adjust endpoint based on your backend URL structure
    final String endpoint = '/vendor_auth/vendor/menus/$menuId/items/';
    debugPrint('Attempting to fetch items for menu $menuId...');
    return await get(endpoint);
  }

  // Method to add an item to a specific menu
  Future<Map<String, dynamic>> addItemToMenu(String menuId, Map<String, dynamic> itemData) async {
    // Adjust endpoint based on your backend URL structure
    final String endpoint = '/vendor_auth/vendor/menus/$menuId/items/'; // POST to the items list endpoint
    debugPrint('Attempting to add item to menu $menuId...');
    return await post(endpoint, itemData);
  }

  // Method to delete a specific item
  Future<Map<String, dynamic>> deleteItem(String itemId) async {
    // Adjust endpoint based on your backend URL structure
    // Assumes items have a detail route like /items/<item_id>/
    final String endpoint = '/vendor_auth/vendor/items/$itemId/';
    debugPrint('Attempting to delete item $itemId...');
    return await delete(endpoint);
  }

  // --- Generic Request Helpers ---

  // Helper method to encapsulate token retrieval, request execution, and refresh/retry logic
  Future<Map<String, dynamic>> _request(
      String method, 
      String endpoint, 
      {Map<String, dynamic>? data} // Optional data for POST/PUT/PATCH
    ) async {

    int attempt = 1;
    while (attempt <= 2) { // Allow one retry after potential refresh
      final token = await _getToken();

      if (token == null && endpoint != '/vendor_auth/vendor/login/' && endpoint != '/vendor_auth/vendor/register/') {
          debugPrint('$method Error ($endpoint): Not authenticated (no token found).');
          // Return specific error for auth required but no token
          return {'error': 'Authentication required. Please log in.', 'statusCode': 401, 'isTokenExpired': false, 'requiresLogin': true};
      }

      final url = Uri.parse('$_baseUrl$endpoint');
      final headers = token != null ? _getAuthHeaders(token) : <String, String>{};
      if (data != null) {
        headers['Content-Type'] = 'application/json';
      }
      debugPrint('Headers for $method $endpoint: $headers');
      if (data != null) {
          debugPrint('Data for $method $endpoint: ${jsonEncode(data)}');
      }

      http.Response response;
      try {
        // Select the correct http method function
        HttpRequestFunction requestFunc;
        Object? requestBody = (data != null) ? jsonEncode(data) : null;

        switch (method.toUpperCase()) {
          case 'POST':
            requestFunc = http.post;
            break;
          case 'PUT':
            requestFunc = http.put;
            break;
          case 'PATCH':
            requestFunc = http.patch;
            break;
          case 'DELETE':
            // http.delete doesn't accept body in the same way, handle if needed
            // Use correct parameter names matching the typedef
            requestFunc = (Uri u, {Map<String, String>? headers, Object? body}) => http.delete(u, headers: headers);
             requestBody = null; // Ensure body is null for delete
            break;
          case 'GET':
          default:
            // http.get doesn't accept body
            // Use correct parameter names matching the typedef
             requestFunc = (Uri u, {Map<String, String>? headers, Object? body}) => http.get(u, headers: headers);
             requestBody = null; // Ensure body is null for get
        }

        // Execute the request
        response = await requestFunc(url, headers: headers, body: requestBody);

      } catch (e) {
        debugPrint('$method Error ($endpoint) - Network Exception: $e');
        return {'error': 'Network error: $e', 'isTokenExpired': false};
      }

      // Handle the response
      Map<String, dynamic> handledResponse = _handleResponse(response);

      // Check for token expiry
      if (handledResponse.containsKey('isTokenExpired') && handledResponse['isTokenExpired'] == true && attempt == 1) {
        debugPrint("Access token expired for $method $endpoint. Attempting refresh...");
        bool refreshed = await _refreshToken();
        if (refreshed) {
          // If refresh succeeded, increment attempt and loop to retry the request
          attempt++;
          debugPrint("Token refreshed. Retrying original request ($method $endpoint)...");
          continue; // Go to next iteration to retry
        } else {
          // If refresh failed, return specific error to prompt logout
           debugPrint("Refresh token failed for $method $endpoint. User needs to login again.");
           // Maybe logout directly here?
           // await logoutVendor();
           return {'error': 'Session expired. Please log in again.', 'statusCode': 401, 'isTokenExpired': true, 'requiresLogin': true};
        }
      } else {
        // If not expired, or if it was the second attempt, return the handled response
        return handledResponse;
      }
    } // End while loop

    // Should not be reached, but return generic error just in case
     return {'error': 'An unexpected error occurred during the request.', 'isTokenExpired': false};
  }

  Future<Map<String, dynamic>> get(String endpoint) async {
    debugPrint('GET $endpoint (via _request)');
    return await _request('GET', endpoint);
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
     debugPrint('POST $endpoint (via _request)');
     return await _request('POST', endpoint, data: data);
  }

   Future<Map<String, dynamic>> patch(String endpoint, Map<String, dynamic> data) async {
     debugPrint('PATCH $endpoint (via _request)');
     return await _request('PATCH', endpoint, data: data);
  }

  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data) async {
     debugPrint('PUT $endpoint (via _request)');
     return await _request('PUT', endpoint, data: data);
  }

   Future<Map<String, dynamic>> delete(String endpoint) async {
     debugPrint('DELETE $endpoint (via _request)');
     return await _request('DELETE', endpoint);
   }

  // --- Helper for Auth Headers ---

  Map<String, String> _getAuthHeaders(String? token) {
    if (token != null) {
      return {'Authorization': 'Bearer $token'};
    }
    return {};
  }

  // --- Response Handling ---
  Map<String, dynamic> _handleResponse(http.Response response) {
    debugPrint('Response Status: ${response.statusCode}');
    debugPrint('Response Body: ${response.body}');
    try {
      final decodedBody = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Ensure response is a Map, wrap Lists in a 'data' key for consistency
        if (decodedBody is List) {
          return {'data': decodedBody};
        } else if (decodedBody is Map<String, dynamic>){
          return decodedBody;
        } else {
           // Should not happen with typical JSON APIs, but handle just in case
           return {'data': decodedBody};
        }
      } else {
        // Include status code and check for specific token expiry error
        String errorMessage = decodedBody is Map && decodedBody.containsKey('detail')
                            ? decodedBody['detail']
                            : "Request failed with status code ${response.statusCode}";
        bool isTokenExpired = decodedBody is Map &&
                              decodedBody.containsKey('code') &&
                              decodedBody['code'] == 'token_not_valid' &&
                              response.statusCode == 401;

        return {
          'error': errorMessage,
          'statusCode': response.statusCode,
          'isTokenExpired': isTokenExpired // Add flag for token expiry
        };
      }
    } catch (e) {
      // Handle cases where response body is not valid JSON
      debugPrint('JSON Decode Error: $e');
      if (response.statusCode >= 200 && response.statusCode < 300) {
         // Success status but invalid JSON? Return raw body or error.
         return {'error': 'Received success status but invalid JSON response body.', 'statusCode': response.statusCode};
      } else {
         return {'error': 'Request failed with status code ${response.statusCode} and invalid response body.', 'statusCode': response.statusCode, 'isTokenExpired': false};
      }
    }
  }
}
