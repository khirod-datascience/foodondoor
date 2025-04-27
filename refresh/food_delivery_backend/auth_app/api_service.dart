import 'package:flutter/foundation.dart';

class ApiService {
  // New method to delete a specific item
  Future<Map<String, dynamic>> deleteItem(String itemId) async {
    final String endpoint = '/vendor_auth/vendor/items/$itemId/';
    debugPrint('Attempting to delete item $itemId...');
    return await delete(endpoint);
  }

  // New method to add an item to a specific menu
  Future<Map<String, dynamic>> addItemToMenu(String menuId, Map<String, dynamic> itemData) async {
    // Adjust endpoint based on your backend URL structure
    final String endpoint = '/vendor_auth/vendor/menus/$menuId/items/';
    debugPrint('Attempting to add item to menu $menuId...');
    // Use the generic post method which handles authentication
    return await post(endpoint, itemData);
  }

  // --- Generic Request Helpers ---
} 