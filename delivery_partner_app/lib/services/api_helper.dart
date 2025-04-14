import 'dart:convert';
import 'dart:io'; // For HttpStatus
import 'package:http/http.dart' as http;
import 'auth_service.dart'; // To access token methods
import '../config/app_config.dart'; // <-- Ensure this import exists

class ApiHelper {
  // Use the consolidated delivery API base URL from AppConfig
  static const String _apiBaseUrl = AppConfig.deliveryApiBaseUrl;
  final AuthService _authService = AuthService(); // Get access to token storage

  // Centralized method for making authenticated GET requests
  Future<Map<String, dynamic>> get(String endpoint) async {
    // Endpoint should be relative path, e.g., '/orders?status=pending'
    return _makeRequest(
      () async {
        final token = await _authService.getAccessToken();
        if (token == null) throw Exception('Not authenticated');

        final response = await http.get(
          Uri.parse('$_apiBaseUrl$endpoint'), // Constructs full URL like http://IP:PORT/api/delivery/orders?status=...
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token', // Assuming Bearer token auth
          },
        );
        return response;
      },
    );
  }

  // Centralized method for making authenticated POST requests
  Future<Map<String, dynamic>> post(String endpoint, {Map<String, dynamic>? body}) async {
     return _makeRequest(
      () async {
        final token = await _authService.getAccessToken();
        if (token == null) throw Exception('Not authenticated');

        final response = await http.post(
          Uri.parse('$_apiBaseUrl$endpoint'), // Constructs full URL
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: body != null ? jsonEncode(body) : null,
        );
         return response;
      },
    );
  }

   // Centralized method for making authenticated PUT requests
  Future<Map<String, dynamic>> put(String endpoint, {Map<String, dynamic>? body}) async {
     return _makeRequest(
      () async {
        final token = await _authService.getAccessToken();
        if (token == null) throw Exception('Not authenticated');

        final response = await http.put(
          Uri.parse('$_apiBaseUrl$endpoint'), // Constructs full URL
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: body != null ? jsonEncode(body) : null,
        );
         return response;
      },
    );
  }

  // TODO: Add methods for other HTTP verbs (PATCH, DELETE) if needed

  // Internal request handler with error parsing and potential token refresh
  Future<Map<String, dynamic>> _makeRequest(Future<http.Response> Function() requestFunc) async {
     try {
        http.Response response = await requestFunc();

        // TODO: Implement token refresh logic
        // if (response.statusCode == HttpStatus.unauthorized) {
        //   print("Token expired, attempting refresh...");
        //   final bool refreshed = await _authService.refreshToken(); // Assumes AuthService has refreshToken
        //   if (refreshed) {
        //     print("Token refreshed successfully, retrying request...");
        //     response = await requestFunc(); // Retry the original request
        //   } else {
        //     print("Token refresh failed. Logging out.");
        //     // Need a way to trigger logout, maybe throw specific exception
        //     await _authService.clearTokens();
        //     throw Exception('Session expired. Please login again.');
        //   }
        // }

        return _handleResponse(response);

     } on SocketException {
         print("Network Error: No Internet connection or server down.");
         return {'success': false, 'message': 'Network error. Please check your connection.'};
     } on Exception catch (e) {
         print("API Helper Exception: $e");
         if (e.toString().contains('Session expired')) {
            return {'success': false, 'message': 'Session expired. Please login again.'};
         }
         return {'success': false, 'message': e.toString()};
     } catch (e) {
         print("API Helper Unknown Error: $e");
         return {'success': false, 'message': 'An unexpected error occurred.'};
     }
  }

  // Handles parsing the response and checking status codes
  Map<String, dynamic> _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    print("API Response [${response.request?.method} ${response.request?.url}]: $statusCode"); // Log request

    if (statusCode >= 200 && statusCode < 300) {
        try {
             if (response.body.isEmpty) {
                 return {'success': true, 'data': null};
             }
             final dynamic decodedBody = jsonDecode(response.body);
             if (decodedBody is Map<String, dynamic> && decodedBody.containsKey('success') && decodedBody['success'] == false) {
                 return {
                   'success': false,
                   'message': decodedBody['message'] ?? 'Request failed but status code was $statusCode',
                   'errors': decodedBody['errors']
                 };
             }
             return {'success': true, 'data': decodedBody};
        } catch (e) {
             print("API Response JSON Decode Error: $e");
             return {'success': false, 'message': 'Error parsing server response.'};
        }
    } else {
      String errorMessage = 'Request failed with status code: $statusCode';
      Map<String, dynamic>? errors;
      try {
        final decodedBody = jsonDecode(response.body);
        if (decodedBody is Map<String, dynamic>) {
            errorMessage = decodedBody['detail'] ?? decodedBody['message'] ?? errorMessage;
            errors = decodedBody['errors'];
        }
      } catch (_) { /* Ignore decoding error, use default message */ }
      print("API Error Response Body: ${response.body}");
      return {'success': false, 'message': errorMessage, 'errors': errors};
    }
  }
}
