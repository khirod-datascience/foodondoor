import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../assistant_methods/cart_item_counter.dart';
import '../assistant_methods/total_ammount.dart';
import '../global/global.dart';
import '../services/api_service.dart';

// Functions related to parsing local cart ID/Quantity strings are removed
// as cart state will be managed via API.

// --- New API-based Cart Functions ---

Future<void> addItemToCartAPI(String itemId, int quantity, BuildContext context) async {
  final apiService = ApiService();
  try {
    // Show loading indicator maybe?
    final response = await apiService.addToCart(itemId, quantity);

    if (response['success'] == true) {
      Fluttertoast.showToast(msg: "Item Added Successfully.");
      // Update cart counter provider
       Provider.of<CartItemCounter>(context, listen: false).fetchCartCount();

    } else {
      Fluttertoast.showToast(msg: "Error adding item: ${response['error'] ?? response['details'] ?? 'Unknown error'}");
    }
  } catch (e) {
    Fluttertoast.showToast(msg: "Error adding item: ${e.toString()}");
  }
}

Future<void> clearCartAPI(BuildContext context) async {
   final apiService = ApiService();
    try {
       // Show loading?
      final response = await apiService.clearCart();

      if (response['success'] == true) {
         Fluttertoast.showToast(msg: "Cart Cleared Successfully.");
         // Update cart counter provider
          Provider.of<CartItemCounter>(context, listen: false).setCartCount(0);
          // Also potentially clear total amount provider
           Provider.of<TotalAmount>(context, listen: false).setTotalAmount(0.0);

      } else {
          Fluttertoast.showToast(msg: "Error clearing cart: ${response['error'] ?? response['details'] ?? 'Unknown error'}");
      }
    } catch (e) {
       Fluttertoast.showToast(msg: "Error clearing cart: ${e.toString()}");
    }

  // Remove local sharedPreferences cart logic
  // sharedPreferences!.setStringList("userCart", ['garbageValue']);
}
