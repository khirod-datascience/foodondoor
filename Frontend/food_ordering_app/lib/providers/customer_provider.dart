import 'package:flutter/material.dart';
import '../services/customer_api_service.dart';
import 'dart:convert';

class CustomerProvider extends ChangeNotifier {
  // Profile
  Map<String, dynamic>? profile;
  bool loadingProfile = false;
  Future<void> fetchProfile(String customerId) async {
    loadingProfile = true; notifyListeners();
    final response = await CustomerApiService.getProfile(customerId);
    if (response.statusCode == 200) {
      profile = Map<String, dynamic>.from(jsonDecode(response.body));
    }
    loadingProfile = false; notifyListeners();
  }
  // Add similar methods for update/delete
  Future<void> updateProfile(String customerId, Map<String, dynamic> data) async {
    // TODO: Implement actual update logic
    print('Called updateProfile with $customerId and $data');
    await Future.delayed(Duration(milliseconds: 500));
    notifyListeners();
  }

  Future<void> deleteProfile(String customerId) async {
    // TODO: Implement actual delete logic
    print('Called deleteProfile with $customerId');
    await Future.delayed(Duration(milliseconds: 500));
    notifyListeners();
  }
  // ...
}
