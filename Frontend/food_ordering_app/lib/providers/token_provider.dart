import 'package:flutter/material.dart';

class TokenProvider extends ChangeNotifier {
  String? _accessToken;
  String? _refreshToken;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  void setTokens({required String accessToken, required String refreshToken}) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    notifyListeners();
  }

  void setAccessToken(String token) {
    _accessToken = token;
    notifyListeners();
  }

  void setRefreshToken(String token) {
    _refreshToken = token;
    notifyListeners();
  }

  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
    notifyListeners();
  }
}
