import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class MenuItem {
  final String id;
  final String name;
  final double price;
  final String description;
  final bool isAvailable;
  final String category;
  final List<String> images;
  
  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.isAvailable,
    required this.category,
    required this.images,
  });
  
  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'].toString(),
      name: json['name'],
      price: double.parse(json['price'].toString()),
      description: json['description'] ?? '',
      isAvailable: json['is_available'] ?? true,
      category: json['category'] ?? 'General',
      images: (json['images'] as List<dynamic>?)?.map((img) => img.toString()).toList() ?? [],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'description': description,
      'is_available': isAvailable,
      'category': category,
      'images': images,
    };
  }
}

class MenuProvider with ChangeNotifier {
  List<MenuItem> _menuItems = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  List<MenuItem> get menuItems => [..._menuItems];
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // Get menu items by category
  Map<String, List<MenuItem>> getMenuItemsByCategory() {
    final categoryMap = <String, List<MenuItem>>{};
    
    for (var item in _menuItems) {
      if (!categoryMap.containsKey(item.category)) {
        categoryMap[item.category] = [];
      }
      categoryMap[item.category]!.add(item);
    }
    
    return categoryMap;
  }
  
  // Get a specific menu item
  MenuItem? getMenuItemById(String id) {
    try {
      return _menuItems.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }
  
  // Fetch all menu items for the vendor
  Future<void> fetchMenuItems() async {
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
        Uri.parse('${Config.baseUrl}/vendor/$vendorId/menu/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        _menuItems = data.map((item) => MenuItem.fromJson(item)).toList();
        _isLoading = false;
        notifyListeners();
      } else {
        _errorMessage = 'Failed to fetch menu items';
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'An error occurred: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Add a new menu item
  Future<bool> addMenuItem(MenuItem item, List<File>? imageFiles) async {
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
      
      // First create the menu item
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/vendor/$vendorId/menu/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode(item.toJson()),
      );
      
      if (response.statusCode == 201) {
        final newItemData = jsonDecode(response.body);
        final newItem = MenuItem.fromJson(newItemData);
        
        // If we have image files, upload them
        if (imageFiles != null && imageFiles.isNotEmpty) {
          // Upload logic would go here
          // This is a simplified example
        }
        
        _menuItems.add(newItem);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to add menu item';
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
  
  // Update a menu item
  Future<bool> updateMenuItem(String id, MenuItem updatedItem) async {
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
        Uri.parse('${Config.baseUrl}/vendor/$vendorId/menu/$id/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode(updatedItem.toJson()),
      );
      
      if (response.statusCode == 200) {
        final updatedItemData = jsonDecode(response.body);
        final updatedMenuItem = MenuItem.fromJson(updatedItemData);
        
        // Update the item in the local list
        final index = _menuItems.indexWhere((item) => item.id == id);
        if (index >= 0) {
          _menuItems[index] = updatedMenuItem;
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to update menu item';
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
  
  // Toggle availability of a menu item
  Future<bool> toggleAvailability(String id) async {
    try {
      final item = getMenuItemById(id);
      if (item == null) return false;
      
      final updatedItem = MenuItem(
        id: item.id,
        name: item.name,
        price: item.price,
        description: item.description,
        isAvailable: !item.isAvailable, // Toggle availability
        category: item.category,
        images: item.images,
      );
      
      return await updateMenuItem(id, updatedItem);
    } catch (e) {
      _errorMessage = 'An error occurred: $e';
      notifyListeners();
      return false;
    }
  }
  
  // Delete a menu item
  Future<bool> deleteMenuItem(String id) async {
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
      
      final response = await http.delete(
        Uri.parse('${Config.baseUrl}/vendor/$vendorId/menu/$id/'),
        headers: {
          'Authorization': 'Token $token',
        },
      );
      
      if (response.statusCode == 204) {
        // Remove the item from the local list
        _menuItems.removeWhere((item) => item.id == id);
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to delete menu item';
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