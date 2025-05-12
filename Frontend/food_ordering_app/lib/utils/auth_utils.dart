import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'auth_api.dart';

/// Call this at the start of initState() in every major screen.
Future<void> refreshTokenIfNeeded(BuildContext context) async {
  final refreshed = await AuthApi.refreshToken();
  if (!refreshed) {
    // Token refresh failed, do NOT log out or redirect. Let app handle gracefully.
    debugPrint('(AuthUtils) Token refresh failed, but not logging out. App will handle missing token.');
    return;
  }
}
