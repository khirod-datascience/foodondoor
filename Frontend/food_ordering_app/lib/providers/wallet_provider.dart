import 'package:flutter/material.dart';
import '../services/customer_api_service.dart';
import 'dart:convert';

class WalletProvider extends ChangeNotifier {
  double balance = 0.0;
  List<dynamic> transactions = [];
  bool loading = false;

  Future<void> fetchWallet() async {
    loading = true; notifyListeners();
    final response = await CustomerApiService.getWallet();
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      balance = (data['balance'] ?? 0).toDouble();
      transactions = data['transactions'] ?? [];
    }
    loading = false; notifyListeners();
  }

  Future<void> fetchTransactions() async {
    loading = true; notifyListeners();
    final response = await CustomerApiService.getTransactions();
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      transactions = data['transactions'] ?? [];
    }
    loading = false; notifyListeners();
  }
}
