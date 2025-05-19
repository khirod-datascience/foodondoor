import 'package:dio/dio.dart';
import '../utils/auth_storage.dart';
import 'api_client.dart';

class AuthService {
  static Future<bool> login(String username, String password) async {
    final dio = ApiClient().dio;
    try {
      final response = await dio.post('/api/token/', data: {
        'username': username,
        'password': password,
      });
      final accessToken = response.data['access'];
      final refreshToken = response.data['refresh'];
      await AuthStorage.saveAccessToken(accessToken);
      await AuthStorage.saveRefreshToken(refreshToken);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> logout() async {
    await AuthStorage.deleteTokens();
    // TODO: Add navigation to login screen using a global navigator key
  }
}
