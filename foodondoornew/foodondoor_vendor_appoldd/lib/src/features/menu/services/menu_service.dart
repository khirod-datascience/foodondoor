import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:foodondoor_vendor_app/src/constants/api_constants.dart';
import 'package:foodondoor_vendor_app/src/features/menu/models/category_model.dart';
import 'package:foodondoor_vendor_app/src/features/menu/models/menu_item.dart';
import 'package:foodondoor_vendor_app/src/features/menu/models/restaurant.dart'; // Import Restaurant model
import 'package:foodondoor_vendor_app/src/features/auth/services/auth_service.dart'; // Import AuthService
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart'; // For looking up MIME types
import 'package:http_parser/http_parser.dart'; // For MediaType

class MenuService {
  final Dio _dio;
  final AuthService _authService; // Add AuthService dependency
  final FlutterSecureStorage _storage; // Add FlutterSecureStorage dependency

  MenuService(this._dio, this._authService, this._storage);

  // Helper to get restaurant ID (assuming it's stored after auth/setup)
  Future<String?> _getRestaurantId() async {
    // Implementation remains the same
  }

  // Helper method to get authenticated options
  Future<Options?> _getAuthOptions() async {
    final accessToken = await _authService.getAccessToken();
    if (accessToken == null) {
      print('Auth Error: No access token found.');
      return null;
    }
    return Options(headers: {'Authorization': 'Bearer $accessToken'});
  }

  /// Fetches the full restaurant details including menu (categories and items).
  /// Note: This might be redundant if menu items are fetched separately.
  Future<Map<String, dynamic>?> getRestaurantWithMenu() async {
    final options = await _getAuthOptions();
    if (options == null) return null;

    try {
      print('Fetching restaurant and menu data...');
      final response = await _dio.get(
        ApiConstants.vendorRestaurantUrl,
        options: options,
      );

      if (response.statusCode == 200) {
        print('Restaurant and menu data fetched successfully.');
        return response.data as Map<String, dynamic>;
      } else {
        print('Get Restaurant Error: Status code ${response.statusCode}, Data: ${response.data}');
        // Handle 404: Restaurant details not found
        return null;
      }
    } on DioException catch (e) {
      print('DioError fetching restaurant data: ${e.response?.statusCode} - ${e.response?.data ?? e.message}');
      // Handle 401, 404 etc.
      return null;
    } catch (e) {
      print('Unexpected error fetching restaurant data: $e');
      return null;
    }
  }

  // --- Menu Item CRUD Operations ---

  /// Fetches the list of menu items for the vendor.
  Future<List<MenuItem>> getMenuItems() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      final response = await _dio.get(
        ApiConstants.vendorMenuItemsUrl, // Correct constant for listing
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        // Ensure the fromJson factory matches the new structure with imageUrl, categoryName etc.
        return data.map((json) => MenuItem.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Failed to load menu items: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      // Handle Dio specific errors
      print('DioError fetching menu items: $e');
      throw Exception('Network error fetching menu items: ${e.message}');
    } catch (e) {
      print('Error fetching menu items: $e');
      throw Exception('Failed to load menu items. $e');
    }
  }

  // Add Menu Item - Takes Map, returns MenuItem? (nullable)
  Future<MenuItem?> addMenuItem(Map<String, dynamic> itemData, {XFile? imageFile}) async {
    try {
      final token = await _storage.read(key: 'auth_token');

      // Prepare data as FormData
      final formData = FormData.fromMap({
        ...itemData, // Spread existing MenuItem data
        if (imageFile != null) 
          'image': await MultipartFile.fromFile(
            imageFile.path, 
            filename: imageFile.name,
            contentType: MediaType.parse(lookupMimeType(imageFile.path) ?? 'image/jpeg'), // Use parsed MIME type
          ),
      });

      final response = await _dio.post(
        ApiConstants.vendorMenuItemsUrl, // Correct constant for adding
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 201) {
        // Parse the created item, including the new imageUrl from backend
        return MenuItem.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Failed to add menu item: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      print('DioError adding menu item: ${e.response?.data ?? e.message}');
      throw Exception('Network error adding menu item: ${e.response?.data['detail'] ?? e.message}');
    } catch (e) {
      print('Error adding menu item: $e');
      throw Exception('Failed to add menu item. $e');
    }
  }

  // Update Menu Item - Takes Map, returns MenuItem?
  Future<MenuItem?> updateMenuItem(String itemId, Map<String, dynamic> itemData, {XFile? imageFile}) async {
    try {
      final token = await _storage.read(key: 'auth_token');

      // Prepare data as FormData
      final formData = FormData.fromMap({
        ...itemData, // Spread existing MenuItem data
        if (imageFile != null) 
          'image': await MultipartFile.fromFile(
            imageFile.path, 
            filename: imageFile.name,
            contentType: MediaType.parse(lookupMimeType(imageFile.path) ?? 'image/jpeg'), // Use parsed MIME type
          ),
      });

      // Use PATCH for partial updates, including potentially just the image
      // Or use PUT if the backend expects the full resource representation
      final response = await _dio.patch( // Using PATCH is often better for updates
        ApiConstants.vendorMenuItemDetailUrl(itemId), // Correct URL for detail/update
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        // Parse the updated item, including the potentially new imageUrl
        return MenuItem.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Failed to update menu item: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      print('DioError updating menu item: ${e.response?.data ?? e.message}');
      throw Exception('Network error updating menu item: ${e.response?.data['detail'] ?? e.message}');
    } catch (e) {
      print('Error updating menu item: $e');
      throw Exception('Failed to update menu item. $e');
    }
  }

  // Delete Menu Item
  Future<bool> deleteMenuItem(String itemId) async {
    try {
      final token = await _storage.read(key: 'auth_token');
      final response = await _dio.delete(
        ApiConstants.vendorMenuItemDetailUrl(itemId), // Correct URL for delete
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 204) {
        // Success
        return true;
      } else {
        debugPrint('Failed to delete menu item: ${response.statusCode}');
        return false;
      }
    } on DioException catch (e) {
      debugPrint('Dio error deleting menu item: ${e.response?.statusCode} ${e.response?.data}');
      throw Exception('Failed to delete menu item: ${e.message}');
    } catch (e) {
      debugPrint('Error deleting menu item: $e');
      throw Exception('An unexpected error occurred.');
    }
  }
}
