import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../global/global.dart';
import '../mainScreens/home_screen.dart';
import '../services/api_service.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/loading_dialog.dart';
import 'otp_screen.dart';

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
    if (phoneController.text.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) {
            return LoadingDialog(
              message: "Sending OTP...",
            );
          });

      try {
        final response = await _apiService.sendOtp(phoneController.text.trim());

        Navigator.pop(context);

        if (response['success'] == true || response.containsKey('debug_otp')) {
          Fluttertoast.showToast(msg: "OTP Sent Successfully.");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (c) => OtpScreen(phoneNumber: phoneController.text.trim())),
          );
        } else {
          setState(() {
            _isLoading = false;
          });
          Fluttertoast.showToast(msg: "Error: ${response['error'] ?? 'Failed to send OTP'}");
        }
      } catch (e) {
        Navigator.pop(context);
        setState(() {
          _isLoading = false;
        });
        Fluttertoast.showToast(msg: "Error: ${e.toString()}");
      }
    } else {
      Fluttertoast.showToast(msg: "Please enter your phone number.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login', style: Theme.of(context).appBarTheme.titleTextStyle),
        centerTitle: true,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.max, children: [
          Container(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Image.asset(
                'assets/images/login.png',
                height: 270,
              ),
            ),
          ),
          Form(
            key: _formKey,
            child: Column(
              children: [
                CustomTextField(
                  data: Icons.phone,
                  controller: phoneController,
                  hintText: 'Phone Number',
                  isObsecre: false,
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 30,
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : validateAndSendOtp,
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 10)),
            child: _isLoading
                ? const SizedBox(child: CircularProgressIndicator(color: Colors.white), height: 20, width: 20)
                : const Text(
                    "Send OTP",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(
            height: 30,
          )
        ]),
      ),
    );
  }
}
