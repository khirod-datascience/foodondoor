import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _fallbackTokenKey = 'auth_token_fallback';
  static const _customerIdKey = 'customer_id';
  static bool _secureStorageFailed = false;
  
  // Format the token if needed (some backends expect specific prefixes)
  static String _formatToken(String token) {
    // Remove any existing "Bearer " prefix to avoid duplicates
    if (token.startsWith('Bearer ')) {
      return token;
    }
    
    // If it's a JWT token format (base64 encoded with periods)
    if (token.contains('.') && RegExp(r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$').hasMatch(token)) {
      debugPrint('(AuthStorage) Token appears to be in JWT format');
      return token; // Return raw token, "Bearer " prefix will be added in API calls
    }
    
    // Return as is for other formats
    return token;
  }
  
  // Validate token format
  static bool _isValidToken(String? token) {
    if (token == null || token.isEmpty) {
      return false;
    }
    
    // Remove Bearer prefix if exists for validation
    final cleanToken = token.startsWith('Bearer ') ? token.substring(7) : token;
    
    // Check if it looks like a JWT (typical auth token format)
    final jwtPattern = RegExp(r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$');
    final isJwt = cleanToken.contains('.') && jwtPattern.hasMatch(cleanToken);
    
    // Check if it's a simple token (at least 10 chars with only valid chars)
    final simpleTokenPattern = RegExp(r'^[A-Za-z0-9_\-\.]+$');
    final isSimpleToken = cleanToken.length >= 10 && simpleTokenPattern.hasMatch(cleanToken);
    
    return isJwt || isSimpleToken;
  }

  // Save the access token (alias for saveToken)
  static Future<void> saveAccessToken(String token) async {
    await saveToken(token);
  }

  // Save the refresh token
  static Future<void> saveRefreshToken(String token) async {
    debugPrint('(AuthStorage) Saving refresh token...');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('refresh_token', token);
      debugPrint('(AuthStorage) Refresh token saved.');
    } catch (e) {
      debugPrint('(AuthStorage) Error saving refresh token: $e');
    }
  }

  // Retrieve the refresh token
  static Future<String?> getRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('refresh_token');
      debugPrint('(AuthStorage) Retrieved refresh token: ${token != null ? "exists" : "not found"}');
      return token;
    } catch (e) {
      debugPrint('(AuthStorage) Error retrieving refresh token: $e');
      return null;
    }
  }

  // Save the auth token
  static Future<void> saveToken(String token) async {
    debugPrint('(AuthStorage) Saving token...');
    debugPrint('(AuthStorage) Original token: ${token.substring(0, min(10, token.length))}...');
    
    // Format token before saving
    final formattedToken = _formatToken(token);
    debugPrint('(AuthStorage) Formatted token: ${formattedToken.substring(0, min(10, formattedToken.length))}...');
    
    if (!_isValidToken(formattedToken)) {
      debugPrint('(AuthStorage) WARNING: Token appears to be in an invalid format!');
    }
    
    if (!_secureStorageFailed) {
      try {
        // Try to use secure storage first
        await _storage.write(key: _tokenKey, value: formattedToken);
        debugPrint('(AuthStorage) Token saved to secure storage.');
        
        // Verify it was saved correctly
        final savedToken = await _storage.read(key: _tokenKey);
        if (savedToken != formattedToken) {
          debugPrint('(AuthStorage) WARNING: Saved token verification failed!');
          _secureStorageFailed = true;
        }
      } catch (e) {
        debugPrint('(AuthStorage) Error saving to secure storage: $e');
        _secureStorageFailed = true;
      }
    }
    
    // Fall back to SharedPreferences if necessary
    if (_secureStorageFailed) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_fallbackTokenKey, formattedToken);
        debugPrint('(AuthStorage) Token saved to SharedPreferences as fallback.');
        
        // Verify it was saved in SharedPreferences
        final savedToken = prefs.getString(_fallbackTokenKey);
        if (savedToken != formattedToken) {
          debugPrint('(AuthStorage) WARNING: Even SharedPreferences saving failed verification!');
        }
      } catch (e) {
        debugPrint('(AuthStorage) Critical error: Both storage methods failed: $e');
        // At this point, we can't store the token
      }
    }
  }

  // Retrieve the auth token
  static Future<String?> getToken() async {
    String? token;
    bool secureStorageError = false;
    
    // Try secure storage first if it hasn't failed before
    if (!_secureStorageFailed) {
      try {
        token = await _storage.read(key: _tokenKey);
        if (token != null) {
          debugPrint('(AuthStorage) Retrieved token from secure storage: ${token.substring(0, min(10, token.length))}...');
        } else {
          debugPrint('(AuthStorage) No token found in secure storage');
        }
      } catch (e) {
        debugPrint('(AuthStorage) Error retrieving from secure storage: $e');
        secureStorageError = true;
        _secureStorageFailed = true;
      }
    } else {
      secureStorageError = true;
    }
    
    // If we couldn't get from secure storage or it failed previously, try SharedPreferences
    if (token == null || secureStorageError) {
      try {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString(_fallbackTokenKey);
        if (token != null) {
          debugPrint('(AuthStorage) Retrieved token from SharedPreferences fallback: ${token.substring(0, min(10, token.length))}...');
        } else {
          debugPrint('(AuthStorage) No token found in SharedPreferences fallback either.');
        }
      } catch (e) {
        debugPrint('(AuthStorage) Error retrieving from SharedPreferences: $e');
      }
    }
    
    // Validate the token format
    if (token != null && !_isValidToken(token)) {
      debugPrint('(AuthStorage) WARNING: Retrieved token appears to be invalid!');
      // Consider returning null for clearly invalid tokens
    }
    
    return token;
  }

  // Delete the auth token
  static Future<void> deleteToken() async {
    debugPrint('(AuthStorage) Deleting token...');
    
    // Try to delete from secure storage
    try {
      await _storage.delete(key: _tokenKey);
      debugPrint('(AuthStorage) Token deleted from secure storage.');
    } catch (e) {
      debugPrint('(AuthStorage) Error deleting from secure storage: $e');
    }
    
    // Also delete from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_fallbackTokenKey);
      debugPrint('(AuthStorage) Token deleted from SharedPreferences fallback.');
    } catch (e) {
      debugPrint('(AuthStorage) Error deleting from SharedPreferences: $e');
    }
  }
  
  // Test if storage is working correctly
  static Future<bool> testStorage() async {
    debugPrint('(AuthStorage) Testing storage functionality...');
    
    const testValue = 'storage_test_token';
    bool secureStorageWorks = false;
    bool sharedPrefsWorks = false;
    
    // Test secure storage
    try {
      await _storage.write(key: 'test_key', value: testValue);
      final readBack = await _storage.read(key: 'test_key');
      secureStorageWorks = (readBack == testValue);
      debugPrint('(AuthStorage) Secure storage test result: ${secureStorageWorks ? "SUCCESS" : "FAILED"}');
      await _storage.delete(key: 'test_key');
    } catch (e) {
      debugPrint('(AuthStorage) Secure storage test error: $e');
      secureStorageWorks = false;
    }
    
    // Test SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('test_prefs_key', testValue);
      final readBack = prefs.getString('test_prefs_key');
      sharedPrefsWorks = (readBack == testValue);
      debugPrint('(AuthStorage) SharedPreferences test result: ${sharedPrefsWorks ? "SUCCESS" : "FAILED"}');
      await prefs.remove('test_prefs_key');
    } catch (e) {
      debugPrint('(AuthStorage) SharedPreferences test error: $e');
      sharedPrefsWorks = false;
    }
    
    _secureStorageFailed = !secureStorageWorks;
    debugPrint('(AuthStorage) Primary storage method: ${_secureStorageFailed ? "SharedPreferences" : "SecureStorage"}');
    
    return secureStorageWorks || sharedPrefsWorks;
  }
  
  // Helper function to get min value (like Math.min)
  static int min(int a, int b) {
    return a < b ? a : b;
  }

  // Save customer ID
  static Future<void> saveCustomerId(String customerId) async {
    debugPrint('(AuthStorage) Saving customer ID: $customerId');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_customerIdKey, customerId);
      
      // Verify it was saved correctly
      final savedId = prefs.getString(_customerIdKey);
      if (savedId != customerId) {
        debugPrint('(AuthStorage) WARNING: Saved customer ID verification failed!');
      } else {
        debugPrint('(AuthStorage) Customer ID saved successfully');
      }
    } catch (e) {
      debugPrint('(AuthStorage) Error saving customer ID: $e');
      // Try again as a fallback
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_customerIdKey, customerId);
        debugPrint('(AuthStorage) Customer ID saved on retry');
      } catch (e2) {
        debugPrint('(AuthStorage) Critical error saving customer ID: $e2');
      }
    }
  }

  // Get customer ID
  static Future<String?> getCustomerId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customerId = prefs.getString(_customerIdKey);
      if (customerId != null && customerId.isNotEmpty) {
        debugPrint('(AuthStorage) Retrieved customer ID: $customerId');
      } else {
        debugPrint('(AuthStorage) No customer ID found');
      }
      return customerId;
    } catch (e) {
      debugPrint('(AuthStorage) Error retrieving customer ID: $e');
      return null;
    }
  }

  // Clear all auth data
  static Future<void> clearAuthData() async {
    debugPrint('(AuthStorage) Clearing all auth data');
    try {
      // Remove secure token
      await deleteToken();
      
      // Remove customer ID from preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_customerIdKey);
      await prefs.remove(_fallbackTokenKey);
      
      debugPrint('(AuthStorage) All auth data cleared successfully');
    } catch (e) {
      debugPrint('(AuthStorage) Error clearing auth data: $e');
    }
  }

  // Save the auth token
  static Future<void> saveAuthToken(String token) async {
    debugPrint('(AuthStorage) Saving auth token...');
    await saveToken(token);
  }

  // Get the auth token
  static Future<String?> getAuthToken() async {
    debugPrint('(AuthStorage) Getting auth token...');
    return await getToken();
  }

  // Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final token = await getToken();
    final customerId = await getCustomerId();
    
    final isAuth = token != null && token.isNotEmpty && 
                  customerId != null && customerId.isNotEmpty;
    
    debugPrint('(AuthStorage) Authentication check: ${isAuth ? "Authenticated" : "Not authenticated"}');
    return isAuth;
  }
}
