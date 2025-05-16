class AppConfig {
  static const String baseUrl = 'http://192.168.225.54:8000/customer';
  
  // Paytm Configuration
  static const String paytmEnvironment = "1"; // "0" for production, "1" for testing
  static const String paytmMerchantId = "YOUR_MERCHANT_ID";
  static const String paytmMerchantKey = "YOUR_MERCHANT_KEY";
  static const String paytmWebsite = "DEFAULT"; // Use "DEFAULT" for testing
  static const String paytmIndustryType = "Retail";
  static const String paytmCallbackUrl = "https://securegw-stage.paytm.in/theia/paytmCallback"; // Use this for testing
}