import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class Order {
  final String id;
  final String orderNumber;
  final double totalAmount;
  final String status;
  final String deliveryAddress;
  final DateTime createdAt;
  final List<OrderItem> items;
  
  Order({
    required this.id,
    required this.orderNumber,
    required this.totalAmount,
    required this.status,
    required this.deliveryAddress,
    required this.createdAt,
    required this.items,
  });
  
  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'].toString(),
      orderNumber: json['order_number'],
      totalAmount: double.parse(json['total_amount'].toString()),
      status: json['status'],
      deliveryAddress: json['delivery_address'],
      createdAt: DateTime.parse(json['created_at']),
      items: (json['items'] as List<dynamic>)
          .map((item) => OrderItem.fromJson(item))
          .toList(),
    );
  }
}

class OrderItem {
  final String id;
  final Map<String, dynamic> food;
  final int quantity;
  final double price;
  
  OrderItem({
    required this.id,
    required this.food,
    required this.quantity,
    required this.price,
  });
  
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'].toString(),
      food: json['food'],
      quantity: json['quantity'],
      price: double.parse(json['price'].toString()),
    );
  }
}

class OrderProvider with ChangeNotifier {
  List<Order> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  List<Order> get orders => [..._orders];
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // Filter orders by status
  List<Order> getOrdersByStatus(String status) {
    return _orders.where((order) => order.status == status).toList();
  }
  
  // Get a specific order
  Order? getOrderById(String orderId) {
    try {
      return _orders.firstWhere((order) => order.id == orderId);
    } catch (e) {
      return null;
    }
  }
  
  // Fetch all orders for the vendor
  Future<void> fetchOrders() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final vendorId = prefs.getString('vendor_id');
      
      if (token == null || vendorId == null) {
        _errorMessage = 'Authentication required';
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/vendor/$vendorId/orders/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        _orders = data.map((item) => Order.fromJson(item)).toList();
        _isLoading = false;
        notifyListeners();
      } else {
        _errorMessage = 'Failed to fetch orders';
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'An error occurred: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Update an order status
  Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final vendorId = prefs.getString('vendor_id');
      
      if (token == null || vendorId == null) {
        _errorMessage = 'Authentication required';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      final response = await http.patch(
        Uri.parse('${Config.baseUrl}/vendor/$vendorId/orders/$orderId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({
          'status': newStatus,
        }),
      );
      
      if (response.statusCode == 200) {
        // Update local order
        final orderIndex = _orders.indexWhere((order) => order.id == orderId);
        if (orderIndex >= 0) {
          final updatedOrderData = jsonDecode(response.body);
          final updatedOrder = Order.fromJson(updatedOrderData);
          _orders[orderIndex] = updatedOrder;
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to update order status';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'An error occurred: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Clear any error messages
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
} 