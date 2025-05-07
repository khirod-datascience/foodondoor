import 'package:flutter/foundation.dart';
import 'package:foodondoor_vendor_app/src/features/restaurant/models/restaurant_model.dart';
import 'package:foodondoor_vendor_app/src/features/restaurant/services/restaurant_service.dart';

// Define possible states for the restaurant data fetching/updating
enum RestaurantStatus {
  initial,
  loading,
  loaded,
  error,
  updating, // Added status for update operations
  updateError // Added status for update errors
}

class RestaurantProvider with ChangeNotifier {
  final RestaurantService _restaurantService;

  Restaurant? _restaurant;
  RestaurantStatus _status = RestaurantStatus.initial;
  String? _errorMessage;

  RestaurantProvider(this._restaurantService);

  // Getters
  Restaurant? get restaurant => _restaurant;
  RestaurantStatus get status => _status;
  String? get errorMessage => _errorMessage;

  // Fetch restaurant details
  Future<void> fetchRestaurantDetails() async {
    if (_status == RestaurantStatus.loading) return; // Prevent concurrent loads

    print('[RestaurantProvider] Fetching restaurant details...');
    _status = RestaurantStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _restaurant = await _restaurantService.getRestaurantDetails();
      if (_restaurant != null) {
        _status = RestaurantStatus.loaded;
         print('[RestaurantProvider] Restaurant details loaded successfully.');
      } else {
        // This could mean 404 (no restaurant yet) or other fetch errors handled in service
        _status = RestaurantStatus.error;
        _errorMessage = 'Could not fetch restaurant details.'; // Generic message
         print('[RestaurantProvider] Failed to load restaurant details (restaurant is null).');
      }
    } catch (e) {
      _status = RestaurantStatus.error;
      _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      print('[RestaurantProvider] Error fetching restaurant details: $e');
    }
    notifyListeners();
  }

  // Update restaurant details
  Future<bool> updateRestaurantDetails(Map<String, dynamic> updateData) async {
     if (_status == RestaurantStatus.updating) return false; // Prevent concurrent updates
     if (_restaurant == null) {
       _errorMessage = 'Cannot update, no restaurant loaded.';
       _status = RestaurantStatus.updateError;
       notifyListeners();
       return false;
     }

    print('[RestaurantProvider] Updating restaurant details...');
    _status = RestaurantStatus.updating;
    _errorMessage = null;
    notifyListeners();

    try {
      // We don't need the restaurant ID here if the service updates based on auth
      final updatedRestaurant = await _restaurantService.updateRestaurantDetails(updateData);

      if (updatedRestaurant != null) {
        _restaurant = updatedRestaurant; // Update local state
        _status = RestaurantStatus.loaded; // Back to loaded after successful update
        print('[RestaurantProvider] Restaurant details updated successfully.');
        notifyListeners();
        return true;
      } else {
        _status = RestaurantStatus.updateError;
        _errorMessage = 'Failed to update restaurant details.';
        print('[RestaurantProvider] Failed to update restaurant details (service returned null).');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _status = RestaurantStatus.updateError;
      _errorMessage = 'An error occurred during update: ${e.toString()}';
      print('[RestaurantProvider] Error updating restaurant details: $e');
      notifyListeners();
      return false;
    }
  }
}
