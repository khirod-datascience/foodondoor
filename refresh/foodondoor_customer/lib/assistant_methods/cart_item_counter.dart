import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../global/global.dart';
import '../services/api_service.dart';

class CartItemCounter extends ChangeNotifier {
  int _cartListItemCounter = 0;
  final ApiService _apiService = ApiService();

  int get count => _cartListItemCounter;

  void setCartCount(int newCount) {
    _cartListItemCounter = newCount;
    notifyListeners();
  }

  Future<void> fetchCartCount() async {
    try {
      final response = await _apiService.getCart();
      int count = 0;
      if (response['success'] == true) {
        if (response.containsKey('item_count') && response['item_count'] is int) {
          count = response['item_count'];
        } else if (response.containsKey('items') && response['items'] is List) {
          count = (response['items'] as List).length;
        } else if (response.containsKey('cart_items') && response['cart_items'] is List) {
          count = (response['cart_items'] as List).length;
        } else {
          debugPrint("Cart API response structure doesn't match expected keys for count (item_count, items, cart_items).");
        }
      } else {
        debugPrint("Error fetching cart count: ${response['error']}");
      }

      if (_cartListItemCounter != count) {
        _cartListItemCounter = count;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Exception fetching cart count: ${e.toString()}");
    }
  }
}
