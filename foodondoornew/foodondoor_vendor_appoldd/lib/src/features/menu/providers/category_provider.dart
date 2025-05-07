import 'package:flutter/material.dart' hide Category;
import 'package:provider/provider.dart';
import 'package:foodondoor_vendor_app/src/features/menu/models/category_model.dart';
import 'package:foodondoor_vendor_app/src/features/menu/services/category_service.dart';

// Provider definition will be handled in main.dart

class CategoryNotifier extends ChangeNotifier {
  final CategoryService _categoryService;

  List<Category> _categories = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isMutating = false;

  CategoryNotifier(this._categoryService) {
    fetchCategories();
  }

  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isMutating => _isMutating;

  Future<void> fetchCategories() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final categories = await _categoryService.getCategories();
      _categories = categories;
    } catch (e, stackTrace) {
      print('Error fetching categories: $e\n$stackTrace');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addCategory(String name, {String? description}) async {
    _errorMessage = null;
    _isMutating = true;
    notifyListeners();
    bool success = false;
    try {
      final bool added = await _categoryService.addCategory(name, description: description);
      if (added) {
        await fetchCategories(); // Refresh the list from the server
        success = true;
      } else {
        _errorMessage = 'Failed to add category on server.'; // Set specific error
        success = false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      success = false;
    } finally {
      _isMutating = false;
      notifyListeners();
    }
    return success;
  }

  Future<bool> updateCategory(String id, String name, {String? description}) async {
    _errorMessage = null;
    _isMutating = true;
    notifyListeners();
    bool success = false;
    try {
      final updated = await _categoryService.updateCategory(id, name, description: description);
      if (updated) {
        await fetchCategories();
        success = true;
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      success = false;
    } finally {
      _isMutating = false;
      notifyListeners();
    }
    return success;
  }

  Future<bool> deleteCategory(String id) async {
    _errorMessage = null;
    _isMutating = true;
    notifyListeners();
    bool success = false;
    try {
      final deleted = await _categoryService.deleteCategory(id);
      if (deleted) {
        _categories.removeWhere((Category cat) => cat.id == id);
        success = true;
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      success = false;
    } finally {
      _isMutating = false;
      notifyListeners();
    }
    return success;
  }
}
