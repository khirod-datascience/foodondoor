import 'package:flutter/material.dart';
import 'package:foodondoor_vendor/authentication/otp_screen.dart';
import 'package:foodondoor_vendor/services/api_service.dart';
import '../global/global.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/error_Dialog.dart';
import '../widgets/loading_dialog.dart';
import 'package:fluttertoast/fluttertoast.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  TextEditingController phoneController = TextEditingController();
  bool _isLoading = false;

  final ApiService _apiService = ApiService();

  Future<void> validateAndSendOtp() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => const LoadingDialog(message: "Sending OTP...")
      );

      try {
        final response = await _apiService.sendOtp(phoneController.text.trim());

        if (!mounted) return;
        Navigator.pop(context);

        if (response['success'] == true) {
          Fluttertoast.showToast(msg: "OTP sent successfully.");
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (c) => OtpScreen(phoneNumber: phoneController.text.trim()),
            ),
          );
        } else {
           setState(() { _isLoading = false; });
           showDialog(
              context: context,
              builder: (c) => ErrorDialog(message: "Failed to send OTP: ${response['error'] ?? 'Unknown error'}")
           );
        }
      } catch (e) {
         if (!mounted) return;
         Navigator.pop(context);
         setState(() { _isLoading = false; });
         showDialog(
             context: context,
             builder: (c) => ErrorDialog(message: "An error occurred: ${e.toString()}")
         );
      } finally {
         if (mounted) {
            setState(() { _isLoading = false; });
         }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Image.asset(
                  'assets/images/seller.png',
                  height: 270,
                  errorBuilder: (context, error, stackTrace) {
                     print("Error loading seller.png: $error");
                     return const Icon(Icons.storefront, size: 150, color: Colors.grey);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
             Text(
               "Enter Phone Number to Login/Register",
               style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
               textAlign: TextAlign.center,
             ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: CustomTextField(
                    data: Icons.phone_android,
                    controller: phoneController,
                    hintText: 'Phone Number (e.g., 9876543210)',
                    isObsecre: false,
                    keyboardType: TextInputType.phone,
                     validator: (value) {
                       if (value == null || value.isEmpty) {
                         return 'Please enter your phone number';
                       }
                       if (value.length != 10 || int.tryParse(value) == null) {
                         return 'Please enter a valid 10-digit phone number';
                       }
                       return null;
                     },
                 ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading ? null : validateAndSendOtp,
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                  : const Text(
                      "Send OTP",
                    ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
