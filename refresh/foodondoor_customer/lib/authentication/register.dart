import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../global/global.dart'; // For sharedPreferences
import '../mainScreens/home_screen.dart';
import '../services/api_service.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/loading_dialog.dart';

// Renamed class for clarity
class RegisterScreen extends StatefulWidget {
  final String phone;

  const RegisterScreen({super.key, required this.phone});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

// Renamed state class for clarity
class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  Future<void> _registerUser() async {
     if (_formKey.currentState!.validate()) {
       setState(() { _isLoading = true; });
       showDialog(
           context: context,
           barrierDismissible: false,
           builder: (c) => LoadingDialog(message: "Registering..."));

       try {
         final response = await _apiService.registerCustomer(
             nameController.text.trim(),
             emailController.text.trim()
         );

         Navigator.pop(context); // Dismiss loading

         if (response['success'] == true) {
            // Accept any of these token keys
            String? token = response['auth_token'] ?? response['token'] ?? response['access'];
            if (token != null && token.isNotEmpty) {
                await _apiService.storeToken(token);
                // Store user details if present
                if (response.containsKey('user')) {
                  final userData = response['user'] as Map<String, dynamic>;
                  await sharedPreferences!.setString("uid", userData['user_id']?.toString() ?? '');
                  await sharedPreferences!.setString("name", userData['full_name'] ?? '');
                  await sharedPreferences!.setString("email", userData['email'] ?? '');
                  await sharedPreferences!.setString("phone", userData['phone'] ?? '');
                } else {
                  await sharedPreferences!.setString("uid", response['user_id']?.toString() ?? '');
                  await sharedPreferences!.setString("phone", response['phone'] ?? '');
                }
                Fluttertoast.showToast(msg: "Registration Successful.");
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (c) => const HomeScreen()),
                  (route) => false, // Clear back stack
                );
            } else {
                setState(() { _isLoading = false; });
                Fluttertoast.showToast(msg: "Registration failed: Missing token or user data in response.");
            }
         } else {
           setState(() { _isLoading = false; });
           // Try to extract detailed error
           String errorMessage = response['error']?.toString() ?? '';
           if (response.containsKey('email') && response['email'] is List && response['email'].isNotEmpty) {
             errorMessage = "Email: "+response['email'][0].toString();
           } else if (response.containsKey('name') && response['name'] is List && response['name'].isNotEmpty) {
             errorMessage = "Name: "+response['name'][0].toString();
           } else if (response.containsKey('non_field_errors') && response['non_field_errors'] is List && response['non_field_errors'].isNotEmpty) {
             errorMessage = response['non_field_errors'][0].toString();
           } else if (response.containsKey('detail')) {
             errorMessage = response['detail'].toString();
           }
           Fluttertoast.showToast(msg: "Error: $errorMessage");
         }
       } catch (e) {
         Navigator.pop(context); // Dismiss loading on error
         setState(() { _isLoading = false; });
         Fluttertoast.showToast(msg: "Error: ${e.toString()}");
       }
     } else {
         Fluttertoast.showToast(msg: "Please fill in all required fields correctly.");
     }
   }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text("Complete Signup", style: Theme.of(context).appBarTheme.titleTextStyle), centerTitle: true, elevation: 0),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Enter your details for phone: ${widget.phone}",
                  textAlign: TextAlign.center,
                  // Apply theme text style
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color ?? Colors.black54,
                  ),
                ),
                const SizedBox(height: 30),
                CustomTextField(
                  data: Icons.person,
                  controller: nameController,
                  hintText: "Full Name",
                  isObsecre: false,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  data: Icons.email,
                  controller: emailController,
                  hintText: "Email",
                  isObsecre: false,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains("@") || !value.contains(".")) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _isLoading ? null : _registerUser,
                  // REMOVED explicit style to inherit from theme
                  // style: ElevatedButton.styleFrom(...)
                  child: _isLoading
                      ? const SizedBox(
                          height: 24, // Match height of text
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      // Theme handles text style
                      : const Text("Register"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
