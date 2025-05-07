class ApiConstants {
  static const String baseUrl = 'http://10.0.2.2:8000/api'; // Use 10.0.2.2 for Android emulator
  static const String apiBaseUrl = '$baseUrl'; // Removed /v1 suffix

  // Core Auth
  static const String sendOtpUrl = '$apiBaseUrl/core/auth/send-otp/';
  static const String verifyOtpUrl = '$apiBaseUrl/core/auth/verify-otp/';
  static const String refreshTokenUrl = '$apiBaseUrl/core/auth/token/refresh/';

  // Vendor Auth & Profile
  static const String vendorRegisterUrl = '$baseUrl/vendor/auth/register/';
  static const String vendorProfileUrl = '$apiBaseUrl/vendor/profile/';
  static const String vendorProfileUpdateUrl = '$apiBaseUrl/vendor/profile/update/'; // Placeholder, might not be needed if separate restaurant

  // Vendor Restaurant Management
  static const String vendorRestaurantUrl = '$baseUrl/vendor/restaurant/'; // GET, PUT
  // static const String vendorRestaurantCreateUrl = '$baseUrl/vendor/restaurant/create/'; // Optional POST

  // Vendor Category Management
  static const String vendorCategoriesUrl = '$apiBaseUrl/vendor/categories/'; // GET (List), POST (Create)
  // Note: GET (Detail), PUT, DELETE require appending '/<uuid:categoryId>/' to vendorCategoriesUrl

  // Vendor Menu Management
  static const String vendorMenuItemsUrl = '$apiBaseUrl/vendor/menu-items/'; // GET and POST
  static String vendorMenuItemDetailUrl(String id) => '$apiBaseUrl/vendor/menu-items/$id/'; // For GET (retrieve), PUT/PATCH (update), DELETE

  // Vendor Order Management
  static const String vendorOrdersUrl = '$apiBaseUrl/vendor/orders/'; // GET (with query params like ?status=new)
  static const String vendorOrderAcceptUrl = '$apiBaseUrl/vendor/orders/'; // POST with /<id>/accept/
  static const String vendorOrderReadyUrl = '$apiBaseUrl/vendor/orders/'; // POST with /<id>/ready/
  static const String vendorOrderRejectUrl = '$apiBaseUrl/vendor/orders/'; // POST with /<id>/reject/

}
