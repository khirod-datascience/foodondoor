import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import '../globals.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http_parser/http_parser.dart';

class FoodFormScreen extends StatefulWidget {
  final Map<String, dynamic>? food; // Optional parameter for editing food

  FoodFormScreen({this.food});

  @override
  _FoodFormScreenState createState() => _FoodFormScreenState();
}

class _FoodFormScreenState extends State<FoodFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final List<String> _uploadedImages = [];
  final List<String> _units = ['kg', 'gms', 'pc', 'ltr'];
  String? _selectedUnit;

  @override
  void initState() {
    super.initState();
    if (widget.food != null) {
      _nameController.text = widget.food!['name'];
      _descriptionController.text = widget.food!['description'];
      _quantityController.text = widget.food!['quantity'].toString();
      _priceController.text = widget.food!['price'].toString();
      _selectedUnit = _units.contains(widget.food!['unit']) ? widget.food!['unit'] : _units.first;
      if (widget.food!['images'] != null) {
        _uploadedImages.addAll(List<String>.from(widget.food!['images']));
      }
    } else {
      _selectedUnit = _units.first; // Default to the first unit
    }
  }

  Future<void> _submitFood() async {
    if (!_formKey.currentState!.validate()) return;

    // Use tryParse to safely convert text to numbers
    final int? quantity = int.tryParse(_quantityController.text);
    final double? price = double.tryParse(_priceController.text);

    // Check if parsing was successful
    if (quantity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invalid quantity entered. Please enter a valid number.")),
      );
      return; // Stop execution if quantity is invalid
    }

    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invalid price entered. Please enter a valid number.")),
      );
      return; // Stop execution if price is invalid
    }

    final payload = {
      'name': _nameController.text,
      'description': _descriptionController.text,
      'quantity': quantity, // Use the parsed integer
      'price': price,       // Use the parsed double
      'unit': _selectedUnit,
      'images': _uploadedImages,
    };
    
    print("Payload: $payload");

    try {
      final url = widget.food == null
          ? '${Config.baseUrl}/auth/food-listings/${Globals.vendorId}/' 
          : '${Config.baseUrl}/auth/food-listings/${Globals.vendorId}/${widget.food!['id']}/';

      final response = widget.food == null
          ? await http.post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
          : await http.put(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            );

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.food == null ? "Food added successfully!" : "Food updated successfully!")),
        );
        // Pop only if the widget is still mounted
        if (mounted) {
          Navigator.pop(context); 
        }
      } else {
        // Decode error only if response body is not empty
        final error = response.body.isNotEmpty 
                      ? (jsonDecode(response.body)['error'] ?? 'Failed to save food!') 
                      : 'Failed to save food! (Status code: ${response.statusCode})';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        }
      }
    } catch (e) {
      print("Error submitting food: $e"); // Log the actual error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Network error or invalid data: Unable to save food!")),
        );
      }
    }
  }

  Future<void> _uploadImage() async {
    try {
      if (Globals.vendorId == null) {
        print("Vendor ID is null");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please login again")),
        );
        return;
      }

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        print("Selected image path: ${image.path}");
        print("Current vendor ID: ${Globals.vendorId}");

        // Create request with vendor_id as query parameter
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('${Config.baseUrl}/auth/upload-image/?vendor_id=${Globals.vendorId}'),
        );
        
        // Add the image file
        var imageStream = await image.readAsBytes();
        var multipartFile = http.MultipartFile.fromBytes(
          'image',
          imageStream,
          filename: image.name,
          contentType: MediaType('image', 'jpeg'),
        );
        request.files.add(multipartFile);

        print("Sending request to: ${request.url}");
        
        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);
        
        print("Response status: ${response.statusCode}");
        print("Response body: ${response.body}");

        if (response.statusCode == 200 || response.statusCode == 201) {
          var jsonResponse = jsonDecode(response.body);
          setState(() {
            _uploadedImages.add(jsonResponse['image_url']);
          });
          
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text("Image uploaded successfully")),
            );
        } else {
          var errorMessage = jsonDecode(response.body)['error'] ?? 'Failed to upload image';
          throw Exception(errorMessage);
        }
      }
    } catch (e) {
      print("Error uploading image: $e");
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text("Failed to upload image: $e")),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.food == null ? "Add Food Listing" : "Edit Food Listing"),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.food == null ? "Add Food Details" : "Edit Food Details",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: "Food Name",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.fastfood),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please enter the food name";
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: "Description",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please enter the description";
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _quantityController,
                  decoration: InputDecoration(
                    labelText: "Quantity",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.production_quantity_limits),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please enter the quantity";
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedUnit,
                  items: _units.map((unit) {
                    return DropdownMenuItem(
                      value: unit,
                      child: Text(unit),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedUnit = value;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: "Unit",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.scale),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please select a unit";
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _priceController,
                  decoration: InputDecoration(
                    labelText: "Price",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please enter the price";
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                Text(
                  "Uploaded Images:",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _uploadedImages.map((imageUrl) => Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        margin: EdgeInsets.only(top: 8, right: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            '${Config.baseUrl}$imageUrl', // Add base URL here
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / 
                                        loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              print("Error loading image: $error");
                              return Container(
                                color: Colors.grey[200],
                                child: Icon(Icons.broken_image, color: Colors.grey),
                              );
                            },
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton(
                          icon: Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _uploadedImages.remove(imageUrl);
                            });
                          },
                        ),
                      ),
                    ],
                  )).toList(),
                ),
                SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _uploadImage,
                  icon: Icon(Icons.upload),
                  label: Text("Upload Image"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                ),
                SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    onPressed: _submitFood,
                    child: Text(widget.food == null ? "Submit" : "Update"),
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
    );
  }
}
