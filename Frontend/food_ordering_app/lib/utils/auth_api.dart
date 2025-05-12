import 'package:dio/dio.dart';
import 'auth_storage.dart';
import '../config.dart';
import 'package:flutter/material.dart';

class AuthApi {
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
      final response = await _dio.post(
        '${AppConfig.baseUrl}/token/refresh/',
        data: {'refresh': refreshToken},
      );
      if (response.statusCode == 200 && response.data != null && response.data['access'] != null) {
        final newAccessToken = response.data['access'];
        await AuthStorage.saveAccessToken(newAccessToken);
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

  /// Wrapper for authenticated Dio requests with automatic refresh & retry.
  /// Usage: await AuthApi.authenticatedRequest(() => dio.get(...))
  static Future<Response<T>?> authenticatedRequest<T>(Future<Response<T>> Function() requestFn) async {
    Response<T>? response;
    try {
      response = await requestFn();
      if (response.statusCode == 401) {
        // Try refresh and retry once
        final refreshed = await refreshToken();
        if (refreshed) {
          response = await requestFn();
        } else {
          debugPrint('(AuthApi) Token refresh failed, not clearing auth data automatically. Returning null to let UI handle session expiration.');
return null;
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
          debugPrint('(AuthApi) Token refresh failed, not clearing auth data automatically. Returning null to let UI handle session expiration.');
return null;
        }
      }
      rethrow;
    }
  }
}
