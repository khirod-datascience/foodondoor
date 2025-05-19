import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../utils/auth_storage.dart'; // TokenStorage fully removed
import '../utils/globals.dart';
import '../screens/login_screen.dart';
import '../config.dart';
// Fetch addresses for a given customer ID (with authentication and retry)
Future<Response?> fetchAddressesByCustomerId(String customerId) async {
  try {
    final dio = ApiClient().dio;
    final url = '${AppConfig.baseUrl}/customer/$customerId/addresses/';
    final response = await dio.get(url);
    return response;
  } catch (e) {
    debugPrint('[ApiClient] Error fetching addresses for customer $customerId: $e');
    return null;
  }
}
// Fetch addresses with authentication for use in Home and Checkout screens
Future<Response?> fetchAddressesWithAuth() async {
  try {
    final dio = ApiClient().dio;
    final response = await dio.get('/api/customer/address/');
    return response;
  } catch (e) {
    debugPrint('[ApiClient] Error fetching addresses: $e');
    return null;
  }
}


class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  late Dio dio;

  ApiClient._internal() {
    dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final accessToken = await AuthStorage.getToken();
        if (accessToken != null) {
          options.headers['Authorization'] = 'Bearer $accessToken';
        } else {
          debugPrint('[ApiClient] No access token found for request.');
        }
        return handler.next(options);
      },
      onError: (DioException error, handler) async {
        if (error.response?.statusCode == 401) {
          debugPrint('[ApiClient] Received 401. Attempting to refresh token...');
          final refreshed = await _refreshToken(onRefreshFail: (String failReason) async {
            // Only called if refresh endpoint fails (e.g., 401/403 on refresh)
            debugPrint('[ApiClient] Refresh token failed: $failReason');
            // Show SnackBar and redirect to login
            if (navigatorKey.currentState != null) {
              final context = navigatorKey.currentState!.overlay!.context;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Session expired. Please log in again.'), backgroundColor: Colors.red)
              );
              // Redirect to login after short delay
              await Future.delayed(Duration(milliseconds: 800));
              navigatorKey.currentState!.pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (route) => false,
              );
            }
          });
          if (refreshed) {
            final newAccessToken = await AuthStorage.getToken();
            if (newAccessToken != null) {
              error.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
              final opts = Options(
                method: error.requestOptions.method,
                headers: error.requestOptions.headers,
                responseType: error.requestOptions.responseType,
                contentType: error.requestOptions.contentType,
                extra: error.requestOptions.extra,
                followRedirects: error.requestOptions.followRedirects,
                receiveDataWhenStatusError: error.requestOptions.receiveDataWhenStatusError,
                validateStatus: error.requestOptions.validateStatus,
                receiveTimeout: error.requestOptions.receiveTimeout,
                sendTimeout: error.requestOptions.sendTimeout,
              );
              final cloneReq = await dio.request(
                error.requestOptions.path,
                data: error.requestOptions.data,
                queryParameters: error.requestOptions.queryParameters,
                options: opts,
              );
              return handler.resolve(cloneReq);
            } else {
              debugPrint('[ApiClient] No new access token after refresh.');
            }
          } else {
            debugPrint('[ApiClient] Token refresh failed. User will be logged out only if refresh token is invalid/expired.');
          }
        }
        return handler.next(error);
      },
    ));
  }

  static bool _refreshing = false;
  static Completer<bool>? _refreshCompleter;

  static Future<bool> _refreshToken({Future<void> Function(String failReason)? onRefreshFail}) async {
    if (_refreshing) {
      // If already refreshing, wait for the same result
      if (_refreshCompleter != null) {
        return _refreshCompleter!.future;
      }
    }
    _refreshing = true;
    _refreshCompleter = Completer<bool>();
    final refreshToken = await AuthStorage.getRefreshToken();
    debugPrint('[ApiClient] Attempting token refresh. Refresh token: ' + (refreshToken ?? 'NULL'));
    if (refreshToken == null) {
      debugPrint('[ApiClient] No refresh token found.');
      _refreshing = false;
      _refreshCompleter?.complete(false);
      if (onRefreshFail != null) await onRefreshFail('No refresh token found');
      return false;
    }
    try {
      // Use a new Dio instance to avoid interceptor loops
      final dio = Dio();
      debugPrint('[ApiClient] Sending refresh request to /api/customer/auth/refresh/ with payload: {"refresh": "$refreshToken"}');
      final response = await dio.post(
        '/api/customer/auth/refresh/',
        data: {'refresh': refreshToken},
        options: Options(headers: {}), // Ensure no Authorization header
      );
      debugPrint('[ApiClient] Refresh response: status=${response.statusCode}, data=${response.data}');
      final newAccessToken = response.data['access'];
      final newRefreshToken = response.data['refresh'] ?? refreshToken;
      debugPrint('[ApiClient] Saving new tokens: access=' + (newAccessToken != null ? newAccessToken.substring(0,8) : 'NULL') + '..., refresh=' + (newRefreshToken != null ? newRefreshToken.substring(0,8) : 'NULL') + '...');
      await AuthStorage.saveAccessToken(newAccessToken);
      await AuthStorage.saveRefreshToken(newRefreshToken);
      _refreshing = false;
      _refreshCompleter?.complete(true);
      return true;
    } on DioException catch (e) {
      debugPrint('[ApiClient] Refresh failed: status=${e.response?.statusCode}, data=${e.response?.data}, message=${e.message}');
      _refreshing = false;
      _refreshCompleter?.complete(false);
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        if (onRefreshFail != null) await onRefreshFail('Refresh endpoint returned ${e.response?.statusCode}');
      }
      return false;
    } catch (e) {
      debugPrint('[ApiClient] Refresh failed: $e');
      _refreshing = false;
      _refreshCompleter?.complete(false);
      if (onRefreshFail != null) await onRefreshFail('Unknown error: $e');
      return false;
    }
  }
}
