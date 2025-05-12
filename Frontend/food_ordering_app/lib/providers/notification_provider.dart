import 'package:flutter/material.dart';
import '../services/customer_api_service.dart';
import 'dart:convert';

class NotificationProvider extends ChangeNotifier {
  List<dynamic> notifications = [];
  bool loading = false;
  String? errorMessage;

  Future<void> fetchNotifications() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await CustomerApiService.getNotifications();
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        notifications = data['notifications'] ?? [];
        errorMessage = null;
      } else {
        errorMessage = 'Failed to fetch notifications';
      }
    } catch (e) {
      errorMessage = 'Error: $e';
    }
    loading = false;
    notifyListeners();
  }
}

