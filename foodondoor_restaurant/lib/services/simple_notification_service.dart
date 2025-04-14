import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/globals.dart';
import '../config.dart';

/// A simplified notification service that uses polling to fetch notifications
/// without requiring Firebase or flutter_local_notifications
class SimpleNotificationService {
  // Singleton instance
  static final SimpleNotificationService _instance = SimpleNotificationService._();
  static SimpleNotificationService get instance => _instance;
  
  // Device token (can be device ID or any unique identifier)
  String? _deviceToken;
  String? get deviceToken => _deviceToken;
  
  // Stream controller for all notifications
  final StreamController<Map<String, dynamic>> _notificationsController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  // Public stream for notifications
  Stream<Map<String, dynamic>> get notifications => _notificationsController.stream;
  
  // Timer for polling
  Timer? _pollingTimer;
  
  // Private constructor
  SimpleNotificationService._();
  
  // Initialize notification service
  Future<void> initialize() async {
    try {
      print('Initializing simple notification service...');
      
      // Generate a device token based on device info or use a random UUID
      await _generateDeviceToken();
      
      // Register token if vendor is logged in
      final prefs = await SharedPreferences.getInstance();
      final savedVendorId = prefs.getString('vendor_id');
      final savedToken = prefs.getString('auth_token');
      
      if (savedVendorId != null && savedToken != null) {
        await _updateTokenOnServer(savedVendorId, savedToken);
        // Start polling for notifications
        _startPolling();
      }
      
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }
  
  // Generate a unique device token
  Future<void> _generateDeviceToken() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if we already have a device token stored
    _deviceToken = prefs.getString('device_token');
    
    if (_deviceToken == null) {
      // Generate a simple unique ID - in production, use a proper device ID library
      _deviceToken = 'vendor_app_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('device_token', _deviceToken!);
    }
    
    print('Device Token: $_deviceToken');
  }
  
  // Start polling for notifications
  void _startPolling() {
    // Cancel any existing timer
    _pollingTimer?.cancel();
    
    // Poll every 30 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchNotifications();
    });
    
    // Initial fetch
    _fetchNotifications();
  }
  
  // Fetch notifications from server
  Future<void> _fetchNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVendorId = prefs.getString('vendor_id');
      final savedToken = prefs.getString('auth_token');
      
      if (savedVendorId == null || savedToken == null) {
        print('Cannot fetch notifications: Not logged in');
        _pollingTimer?.cancel();
        return;
      }
      
      // Get last notification timestamp
      final lastTimestamp = prefs.getString('last_notification_timestamp') ?? '';
      
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/vendors/$savedVendorId/notifications/?since=$lastTimestamp'),
        headers: {
          'Authorization': 'Token $savedToken',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> notifications = data['notifications'] ?? [];
        
        // Process each notification
        if (notifications.isNotEmpty) {
          // Update last timestamp
          String? newTimestamp;
          
          for (final notification in notifications) {
            // Handle notification
            _handleNotificationData(notification);
            
            // Keep track of newest timestamp
            final timestamp = notification['timestamp'];
            if (timestamp != null && (newTimestamp == null || timestamp.compareTo(newTimestamp) > 0)) {
              newTimestamp = timestamp;
            }
          }
          
          // Save newest timestamp
          if (newTimestamp != null) {
            await prefs.setString('last_notification_timestamp', newTimestamp);
          }
        }
      } else {
        print('Failed to fetch notifications: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error fetching notifications: $e');
    }
  }
  
  void _handleNotificationData(Map<String, dynamic> notificationData) {
    print('Processing notification data: $notificationData');
    
    // Broadcast notification to all listeners
    _notificationsController.add(notificationData);
  }
  
  // Update device token on server
  Future<void> _updateTokenOnServer(String vendorId, String authToken) async {
    try {
      if (_deviceToken == null) {
        print('Cannot update device token: Token is null');
        return;
      }
      
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/auth/vendors/$vendorId/device-token/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $authToken',
        },
        body: jsonEncode({
          'vendor_id': vendorId,
          'device_token': _deviceToken,
          'device_type': 'vendor_app'
        }),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Device token updated on server successfully');
      } else {
        print('Failed to update device token on server: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error updating device token on server: $e');
    }
  }
  
  // Clean up device token on logout
  Future<void> clearDeviceToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVendorId = prefs.getString('vendor_id');
      final savedToken = prefs.getString('auth_token');
      
      if (savedVendorId != null && savedToken != null && _deviceToken != null) {
        // Send empty token to server to unregister this device
        final response = await http.post(
          Uri.parse('${Config.baseUrl}/auth/vendors/$savedVendorId/device-token/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Token $savedToken',
          },
          body: jsonEncode({
            'vendor_id': savedVendorId,
            'device_token': '', // Empty token to unregister
            'device_type': 'vendor_app'
          }),
        );
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          print('Device token cleared on server successfully');
        } else {
          print('Failed to clear device token on server: ${response.statusCode} ${response.body}');
        }
      }
      
      // Stop polling
      _pollingTimer?.cancel();
    } catch (e) {
      print('Error clearing device token: $e');
    }
  }
  
  // Manual refresh method
  Future<void> refreshNotifications() async {
    await _fetchNotifications();
  }
  
  // Dispose resources
  void dispose() {
    _pollingTimer?.cancel();
    _notificationsController.close();
  }
} 