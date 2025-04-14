import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import 'dashboard_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http_parser/http_parser.dart';

class DetailsFormScreen extends StatefulWidget {
  final String phoneNumber;
  final String vendorId; // Add this line

  DetailsFormScreen({
    required this.phoneNumber,
    required this.vendorId, // Add this line
  });

  @override
  _DetailsFormScreenState createState() => _DetailsFormScreenState();
}

class _DetailsFormScreenState extends State<DetailsFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _restaurantNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();
  final TextEditingController _openHoursController = TextEditingController();
  File? _selectedImage;

  Future<String?> _uploadImage(File image) async {
    try {
      print("Uploading image for vendor: ${widget.vendorId}"); // Debug print

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Config.baseUrl}/auth/upload-image/?vendor_id=${widget.vendorId}'),
      );

      var imageStream = http.ByteStream(image.openRead());
      var length = await image.length();
      var multipartFile = http.MultipartFile(
        'image',
        imageStream,
        length,
        filename: image.path.split('/').last,
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(multipartFile);

      print("Sending image upload request..."); // Debug print
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      print('Upload response: ${response.body}'); // Debug print

      if (response.statusCode == 201) {
        var jsonResponse = jsonDecode(response.body);
        return jsonResponse['image_url'];
      } else {
        print('Image upload failed: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Prepare the initial payload without the image URL
    final payload = {
      'phone': widget.phoneNumber,
      'vendor_id': widget.vendorId,
      'restaurant_name': _restaurantNameController.text,
      'email': _emailController.text,
      'address': _addressController.text,
      'contact_number': _contactNumberController.text,
      'open_hours': _openHoursController.text,
      'image': null, // Explicitly include image field as null initially
    };

    print("Submitting signup details with payload: $payload");

    try {
      // First, create the vendor profile with basic details
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/auth/signup/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201) {
        // If vendor creation is successful and an image was selected, upload it
        if (_selectedImage != null) {
          String? imageUrl = await _uploadImage(_selectedImage!);
          if (imageUrl != null) {
            // Optional: If needed, you could make another request here
            // to update the vendor profile with the obtained imageUrl.
            // For now, we just show a warning if upload fails.
            print("Image uploaded successfully: $imageUrl");
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Warning: Failed to upload image, but profile created.')),
            );
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Signup details submitted successfully!")),
        );

        print("Navigating to DashboardScreen...");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(),
          ),
        );
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Failed to submit details!';
        print("Error response from backend: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    } catch (e) {
      print("Network error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Network error: Unable to submit details!")),
      );
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Signup Details"),
        backgroundColor: Colors.orange,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade100, Colors.orange.shade300],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _restaurantNameController,
                    decoration: InputDecoration(labelText: "Restaurant Name"),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter the restaurant name";
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(labelText: "Email"),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter the email";
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: InputDecoration(labelText: "Address"),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter the address";
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _contactNumberController,
                    decoration: InputDecoration(labelText: "Contact Number"),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter the contact number";
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _openHoursController,
                    decoration: InputDecoration(labelText: "Open Hours"),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter the open hours";
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Selected Image",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  _selectedImage != null
                      ? Container(
                          width: 100,
                          height: 100,
                          margin: EdgeInsets.only(top: 8, right: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: Icon(Icons.broken_image, color: Colors.grey),
                                );
                              },
                            ),
                          ),
                        )
                      : Text("No image selected"),
                  SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: Icon(Icons.image),
                    label: Text("Pick Image"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  ),
                  SizedBox(height: 16),
                  Center(
                    child: ElevatedButton(
                      onPressed: _submitForm,
                      child: Text("Submit"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        textStyle: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}