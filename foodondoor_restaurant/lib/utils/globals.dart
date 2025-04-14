import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class Globals {
  // Global variables
  static String? vendorId;
  static String? authToken;
  
  // Initialization
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Log before reading
      debugPrint('(Globals.initialize) Reading from SharedPreferences...'); 
      vendorId = prefs.getString('vendor_id');
      authToken = prefs.getString('auth_token');
      // Log after reading
      debugPrint('(Globals.initialize) Read Vendor ID: $vendorId');
      debugPrint('(Globals.initialize) Read Auth Token: ${authToken != null}');
      
      print('Globals initialized:');
      print('Vendor ID: $vendorId');
      print('Auth Token: ${authToken != null ? 'Token exists' : 'No token'}');
    } catch (e) {
      print('Error initializing globals: $e');
      debugPrint('(Globals.initialize) Error: $e');
    }
  }
  
  // Save vendor credentials
  static Future<void> saveVendorCredentials(String id, String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Log before writing
      debugPrint('(Globals.save) Saving Vendor ID: $id, Token: ${token.isNotEmpty}');
      await prefs.setString('vendor_id', id);
      await prefs.setString('auth_token', token);
      // Log after writing
      debugPrint('(Globals.save) SharedPreferences write successful.');
      
      vendorId = id;
      authToken = token;
      
      print('Vendor credentials saved:');
      print('Vendor ID: $vendorId');
      print('Auth Token: ${authToken != null ? 'Token exists' : 'No token'}');
    } catch (e) {
      print('Error saving vendor credentials: $e');
      debugPrint('(Globals.save) Error: $e');
    }
  }
  
  // Clear vendor credentials
  static Future<void> clearVendorCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Log before removing
      debugPrint('(Globals.clear) Removing vendor_id and auth_token...');
      await prefs.remove('vendor_id');
      await prefs.remove('auth_token');
      // Log after removing
      debugPrint('(Globals.clear) SharedPreferences remove successful.');
      
      vendorId = null;
      authToken = null;
      
      print('Vendor credentials cleared');
    } catch (e) {
      print('Error clearing vendor credentials: $e');
      debugPrint('(Globals.clear) Error: $e');
    }
  }
}

// Convenience global variables for easier access
String? get globalVendorId => Globals.vendorId;
String? get globalToken => Globals.authToken;

// Setters that update both the global variables and the SharedPreferences
set globalVendorId(String? id) {
  if (id != null) {
    Globals.vendorId = id;
    SharedPreferences.getInstance().then((prefs) => prefs.setString('vendor_id', id));
  }
}

set globalToken(String? token) {
  if (token != null) {
    Globals.authToken = token;
    SharedPreferences.getInstance().then((prefs) => prefs.setString('auth_token', token));
  }
} 