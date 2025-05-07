class ApiConstants {
  // TODO: Replace with your actual backend URL
  static const String baseUrl = 'http://127.0.0.1:8000/api/';

  // Authentication Endpoints
  static const String sendOtp = 'vendor/send-otp/';
  static const String verifyOtp = 'vendor/verify-otp/';
  static const String registerVendor = 'vendor/register/'; 

  // Restaurant Endpoints
  static const String restaurantDetails = 'vendor/restaurant/'; // GET, PATCH/PUT

  // Add other endpoints as needed
  // static const String categories = 'vendor/categories/';
  // static const String foodItems = 'vendor/food-items/';
}
