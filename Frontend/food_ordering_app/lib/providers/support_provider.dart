import 'package:flutter/material.dart';
import '../services/customer_api_service.dart';
import 'dart:convert';

class SupportProvider extends ChangeNotifier {
  List<dynamic> messages = [];
  bool loading = false;
  bool sending = false;

  Future<void> fetchMessages() async {
    loading = true; notifyListeners();
    final response = await CustomerApiService.getSupportMessages();
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      messages = data['messages'] ?? [];
    }
    loading = false; notifyListeners();
  }

  Future<void> sendMessage(String message) async {
    sending = true; notifyListeners();
    final response = await CustomerApiService.sendSupportMessage(message);
    if (response.statusCode == 200) {
      await fetchMessages();
    }
    sending = false; notifyListeners();
  }
}
