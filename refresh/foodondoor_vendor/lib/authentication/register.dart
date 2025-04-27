import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/error_Dialog.dart';
import '../widgets/loading_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../global/global.dart';
import '../mainScreens/home_screen.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  final String phone;

  const RegisterScreen({super.key, required this.phone});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController locationController = TextEditingController();
  TextEditingController pincodeController = TextEditingController();
  TextEditingController cuisineController = TextEditingController();

  XFile? imageXFile;
  final ImagePicker _picker = ImagePicker();

  Position? position;
  List<Placemark>? placeMarks;

  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    phoneController.text = widget.phone;
  }

  Future<void> _getImage() async {
    imageXFile = await _picker.pickImage(source: ImageSource.gallery);
    setState(() {
      imageXFile;
    });
  }

  getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) showDialog(context: context, builder: (c) => const ErrorDialog(message: "Location permission denied."));
        return;
      }
      Position newPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      position = newPosition;

      placeMarks = await placemarkFromCoordinates(position!.latitude, position!.longitude);

      if (placeMarks != null && placeMarks!.isNotEmpty) {
        Placemark pMarks = placeMarks![0];
        String street = pMarks.thoroughfare ?? pMarks.subThoroughfare ?? '';
        String subLocality = pMarks.subLocality ?? '';
        String locality = pMarks.locality ?? '';
        String postalCode = pMarks.postalCode ?? '';
        String adminArea = pMarks.administrativeArea ?? '';
        String country = pMarks.country ?? '';

        List<String> addressParts = [street, subLocality, locality, adminArea, country];
        String fullAddress = addressParts.where((part) => part.isNotEmpty).join(', ');

        locationController.text = fullAddress;
        pincodeController.text = postalCode;
      }
      setState(() {});
    } catch (e) {
      print("Error getting location: $e");
      if (mounted) showDialog(context: context, builder: (c) => ErrorDialog(message: "Error getting location: $e"));
    }
  }

  Future<void> formValidation() async {
    if (imageXFile == null) {
      showDialog(context: context, builder: (c) => const ErrorDialog(message: "Please select an image for your restaurant"));
      return;
    }

    if (_formKey.currentState!.validate()) {
      if (position == null || locationController.text.isEmpty) {
        showDialog(context: context, builder: (c) => const ErrorDialog(message: "Please get your current location or enter address manually"));
        return;
      }

      setState(() { _isLoading = true; });
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => const LoadingDialog(message: "Registering Account...")
      );

      File imageFile = File(imageXFile!.path);
      final imageUploadResponse = await _apiService.uploadImage(imageFile);

      if (!mounted) return;

      if (imageUploadResponse.containsKey('error') || !imageUploadResponse.containsKey('image_path')) {
        Navigator.pop(context);
        setState(() { _isLoading = false; });
        showDialog(
            context: context,
            builder: (c) => ErrorDialog(message: "Image upload failed: ${imageUploadResponse['error'] ?? 'Unknown error'}")
        );
        return;
      }

      String imagePath = imageUploadResponse['image_path'];
      print("Image uploaded successfully, path: $imagePath");

      Map<String, dynamic> registrationData = {
        "email": emailController.text.trim(),
        "restaurant_name": nameController.text.trim(),
        "address": locationController.text.trim(),
        "contact_number": widget.phone,
        "latitude": position!.latitude.toString(),
        "longitude": position!.longitude.toString(),
        "image_path": imagePath,
      };

      final registrationResponse = await _apiService.registerVendor(registrationData);

       if (!mounted) return;
      Navigator.pop(context);
      setState(() { _isLoading = false; });

      if (registrationResponse.containsKey('error')) {
        showDialog(
            context: context,
            builder: (c) => ErrorDialog(message: "Registration failed: ${registrationResponse['error']}")
        );
      } else if (registrationResponse.containsKey('vendor') && registrationResponse.containsKey('access')) {
        print("Registration successful!");

        Map<String, dynamic> vendorData = registrationResponse['vendor'];
        String token = registrationResponse['access'];

        sharedPreferences = await SharedPreferences.getInstance();
        await sharedPreferences!.setString("token", token);
        await sharedPreferences!.setString("uid", vendorData['vendor_id'].toString());
        await sharedPreferences!.setString("email", vendorData['email'] ?? '');
        await sharedPreferences!.setString("name", vendorData['restaurant_name']);

        // Store token securely using ApiService
        await _apiService.storeToken(token);

        Fluttertoast.showToast(msg: "Registration Successful!");

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (c) => const HomeScreen()),
          (route) => false,
        );
      } else {
        showDialog(
            context: context,
            builder: (c) => const ErrorDialog(message: "Registration failed: Unexpected response format.")
        );
      }
    } else {
      Fluttertoast.showToast(msg: "Please fill all required fields correctly.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       appBar: AppBar(title: const Text("Vendor Registration")),
       body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            const SizedBox(height: 10),
            InkWell(
              onTap: _getImage,
              child: CircleAvatar(
                radius: MediaQuery.of(context).size.width * 0.20,
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                backgroundImage: imageXFile == null
                    ? null
                    : FileImage(
                        File(imageXFile!.path),
                      ),
                child: imageXFile == null
                    ? Icon(
                        Icons.add_photo_alternate,
                        size: MediaQuery.of(context).size.width * 0.20,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    CustomTextField(
                      data: Icons.person,
                      controller: nameController,
                      hintText: 'Restaurant Name',
                      isObsecre: false,
                      validator: (value) => value == null || value.isEmpty ? 'Please enter restaurant name' : null,
                    ),
                    CustomTextField(
                      data: Icons.email,
                      controller: emailController,
                      hintText: 'Email (Optional)',
                      isObsecre: false,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    CustomTextField(
                      data: Icons.phone,
                      controller: phoneController,
                      hintText: 'Phone Number',
                      isObsecre: false,
                      enabled: false,
                    ),
                    CustomTextField(
                      data: Icons.my_location,
                      controller: locationController,
                      hintText: 'Full Address',
                      isObsecre: false,
                      enabled: true,
                      validator: (value) => value == null || value.isEmpty ? 'Please enter address or get location' : null,
                    ),
                    Container(
                      width: double.infinity,
                      height: 50,
                      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                      child: ElevatedButton.icon(
                        onPressed: getCurrentLocation,
                        icon: const Icon(Icons.location_on),
                        label: const Text('Get My Current Location'),
                        style: ElevatedButton.styleFrom(
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading ? null : formValidation,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLoading
                           ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                           : const Text('Register', style: TextStyle(fontSize: 18)),
                    ),
                     const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
