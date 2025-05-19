import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// WARNING: Deprecated. Use AuthStorage for all token management.
/*
// WARNING: Deprecated. Use AuthStorage for all token management.
//
// class TokenStorage {
//   static const _accessTokenKey = 'access_token';
//   static const _refreshTokenKey = 'refresh_token';
//   static final _storage = FlutterSecureStorage();
//
//   static Future<void> saveTokens(String accessToken, String refreshToken) async {
//     await _storage.write(key: _accessTokenKey, value: accessToken);
//     await _storage.write(key: _refreshTokenKey, value: refreshToken);
//   }
//
//   static Future<Map<String, String?>> readTokens() async {
//     final accessToken = await _storage.read(key: _accessTokenKey);
//     final refreshToken = await _storage.read(key: _refreshTokenKey);
//     return {
//       'accessToken': accessToken,
//       'refreshToken': refreshToken,
//     };
//   }
//
//   static Future<void> deleteTokens() async {
//     await _storage.delete(key: _accessTokenKey);
//     await _storage.delete(key: _refreshTokenKey);
//   }
// }
*/
