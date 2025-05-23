import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/customer_api_service.dart';
import 'dart:convert';
import '../utils/auth_storage.dart';
import '../config.dart';
import '../utils/auth_api.dart';

class OrderProvider extends ChangeNotifier {
  Map<String, dynamic>? trackingData;
  String? orderStatus;
  bool loadingTracking = false;
  bool loadingStatus = false;
  String? lastTrackingError;

  List<Map<String, dynamic>> _inProgressOrders = [];
  List<Map<String, dynamic>> get inProgressOrders => _inProgressOrders;
  Map<String, dynamic>? get latestInProgressOrder => _inProgressOrders.isNotEmpty ? _inProgressOrders.first : null;

  Future<void> fetchInProgressOrders({String? customerId}) async {
    _inProgressOrders = [];
    try {
      final response = await CustomerApiService.getOrders(customerId: customerId);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          // Filter for in-progress orders (status not delivered/cancelled)
          _inProgressOrders = List<Map<String, dynamic>>.from(
            data.where((order) => order['status'] != null && order['status'] != 'delivered' && order['status'] != 'cancelled')
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching in-progress orders: $e');
    }
    notifyListeners();
  }

  Future<void> fetchTracking(String orderNumber) async {
    loadingTracking = true; notifyListeners();
    try {
      final dioResponse = await AuthApi.authenticatedRequest(() async {
        // Use Dio for consistency with AuthApi wrapper
        final dio = Dio();
        final token = await AuthStorage.getToken();
        return dio.get(
          '${AppConfig.baseUrl}/orders/$orderNumber/track/',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      });
      if (dioResponse != null && dioResponse.statusCode == 200 && dioResponse.data != null) {
        // New backend fields: status, delivery_lat, delivery_lng
        trackingData = dioResponse.data is Map<String, dynamic>
            ? dioResponse.data
            : Map<String, dynamic>.from(dioResponse.data); // Should contain 'status', 'delivery_lat', 'delivery_lng'
      } else if (dioResponse == null) {
        trackingData = null;
        // Session expired or token refresh failed
        // Optionally, notify listeners/UI for session expiration
      }
    } catch (e) {
      trackingData = null;
      lastTrackingError = e.toString();
    }
    loadingTracking = false; notifyListeners();
  }

  Future<void> fetchOrderStatus(String orderNumber) async {
    loadingStatus = true; notifyListeners();
    final response = await CustomerApiService.getOrderStatus(orderNumber);
    if (response.statusCode == 200) {
      orderStatus = jsonDecode(response.body)['status'];
    }
    loadingStatus = false; notifyListeners();
  }
}
