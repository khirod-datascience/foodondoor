// lib/config/app_config.dart

class AppConfig {
  // IMPORTANT: Replace with your actual backend IP address when running on a physical device.
  // Find your computer's local IP (e.g., using ipconfig/ifconfig).
  // Ensure your device and computer are on the same network.
  // Also, make sure your Django server is running on 0.0.0.0 (e.g., python manage.py runserver 0.0.0.0:8000)
  static const String backendIpAddress = "192.168.225.54"; // <-- REPLACE THIS! Example IP
  static const String backendPort = "8000";

  // ---- Consolidated Base URL for Delivery Partner API ----
  static const String deliveryApiBaseUrl = "http://$backendIpAddress:$backendPort/api/delivery";

  // --- Remove or comment out old split URLs ---
  // // Base URL for authentication endpoints (OLD)
  // static const String authBaseUrl = "http://$backendIpAddress:$backendPort/api/delivery-auth";
  // // Base URL for general API endpoints (excluding auth) (OLD)
  // static const String apiBaseUrl = "http://$backendIpAddress:$backendPort/api";

  // Other configurations can go here (e.g., API keys, feature flags)
} 