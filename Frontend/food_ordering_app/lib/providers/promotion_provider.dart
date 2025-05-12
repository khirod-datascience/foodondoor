import 'package:flutter/material.dart';
import '../services/customer_api_service.dart';
import 'dart:convert';

class PromotionProvider extends ChangeNotifier {
  List<dynamic> promotions = [];
  bool loading = false;

  Future<void> fetchPromotions() async {
    loading = true; notifyListeners();
    final response = await CustomerApiService.getPromotions();
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      promotions = data['promotions'] ?? [];
    }
    loading = false; notifyListeners();
  }
}
