import 'package:flutter/foundation.dart';
// Purpose: Manages the state of the shopping cart, including adding, removing, and updating item quantities, and persisting the cart.

import 'dart:collection';
import 'dart:convert'; // For JSON encoding/decoding
import 'package:shared_preferences/shared_preferences.dart'; // For persistence

class CartProvider with ChangeNotifier {
  Map<String, Map<String, dynamic>> _items = {};
  static const _cartPrefKey = 'cart_items';
  bool _isInitialized = false;
  String? _currentRestaurantId; // Track the current restaurant's ID

  CartProvider() {
    _initializeCart();
  }

  Future<void> _initializeCart() async {
    if (!_isInitialized) {
      await _loadCartFromPrefs();
      _isInitialized = true;
      _determineCurrentRestaurant(); // Set current restaurant ID based on loaded items
      notifyListeners();
    }
  }

  // Determine the current restaurant ID based on cart items
  void _determineCurrentRestaurant() {
    if (_items.isEmpty) {
      _currentRestaurantId = null;
    } else {
      // Find the first item with a valid vendor_id and use it
      for (var item in _items.values) {
        if (item['vendor_id'] != null) {
          _currentRestaurantId = item['vendor_id'].toString();
          break;
        }
      }
    }
    debugPrint('(CartProvider) Current restaurant ID: $_currentRestaurantId');
  }

  // Get current restaurant ID
  String? get currentRestaurantId => _currentRestaurantId;

  // Check if item is from same restaurant
  bool isFromSameRestaurant(String? vendorId) {
    if (_currentRestaurantId == null || vendorId == null) {
      return true; // If cart is empty or item has no vendor, allow adding
    }
    return _currentRestaurantId == vendorId;
  }

  // Get restaurant name (if available in cart)
  String? get currentRestaurantName {
    for (var item in _items.values) {
      if (item.containsKey('restaurant_name') && item['restaurant_name'] != null) {
        return item['restaurant_name'].toString();
      }
    }
    return null;
  }

  UnmodifiableMapView<String, Map<String, dynamic>> get items {
    if (!_isInitialized) {
      debugPrint('(CartProvider) Warning: Accessing items before initialization');
      return UnmodifiableMapView({});
    }
    return UnmodifiableMapView(_items);
  }

  int get itemCount {
    if (!_isInitialized) return 0;
    return _items.length;
  }

  double get totalAmount {
    if (!_isInitialized) return 0.0;
    var total = 0.0;
    _items.forEach((key, cartItem) {
      final price = (cartItem['price'] as num?)?.toDouble() ?? 0.0;
      final quantity = (cartItem['quantity'] as num?)?.toInt() ?? 0;
      total += price * quantity;
    });
    return total;
  }

  Future<Map<String, dynamic>> addToCart(Map<String, dynamic> foodItem) async {
    await _initializeCart();
    final String? itemId = foodItem['id']?.toString();
    if (itemId == null) {
      debugPrint('(CartProvider) Error: Attempted to add item with null ID.');
      return {'success': false, 'error': 'Item ID is missing'};
    }

    final String? vendorId = foodItem['vendor_id']?.toString();
    
    // Check if this item is from a different restaurant than what's already in cart
    if (_items.isNotEmpty && !isFromSameRestaurant(vendorId)) {
      return {
        'success': false, 
        'error': 'Items from multiple restaurants cannot be added to the same order',
        'currentRestaurantName': currentRestaurantName
      };
    }

    if (_items.containsKey(itemId)) {
      _items.update(itemId, (existingCartItem) {
        final currentQuantity = (existingCartItem['quantity'] as num?)?.toInt() ?? 0;
        return {
          ...existingCartItem,
          'quantity': currentQuantity + 1,
        };
      });
      debugPrint('(CartProvider) Increased quantity for item: $itemId');
    } else {
      _items.putIfAbsent(itemId, () => {
        'id': itemId,
        'name': foodItem['name']?.toString() ?? 'Unknown Item',
        'price': (foodItem['price'] as num?)?.toDouble() ?? 0.0,
        'image': foodItem['image']?.toString() ?? '',
        'vendor_id': vendorId,
        'restaurant_name': foodItem['restaurant_name']?.toString() ?? null,
        'quantity': 1,
      });
      
      // Update current restaurant ID if it's the first item
      if (_currentRestaurantId == null && vendorId != null) {
        _currentRestaurantId = vendorId;
      }
      
      debugPrint('(CartProvider) Added new item to cart: $itemId from restaurant: $vendorId');
    }
    await _saveCartAndNotify();
    return {'success': true};
  }

