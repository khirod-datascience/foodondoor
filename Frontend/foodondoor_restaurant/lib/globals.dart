import 'package:shared_preferences/shared_preferences.dart';

// DEPRECATED: Use package:foodondoor_restaurant/utils/globals.dart instead
// This file should not be used anywhere. It is kept only for legacy reasons.
// Throw an error if imported.

@deprecated
class Globals {
  Globals._() {
    throw UnsupportedError('Do not use lib/globals.dart. Use package:foodondoor_restaurant/utils/globals.dart');
  }

  static String? vendorId;  // Changed from int? to String?
  
  // Method to save vendorId to shared preferences
  static Future<bool> saveVendorId(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('vendorId', id);
      vendorId = id;
      print("Saved vendorId to SharedPreferences: $id");
      return true;
    } catch (e) {
      print("Error saving vendorId: $e");
      return false;
    }
  }
  
  // Method to load vendorId from shared preferences
  static Future<String?> loadVendorId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString('vendorId');
      if (id != null && id.isNotEmpty) {
        vendorId = id;
        print("Loaded vendorId from SharedPreferences: $id");
      }
      return id;
    } catch (e) {
      print("Error loading vendorId: $e");
      return null;
    }
  }
  
  // Method to clear vendorId (for logout)
  static Future<bool> clearVendorId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('vendorId');
      vendorId = null;
      print("Cleared vendorId from SharedPreferences");
      return true;
    } catch (e) {
      print("Error clearing vendorId: $e");
      return false;
    }
  }
}