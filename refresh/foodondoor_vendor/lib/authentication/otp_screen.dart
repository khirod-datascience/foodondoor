import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:foodondoor_vendor/authentication/register.dart'; // Import RegisterScreen
import 'package:foodondoor_vendor/mainScreens/home_screen.dart'; // Import HomeScreen
import 'package:foodondoor_vendor/services/api_service.dart';
import 'package:foodondoor_vendor/widgets/loading_dialog.dart';
import 'package:foodondoor_vendor/widgets/error_Dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../global/global.dart'; // Assuming global.dart exists and defines sharedPreferences

class OtpScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpScreen({super.key, required this.phoneNumber});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  TextEditingController otpController = TextEditingController();
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  Future<void> _verifyOtp() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => const LoadingDialog(message: "Verifying OTP..."));

      try {
        // TODO: Get FCM token if needed for vendor login
        // String? fcmToken = await FirebaseMessaging.instance.getToken();
        String? fcmToken = "dummy_fcm_token_for_testing"; // Placeholder

        final response = await _apiService.verifyOtp(
            widget.phoneNumber,
            otpController.text.trim(),
            fcmToken: fcmToken
        );

        if (!mounted) return;
        Navigator.pop(context); // Dismiss loading dialog *after* processing the response

        if (response['success'] == true) {
           Navigator.pop(context); // Dismiss loading on success before navigation/toast
           if (response['is_signup'] == true) {
            // Navigate to Vendor Register Screen
            Fluttertoast.showToast(msg: "OTP Verified. Please complete registration.");
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (c) => RegisterScreen(phone: widget.phoneNumber)),
            );
          } else {
            // Vendor Login Success
            if (response.containsKey('access') && response.containsKey('refresh') && response.containsKey('vendor')) {
              String token = response['access'];
              String refreshToken = response['refresh'];
              Map<String, dynamic> vendorData = response['vendor'];

              // --- CRITICAL FIX: Await token storage --- 
              await _apiService.storeToken(token);
              await _apiService.storeRefreshToken(refreshToken); // Store refresh token
              debugPrint("Token and refresh token stored successfully. Proceeding to save vendor details.");

              // Ensure sharedPreferences is initialized
              sharedPreferences ??= await SharedPreferences.getInstance();

              // Store vendor details in sharedPreferences
              await sharedPreferences!.setString("vendor_uid", vendorData['vendor_id'] ?? ''); // Use vendor specific keys, handle null
              await sharedPreferences!.setString("vendor_email", vendorData['email'] ?? '');
              await sharedPreferences!.setString("vendor_name", vendorData['restaurant_name'] ?? '');

              // Extract photo URL safely
              String photoUrl = "";
              if (vendorData['uploaded_images'] != null && vendorData['uploaded_images'] is List && vendorData['uploaded_images'].isNotEmpty) {
                 // Assuming the first image is the profile/logo
                 photoUrl = vendorData['uploaded_images'][0].toString(); // Ensure it's a string
              }
              await sharedPreferences!.setString("vendor_photoUrl", photoUrl);
              debugPrint("Vendor details saved to SharedPreferences.");

              Fluttertoast.showToast(msg: "Login Successful.");

              // --- Navigate AFTER storing token and details --- 
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (c) => const HomeScreen()),
                (route) => false, // Clear back stack
              );
            } else {
               setState(() { _isLoading = false; }); // Reset loading state on failure
               Navigator.pop(context); // Dismiss loading dialog if it wasn't dismissed
               showDialog(
                  context: context,
                  builder: (c) => const ErrorDialog(message: "Login failed: Invalid response format from server.") // More specific message
              );
            }
          }
        } else {
           Navigator.pop(context); // Dismiss loading on failure
           setState(() { _isLoading = false; });
           showDialog(
              context: context,
              builder: (c) => ErrorDialog(message: "Verification Failed: ${response['error'] ?? 'Invalid OTP or error'}") // Improved message
          );
        }
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Dismiss loading on exception
        setState(() { _isLoading = false; });
         showDialog(
             context: context,
             builder: (c) => ErrorDialog(message: "An error occurred: ${e.toString()}")
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Define vendor theme colors (example - can be same as customer or different)
    final Color vendorPrimaryColor = theme.primaryColor; // Or a different color
    final Color vendorBackgroundColor = theme.scaffoldBackgroundColor;
    final Color vendorTextColor = theme.textTheme.bodyMedium?.color ?? Colors.black;

    return Scaffold(
      appBar: AppBar(
          title: const Text("Verify Vendor OTP"),
          // Apply theme colors if needed
          backgroundColor: vendorPrimaryColor,
          foregroundColor: Colors.white,
       ),
      backgroundColor: vendorBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Enter OTP sent to ${widget.phoneNumber}",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(color: vendorTextColor),
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(fontSize: 24, letterSpacing: 10),
                  decoration: const InputDecoration(
                    hintText: "------",
                    counterText: "",
                    border: OutlineInputBorder(),
                  ),
                   validator: (value) {
                     if (value == null || value.isEmpty) {
                       return 'Please enter the OTP';
                     }
                     if (value.length != 6) {
                       return 'OTP must be 6 digits';
                     }
                     return null;
                   },
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  // Inherit style from vendor theme
                  style: ElevatedButton.styleFrom(
                     backgroundColor: vendorPrimaryColor, // Use vendor theme color
                     foregroundColor: Colors.white, // Ensure text is visible
                     padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                     textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
                      : const Text("Verify OTP"),
                ),
                 const SizedBox(height: 20),
                 TextButton(
                    onPressed: () { // TODO: Implement Resend OTP for vendor
                       Fluttertoast.showToast(msg: "Resend Vendor OTP not implemented yet.");
                    },
                    style: TextButton.styleFrom(foregroundColor: vendorPrimaryColor),
                    child: const Text("Resend OTP?"),
                 )
              ],
            ),
          ),
        ),
      ),
    );
  }
} 