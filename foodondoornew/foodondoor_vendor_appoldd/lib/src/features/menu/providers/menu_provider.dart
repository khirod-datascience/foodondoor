import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:foodondoor_vendor_app/src/features/menu/models/menu_item.dart';
import 'package:foodondoor_vendor_app/src/features/menu/services/menu_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:collection/collection.dart'; // Import for firstWhereOrNull

// Enum for different states of the menu data
enum MenuStateStatus { initial, loading, loaded, itemLoading, notFound, error }

// State Notifier for Menu Items
class MenuNotifier extends ChangeNotifier {
  final MenuService _menuService;

  List<MenuItem> _menuItems = [];
  MenuStateStatus _status = MenuStateStatus.initial;
  String? _errorMessage;
  bool _isItemLoading = false; // For specific item add/update/delete

  MenuNotifier(this._menuService) {
    fetchMenuItems(); // Fetch data initially
  }

  // Getters
  List<MenuItem> get menuItems => _menuItems;
  MenuStateStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == MenuStateStatus.loading; // General loading
  bool get isItemLoading => _isItemLoading; // Item-specific loading

  /// Fetches the menu items for the vendor.
  Future<void> fetchMenuItems() async {
    if (_status == MenuStateStatus.loading) return; // Prevent concurrent fetches

    _status = MenuStateStatus.loading;
    _errorMessage = null;
    notifyListeners(); // Notify start of loading

    try {
      _menuItems = await _menuService.getMenuItems(); // Call without args
      _status = MenuStateStatus.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _status = MenuStateStatus.error;
    } finally {
      notifyListeners(); // Notify end of loading (success or error)
    }
  }

  // Add Menu Item - Takes Map, returns bool
  Future<bool> addMenuItem(Map<String, dynamic> itemData, {XFile? imageFile}) async {
    _isItemLoading = true;
    _errorMessage = null;
    notifyListeners();
    bool success = false;
    try {
      final newItem = await _menuService.addMenuItem(itemData, imageFile: imageFile);
      if (newItem != null) {
        _menuItems.insert(0, newItem); // Add to list optimistically or after success
        success = true;
      } else {
        _errorMessage = "Failed to add item (server error).";
      }
    } catch (e) {
      _errorMessage = "Failed to add item: ${e.toString()}";
      success = false;
    } finally {
      _isItemLoading = false;
      _status = MenuStateStatus.loaded; // Reset main status
      notifyListeners();
    }
    return success;
  }

  // Update Menu Item - Takes Map, returns bool
  Future<bool> updateMenuItem(String itemId, Map<String, dynamic> itemData, {XFile? imageFile}) async {
    _isItemLoading = true;
    _errorMessage = null;
    notifyListeners();
    bool success = false;
    MenuItem? originalItem = _menuItems.firstWhereOrNull((item) => item.id == itemId);

    int? originalIndex;

    if (originalItem != null) {
      originalIndex = _menuItems.indexOf(originalItem);
    }

    try {
      // Optimistic UI update (optional but good UX)
      if (originalItem != null) {
        final updatedPreview = MenuItem(
          id: itemId,
          name: itemData['name'] ?? originalItem.name,
          description: itemData['description'] ?? originalItem.description,
          price: itemData['price'] ?? originalItem.price,
          categoryId: itemData['category'] ?? originalItem.categoryId,
          isAvailable: itemData['is_available'] ?? originalItem.isAvailable,
          imageUrl: originalItem.imageUrl, // Keep old image URL for preview
          restaurantId: originalItem.restaurantId, // Add restaurantId from original
          isVegetarian: itemData['is_vegetarian'] ?? originalItem.isVegetarian,
          categoryName: originalItem.categoryName,
          createdAt: originalItem.createdAt // Add createdAt from original item
        );

        if (originalIndex != null) { // Add null check
          _menuItems[originalIndex] = updatedPreview; // Optimistically update UI
        }
        notifyListeners();
      }

      final updatedItemFromServer = await _menuService.updateMenuItem(itemId, itemData, imageFile: imageFile);

      if (updatedItemFromServer != null) {
        if (originalIndex != null) { // Use final index
          _menuItems[originalIndex] = updatedItemFromServer; // Update with server data
        }
        success = true;
      } else {
        _errorMessage = "Failed to update item (server error).";
        // Revert optimistic update if needed
        if (originalItem != null) {
          if (originalIndex != null) { // Add null check
            _menuItems[originalIndex] = originalItem;
          }
        }
      }
    } catch (e) {
      _errorMessage = "Failed to update item: ${e.toString()}";
      success = false;
      // Revert optimistic update
      if (originalItem != null) {
        if (originalIndex != null) { // Add null check
          _menuItems[originalIndex] = originalItem;
        }
      }
    } finally {
      _isItemLoading = false;
      _status = MenuStateStatus.loaded;
      notifyListeners();
    }
    return success;
  }

  // Delete Menu Item
  Future<bool> deleteMenuItem(String itemId) async {
    _isItemLoading = true;
    _errorMessage = null;
    notifyListeners();
    bool success = false;
    try {
      await _menuService.deleteMenuItem(itemId);
      _menuItems.removeWhere((item) => item.id == itemId);
      success = true;
    } catch (e) {
      _errorMessage = "Failed to delete item: ${e.toString()}";
      success = false;
    } finally {
      _isItemLoading = false;
      _status = MenuStateStatus.loaded;
      notifyListeners();
    }
    return success;
  }
}
