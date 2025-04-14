import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class FoodDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> food;

  FoodDetailsScreen({required this.food});

  @override
  _FoodDetailsScreenState createState() => _FoodDetailsScreenState();
}

class _FoodDetailsScreenState extends State<FoodDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  late String _selectedUnit;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.food['name']);
    _descriptionController = TextEditingController(text: widget.food['description']);
    _quantityController = TextEditingController(text: widget.food['quantity'].toString());
    _priceController = TextEditingController(text: widget.food['price'].toString());
    _selectedUnit = widget.food['unit'] ?? 'kg'; // Default to 'kg' if null
  }

  Future<void> _updateFood() async {
    if (!_formKey.currentState!.validate()) return;

    final payload = {
      'name': _nameController.text,
      'description': _descriptionController.text,
      'quantity': int.parse(_quantityController.text),
      'unit': _selectedUnit,
      'price': double.parse(_priceController.text),
    };

    print("Updating food with payload: $payload");

    try {
      final response = await http.put(
        Uri.parse('${Config.baseUrl}/auth/food-listings/${widget.food['id']}/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Food updated successfully!")),
        );
        Navigator.pop(context); // Go back to the food listings screen
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Failed to update food!';
        print("Error response from backend: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    } catch (e) {
      print("Network error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Network error: Unable to update food!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Edit Food Details"),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: widget.food['images'] != null && widget.food['images'].isNotEmpty
                      ? Image.network(
                          // Add base URL to the image path
                          '${Config.baseUrl}${widget.food['images'][0]}',
                          width: 150,
                          height: 150,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print("Error loading image: $error"); // Add error logging
                            return Icon(Icons.broken_image, size: 150, color: Colors.grey);
                          },
                        )
                      : Icon(Icons.fastfood, size: 150, color: Colors.orange),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: "Food Name"),
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
                  decoration: InputDecoration(labelText: "Description"),
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
                  decoration: InputDecoration(labelText: "Quantity"),
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
                  items: ['kg', 'gms', 'pc', 'ltr'].map((unit) {
                    return DropdownMenuItem(
                      value: unit,
                      child: Text(unit),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedUnit = value!;
                    });
                  },
                  decoration: InputDecoration(labelText: "Unit"),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _priceController,
                  decoration: InputDecoration(labelText: "Price"),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please enter the price";
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    onPressed: _updateFood,
                    child: Text("Update Food"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
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