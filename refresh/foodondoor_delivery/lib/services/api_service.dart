import 'dart:convert';
import 'dart:io'; // For SocketException
import 'dart:async'; // For TimeoutException
import 'package:http/http.dart' as http;
import 'package:foodondoor_delivery/models/order_model.dart'; // Import OrderModel
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // TODO: Replace with your actual Django backend URL
  static const String _baseUrl = "http://192.168.225.54:8000/api/"; // Default for Android emulator
  final _secureStorage = const FlutterSecureStorage();
  static const String _authTokenKey = 'auth_token';
  final _httpClient = http.Client();

  // Helper to get stored token
  Future<String?> _getToken() async {
    return await _secureStorage.read(key: _authTokenKey);
  }

  // Helper to store token
  Future<void> _storeToken(String token) async {
    await _secureStorage.write(key: _authTokenKey, value: token);
  }

  // Helper to delete token
  Future<void> _deleteToken() async {
    await _secureStorage.delete(key: _authTokenKey);
  }

  // --- OTP Authentication Methods ---

  /// Sends a request to the backend to generate and send an OTP to the user's phone.
  Future<Map<String, dynamic>> requestOtp(String phoneNumber) async {
    final url = Uri.parse('${_baseUrl}otp/send/');
    print("Requesting OTP for $phoneNumber at $url"); // Debug
    try {
      final response = await _httpClient.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'phone_number': phoneNumber}),
      ).timeout(const Duration(seconds: 15));

      final responseBody = jsonDecode(utf8.decode(response.bodyBytes)); // Handle potential encoding issues
      print("Request OTP Response: ${response.statusCode} - $responseBody"); // Debug

      if (response.statusCode == 200 && responseBody['success'] == true) {
        return {'success': true, 'message': responseBody['message'] ?? 'OTP sent successfully.'};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to send OTP. Server error.'};
      }
    } on TimeoutException catch (_) {
      print("Request OTP Timeout");
      return {'success': false, 'message': 'Request timed out. Please try again.'};
    } on SocketException catch (_) {
      print("Request OTP Network Error");
      return {'success': false, 'message': 'Network error. Please check your connection.'};
    } catch (e) {
      print("Request OTP Error: $e");
      return {'success': false, 'message': 'An unexpected error occurred: $e'};
    }
  }

  /// Verifies the OTP entered by the user against the backend.
  /// Returns user data and tokens on success, or indicates if registration is needed.
  Future<Map<String, dynamic>> verifyOtp(String phoneNumber, String otp) async {
    final url = Uri.parse('${_baseUrl}otp/verify/');
    print("Verifying OTP for $phoneNumber with OTP $otp at $url"); // Debug
    try {
      final response = await _httpClient.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'phone_number': phoneNumber, 'otp': otp}),
      ).timeout(const Duration(seconds: 15));

      final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
      print("Verify OTP Response: ${response.statusCode} - $responseBody"); // Debug

      if (response.statusCode == 200 && responseBody['success'] == true) {
        // Check if login was successful (tokens returned) or if registration is needed
        if (responseBody.containsKey('access')) {
          await _storeToken(responseBody['access']);
          // TODO: Optionally store refresh token: responseBody['refresh']
          return {
            'success': true,
            'is_new_user': false,
            'message': responseBody['message'] ?? 'Login successful.',
            'user': responseBody['user'],
            'access_token': responseBody['access'],
          };
        } else if (responseBody['is_new_user'] == true) {
          return {
            'success': true,
            'is_new_user': true,
            'message': responseBody['message'] ?? 'OTP verified. Please complete registration.',
          };
        } else {
           // Should not happen based on backend logic, but handle defensively
           return {'success': false, 'message': 'Verification successful, but response format is unexpected.'};
        }
      } else {
        // Handle specific errors like 'Invalid OTP' or 'User not found'
        return {'success': false, 'message': responseBody['message'] ?? 'OTP verification failed.'};
      }
    } on TimeoutException catch (_) {
      print("Verify OTP Timeout");
      return {'success': false, 'message': 'Request timed out. Please try again.'};
    } on SocketException catch (_) {
      print("Verify OTP Network Error");
      return {'success': false, 'message': 'Network error. Please check your connection.'};
    } catch (e) {
      print("Verify OTP Error: $e");
      return {'success': false, 'message': 'An unexpected error occurred: $e'};
    }
  }

  /// Registers a new rider after successful OTP verification.
  Future<Map<String, dynamic>> registerRider(Map<String, dynamic> registrationData) async {
    // registrationData should contain phone_number, name, email, etc.
    final url = Uri.parse('${_baseUrl}register/');
    print("Registering Rider at $url with data: $registrationData"); // Debug
    try {
      final response = await _httpClient.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(registrationData),
      ).timeout(const Duration(seconds: 20));

      final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
      print("Register Rider Response: ${response.statusCode} - $responseBody"); // Debug

      if (response.statusCode == 200 && responseBody['success'] == true) {
        if (responseBody.containsKey('access')) {
          await _storeToken(responseBody['access']);
          // TODO: Optionally store refresh token: responseBody['refresh']
          return {
            'success': true,
            'message': responseBody['message'] ?? 'Registration successful.',
            'user': responseBody['user'],
            'access_token': responseBody['access'],
          };
        } else {
           return {'success': false, 'message': 'Registration successful, but token missing in response.'};
        }
      } else {
        // Handle specific registration errors (e.g., email already exists if applicable)
        return {'success': false, 'message': responseBody['message'] ?? 'Registration failed.'};
      }
    } on TimeoutException catch (_) {
      print("Register Rider Timeout");
      return {'success': false, 'message': 'Request timed out. Please try again.'};
    } on SocketException catch (_) {
      print("Register Rider Network Error");
      return {'success': false, 'message': 'Network error. Please check your connection.'};
    } catch (e) {
      print("Register Rider Error: $e");
      return {'success': false, 'message': 'An unexpected error occurred: $e'};
    }
  }

  // Example Logout Method
  Future<void> logout() async {
    // TODO: Add call to backend logout endpoint if it exists/is needed
    // Example: await http.post(Uri.parse('${_baseUrl}auth/logout/'), headers: await _getAuthHeaders());
    await _deleteToken(); // Clear local token regardless
  }

  // Method to check if a token exists (basic check)
  Future<bool> isAuthenticated() async {
    final token = await _getToken();
    // TODO: Optionally add token validation call to backend here
    return token != null;
  }

  // Fetch Orders Method (Refined)
  Future<List<OrderModel>> getOrders(String status) async {
    // Adjust endpoint and query parameter ('status') if needed
    final url = Uri.parse('${_baseUrl}orders/?status=$status');
    final token = await _getToken(); // This gets the 'access' token now

    if (token == null) {
      // Consider attempting a token refresh if implemented, otherwise fail.
      // bool refreshed = await _refreshToken();
      // if (refreshed) return getOrders(status); // Retry after refresh
      print("Error: No auth token found for getOrders.");
      throw Exception('Authentication token not found. Please log in again.');
    }

    print("Fetching orders with status: $status from $url"); // Debug log

    try {
      final response = await _httpClient.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          // Ensure this matches your Django backend (Token or Bearer)
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15)); // Add timeout

      print("GetOrders Response Status: ${response.statusCode}"); // Debug log
      // print("GetOrders Response Body: ${response.body}"); // Debug log (potentially large)

      if (response.statusCode == 200) {
        // Decode UTF8 body if necessary (handles potential encoding issues)
        String responseBody = utf8.decode(response.bodyBytes);
        List<dynamic> body = jsonDecode(responseBody);
        if (body is List) {
            List<OrderModel> orders = body
                .map((dynamic item) => OrderModel.fromJson(item as Map<String, dynamic>))
                .toList();
             print("Successfully parsed ${orders.length} orders."); // Debug log
            return orders;
        } else {
             print("Error: Expected a List but got ${body.runtimeType}");
            throw Exception('API response for orders was not a list.');
        }
      } else if (response.statusCode == 401) { // Unauthorized
        print("Error 401: Unauthorized fetching orders. Token might be invalid/expired.");
        // Optionally try refreshing token here
        // bool refreshed = await _refreshToken();
        // if (refreshed) return getOrders(status); // Retry after refresh
        await _deleteToken(); // Clear invalid token
        throw Exception('Unauthorized (401): Invalid or expired token. Please log in again.');
      } else {
        // Handle other errors (e.g., 404, 500)
        String errorDetail = 'Unknown error';
        try {
           final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
           errorDetail = errorBody['detail'] ?? errorBody.toString();
        } catch (_) {
           errorDetail = response.reasonPhrase ?? 'Failed to decode error';
        }
        print("Error ${response.statusCode} fetching orders: $errorDetail");
        throw Exception('Failed to load orders (Status ${response.statusCode}): $errorDetail');
      }
    } on SocketException catch (e) {
       print("Network Error fetching orders: $e");
       throw Exception('Network Error: Could not connect to the server. Please check your connection.');
    } on HttpException catch (e) {
        print("HTTP Error fetching orders: $e");
       throw Exception('Network Error: Could not find the server.');
    } on FormatException catch (e) {
        print("Format Error parsing order response: $e");
       throw Exception('Bad Response: Error parsing server response.');
    } on TimeoutException catch (e) {
        print("Timeout Error fetching orders: $e");
        throw Exception('Network Timeout: The server did not respond in time.');
    } catch (e) {
      print("Unexpected Error fetching orders: $e");
      throw Exception('An unexpected error occurred while fetching orders: $e');
    }
  }

  // Method to update the status of an order via API
  Future<bool> updateOrderStatus({
    required String orderId,
    required String newStatus,
    double? lat, // Optional latitude
    double? lng, // Optional longitude
  }) async {
    try {
      // **IMPORTANT:** Verify this endpoint with your Django urls.py
      final String url = '${_baseUrl}orders/$orderId/update-status/'; // Or just /api/orders/$orderId/

      // Construct the request body
      final Map<String, dynamic> body = {
        'status': newStatus,
      };
      // Add location if provided
      if (lat != null && lng != null) {
        body['latitude'] = lat;
        body['longitude'] = lng;
        // Add rider's address if your backend needs it
        // if (completeAddress != null && completeAddress!.isNotEmpty) {
        //   body['rider_address'] = completeAddress;
        // }
      }

      // Make the API request using the helper (assuming PATCH method)
      // Change 'patch' to 'put' if your backend uses PUT
      final response = await _httpClient.patch(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ${await _getToken()}',
        },
        body: jsonEncode(body),
      );

      // Check for successful response (e.g., 200 OK, 204 No Content)
      if (response.statusCode == 200 || response.statusCode == 204) {
        print('Order $orderId status updated to $newStatus successfully.');
        return true;
      } else {
        print('Failed to update order status for $orderId. Status code: ${response.statusCode}, Body: ${response.body}');
        // You might want to parse the error message from response.body
        return false;
      }
    } catch (e) {
      print('Error updating order status for $orderId: $e');
      return false;
    }
  }

   // --- Add other necessary API methods here ---
   // e.g., fetchUserProfile, updateProfile, etc.

}
