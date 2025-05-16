import 'package:dio/dio.dart';
import 'auth_storage.dart';
import '../config.dart';
import 'package:flutter/material.dart';
import 'jwt_utils.dart';
import '../utils/globals.dart';

class AuthApi {
  /// Attempts silent login using stored credentials. Returns true if successful.
  static Future<bool> silentLogin() async {
    try {
      final phone = await AuthStorage.getPhone();
      final email = await AuthStorage.getEmail();
      if (phone == null) {
        debugPrint('(AuthApi) No stored phone for silent login.');
        return false;
      }
      final response = await _dio.post(
        '${AppConfig.baseUrl}/login/',
        data: {
          'phone': phone,
          if (email != null) 'email': email,
        },
      );
      if (response.statusCode == 200 && response.data != null && response.data['auth_token'] != null) {
        final newAccessToken = response.data['auth_token'];
        final newRefreshToken = response.data['refresh_token'];
        await AuthStorage.saveAccessToken(newAccessToken);
        if (newRefreshToken != null) {
          await AuthStorage.saveRefreshToken(newRefreshToken);
        }
        debugPrint('(AuthApi) Silent login succeeded.');
        return true;
      } else {
        debugPrint('(AuthApi) Silent login failed: ${response.data}');
        return false;
      }
    } catch (e) {
      debugPrint('(AuthApi) Exception during silent login: $e');
      return false;
    }
  }
  static final Dio _dio = Dio();

  /// Attempts to refresh the JWT token using the refresh endpoint.
  /// Returns true if refresh succeeded, false otherwise.
  /// Attempts to refresh the JWT access token using the refresh token.
  /// Returns true if refresh succeeded, false otherwise.
  static Future<bool> refreshToken() async {
    try {
      final refreshToken = await AuthStorage.getRefreshToken();
      final customerId = await AuthStorage.getCustomerId();
      if (refreshToken == null || customerId == null) {
        debugPrint('(AuthApi) No refresh token or customerId for refresh.');
        return false;
      }
      debugPrint('(AuthApi) Attempting refresh with token: ' + refreshToken);
      final response = await _dio.post(
        '${AppConfig.baseUrl}/token/refresh/',
        data: {'refresh': refreshToken},
      );
      if (response.statusCode == 200 && response.data != null && response.data['access'] != null) {
        final newAccessToken = response.data['access'];
        final newRefreshToken = response.data['refresh'];
        await AuthStorage.saveAccessToken(newAccessToken);
        if (newRefreshToken != null) {
          await AuthStorage.saveRefreshToken(newRefreshToken);
        }
        debugPrint('(AuthApi) Token refresh succeeded.');
        return true;
      } else {
        debugPrint('(AuthApi) Token refresh failed: ${response.data}');
        return false;
      }
    } catch (e) {
      debugPrint('(AuthApi) Exception during token refresh: $e');
      return false;
    }
  }

  /// Checks and refreshes the access token if expired before making authenticated requests.
  /// If both refresh and silent login fail, calls [onSessionExpired] if provided.
  static Future<Response<T>?> authenticatedRequest<T>(
    Future<Response<T>> Function() requestFn, {
    VoidCallback? onSessionExpired,
  }) async {
    Response<T>? response;
    try {
      // Check token expiry before making request
      final accessToken = await AuthStorage.getToken();
      if (accessToken != null && JwtUtils.isTokenExpired(accessToken)) {
        debugPrint('(AuthApi) Access token expired, attempting refresh before request.');
        final refreshed = await refreshToken();
        if (!refreshed) {
           debugPrint('(AuthApi) Token refresh failed, session expired. Logging out and redirecting.');
           // Show a snackbar if context is available
           try {
             // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
             final ctx = navigatorKey.currentContext;
             if (ctx != null) {
               ScaffoldMessenger.of(ctx).showSnackBar(
                 const SnackBar(content: Text('Session expired. Please log in again.')),
               );
             }
           } catch (e) {
             debugPrint('Could not show session expired snackbar: ' + e.toString());
           }
           if (onSessionExpired != null) onSessionExpired();
           return null;
        }
      }
      response = await requestFn();
      if (response.statusCode == 401) {
        // Try refresh and retry once
        final refreshed = await refreshToken();
        if (refreshed) {
          response = await requestFn();
        } else {
          // Try silent login if refresh fails
          debugPrint('(AuthApi) Token refresh failed, attempting silent login...');
          final silent = await silentLogin();
          if (silent) {
            response = await requestFn();
          } else {
            debugPrint('(AuthApi) Silent login failed. Session expired. Logging out and redirecting.');
            if (onSessionExpired != null) onSessionExpired();
            return null;
          }
        }
      }
      return response;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final refreshed = await refreshToken();
        if (refreshed) {
          try {
            response = await requestFn();
            return response;
          } catch (e2) {
            debugPrint('(AuthApi) Retried request after refresh failed: $e2');
          }
        } else {
          // Try silent login if refresh fails
          debugPrint('(AuthApi) Token refresh failed, attempting silent login...');
          final silent = await silentLogin();
          if (silent) {
            try {
              response = await requestFn();
              return response;
            } catch (e2) {
              debugPrint('(AuthApi) Retried request after silent login failed: $e2');
            }
          } else {
            debugPrint('(AuthApi) Silent login failed. Session expired. Logging out and redirecting.');
            if (onSessionExpired != null) onSessionExpired();
            return null;
          }
        }
      }
      rethrow;
    }
  }
}

