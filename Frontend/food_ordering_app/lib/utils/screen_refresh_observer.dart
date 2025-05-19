import 'package:flutter/material.dart';
import 'auth_api.dart';

/// A NavigatorObserver that refreshes the token on every screen transition.
class ScreenRefreshObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _refreshTokenIfNeeded();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _refreshTokenIfNeeded();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _refreshTokenIfNeeded();
  }

  void _refreshTokenIfNeeded() async {
    await AuthApi.refreshToken();
  }
}
