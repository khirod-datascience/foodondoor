import 'package:dio/dio.dart';
import 'package:foodondoor_vendor_app/src/constants/api_constants.dart';
import 'package:foodondoor_vendor_app/src/features/menu/models/category_model.dart';

// Provider definition will be handled in main.dart

class CategoryService {
  final Dio _dio; // Inject Dio via constructor

  CategoryService(this._dio);

  // Fetch categories for the vendor's restaurant
  Future<List<Category>> getCategories() async {
    try {
      final response = await _dio.get(ApiConstants.vendorCategoriesUrl);
      final List<dynamic> data = response.data as List<dynamic>;
      return data.map((json) => Category.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      // TODO: Handle DioError (e.g., logging, user feedback)
      print('Error fetching categories: $e');
      rethrow;
    }
  }

  // Add a new category - Changed to return bool
  Future<bool> addCategory(String name, {String? description}) async {
    try {
      await _dio.post(
        ApiConstants.vendorCategoriesUrl,
        data: {
          'name': name,
          if (description != null) 'description': description,
        },
      );
      return true; // Indicate success
    } on DioException catch (e) {
      print('Dio error adding category: ${e.response?.statusCode} ${e.response?.data}');
      // Consider throwing a more specific exception or returning false
      return false;
    } catch (e) {
      print('Error adding category: $e');
      return false;
    }
  }

  // Update an existing category - Changed to return bool
  Future<bool> updateCategory(String id, String name, {String? description}) async {
    try {
      await _dio.put(
        '${ApiConstants.vendorCategoriesUrl}$id/', // Append ID for update
        data: {
          'name': name,
          if (description != null) 'description': description,
        },
      );
      return true; // Indicate success
    } on DioException catch (e) {
      print('Dio error updating category: ${e.response?.statusCode} ${e.response?.data}');
      return false;
    } catch (e) {
      print('Error updating category: $e');
      return false;
    }
  }

  // Delete a category
  Future<bool> deleteCategory(String id) async {
    try {
      await _dio.delete('${ApiConstants.vendorCategoriesUrl}$id/'); // Append ID for delete
      return true;
    } on DioException catch (e) {
      print('Dio error deleting category: ${e.response?.statusCode} ${e.response?.data}');
      return false;
    } catch (e) {
      print('Error deleting category: $e');
      return false;
    }
  }
}
