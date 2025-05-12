import 'package:shared_preferences/shared_preferences.dart';
// Purpose: Contains global variables and utility functions for the application.

import 'package:flutter/foundation.dart';
import 'auth_storage.dart'; // Import for token clearing

String? globalCustomerId;

// Add a global variable for the currently selected address map
Map<String, dynamic>? globalCurrentAddress; // e.g., {'id': 'addr1', 'address_line1': '123 Main St', ...}

const String _currentAddressPrefKey = 'current_address_id';

// Function to save the ID of the currently selected address
Future<void> saveCurrentAddressId(String? addressId) async {
  final prefs = await SharedPreferences.getInstance();
  if (addressId == null) {
    await prefs.remove(_currentAddressPrefKey);
    debugPrint('Cleared saved address ID preference.');
  } else {
    await prefs.setString(_currentAddressPrefKey, addressId);
    debugPrint('Saved address ID preference: $addressId');
  }
}

// Function to load the saved address ID
Future<String?> loadCurrentAddressId() async {
  final prefs = await SharedPreferences.getInstance();
  final addressId = prefs.getString(_currentAddressPrefKey);
  debugPrint('Loaded address ID preference: $addressId');
  return addressId;
}

// Function to clear globals on logout
Future<void> clearGlobalData() async {
  debugPrint('============= LOGOUT: CLEARING USER DATA =============');
  // Clear memory variables
  globalCustomerId = null;
  globalCurrentAddress = null;
  
  // Clear auth tokens first
  try {
    await AuthStorage.deleteToken();
    debugPrint('Auth tokens deleted from secure storage and SharedPreferences');
  } catch (e) {
    debugPrint('Error while clearing auth tokens: $e');
  }
  
  // Get SharedPreferences instance
  final prefs = await SharedPreferences.getInstance();
  
  // Log what we're about to clear
  final existingKeys = prefs.getKeys();
  debugPrint('Found ${existingKeys.length} keys in SharedPreferences: $existingKeys');
  
  // Clear all known keys related to user data
  final keysToRemove = [
    _currentAddressPrefKey,
    'customer_id',
    'auth_token',
    'auth_token_fallback',
    'user_name',
    'user_email',
    'user_phone',
  ];
  
  for (final key in keysToRemove) {
    if (prefs.containsKey(key)) {
      await prefs.remove(key);
      debugPrint('Removed key from SharedPreferences: $key');
    } else {
      debugPrint('Key not found in SharedPreferences: $key');
    }
  }
  
  // Verify keys were removed
  final remainingKeys = prefs.getKeys();
  final remainingUserKeys = remainingKeys.where((key) => 
    key.contains('auth') || 
    key.contains('token') || 
    key.contains('customer') || 
    key.contains('user') ||
    key.contains('address')
  ).toList();
  
  if (remainingUserKeys.isNotEmpty) {
    debugPrint('WARNING: Some user-related keys still remain: $remainingUserKeys');
  } else {
    debugPrint('Successfully cleared all user-related keys from SharedPreferences');
  }
  
  debugPrint('User data cleared - logout complete');
  debugPrint('======================================================');
}