  Future<void> increaseQuantity(String itemId) async {
    await _initializeCart();
    if (_items.containsKey(itemId)) {
      _items.update(itemId, (existingCartItem) {
        final currentQuantity = (existingCartItem['quantity'] as num?)?.toInt() ?? 0;
        return {
          ...existingCartItem,
          'quantity': currentQuantity + 1,
        };
      });
      await _saveCartAndNotify();
    } else {
      debugPrint('(CartProvider) Warning: Tried to increase quantity for non-existent item $itemId');
    }
  }

  Future<void> decreaseQuantity(String itemId) async {
    await _initializeCart();
    if (!_items.containsKey(itemId)) {
      debugPrint('(CartProvider) Warning: Tried to decrease quantity for non-existent item $itemId');
      return;
    }

    final currentQuantity = (_items[itemId]!['quantity'] as num?)?.toInt() ?? 0;
    if (currentQuantity > 1) {
      _items.update(itemId, (existingCartItem) => {
        ...existingCartItem,
        'quantity': currentQuantity - 1,
      });
    } else {
      _items.remove(itemId);
      if (_items.isEmpty) {
        _currentRestaurantId = null; // Reset restaurant ID if cart is now empty
      }
    }
    await _saveCartAndNotify();
  }

  Future<void> removeFromCart(String itemId) async {
    await _initializeCart();
    if (_items.containsKey(itemId)) {
      _items.remove(itemId);
      if (_items.isEmpty) {
        _currentRestaurantId = null; // Reset restaurant ID if cart is now empty
      } else {
        _determineCurrentRestaurant(); // Re-determine the restaurant ID
      }
      await _saveCartAndNotify();
      debugPrint('(CartProvider) Removed item from cart: $itemId');
    } else {
      debugPrint('(CartProvider) Warning: Tried to remove non-existent item $itemId');
    }
  }

  Future<void> clearCart() async {
    await _initializeCart();
    _items.clear();
    _currentRestaurantId = null; // Reset restaurant ID
    await _saveCartAndNotify();
    debugPrint('(CartProvider) Cart cleared.');
  }

  Future<void> _saveCartAndNotify() async {
    try {
      await _saveCartToPrefs();
      notifyListeners();
    } catch (e) {
      debugPrint('(CartProvider) Error in _saveCartAndNotify: $e');
      // Still notify listeners even if save fails
      notifyListeners();
    }
  }

  Future<void> _saveCartToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encodedData = json.encode(_items);
      await prefs.setString(_cartPrefKey, encodedData);
      debugPrint('(CartProvider) Cart saved to preferences.');
    } catch (e) {
      debugPrint('(CartProvider) Error saving cart to preferences: $e');
      rethrow; // Rethrow to handle in _saveCartAndNotify
    }
  }

  Future<void> _loadCartFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? encodedData = prefs.getString(_cartPrefKey);
      debugPrint('(CartProvider) Loading cart data: $encodedData');

      if (encodedData != null && encodedData.isNotEmpty) {
        final Map<String, dynamic> decodedData = json.decode(encodedData);
        
        _items = decodedData.map((key, value) {
          if (value is Map) {
            return MapEntry(key, Map<String, dynamic>.from(value));
          }
          debugPrint('(CartProvider) Error decoding cart item $key: Inner value is not a Map.');
          return MapEntry(key, <String, dynamic>{});
        });
        
        debugPrint('(CartProvider) Cart loaded successfully: ${_items.length} items.');
        _determineCurrentRestaurant();
      } else {
        debugPrint('(CartProvider) No saved cart data found.');
        _items = {};
      }
    } catch (e) {
      debugPrint('(CartProvider) Error loading cart from preferences: $e');
      _items = {};
    }
  }
} 