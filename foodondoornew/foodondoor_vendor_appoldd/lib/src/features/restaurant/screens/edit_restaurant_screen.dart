import 'package:flutter/material.dart';
import 'package:foodondoor_vendor_app/src/features/restaurant/models/restaurant_model.dart';
import 'package:foodondoor_vendor_app/src/features/restaurant/providers/restaurant_provider.dart';
import 'package:provider/provider.dart';

class EditRestaurantScreen extends StatefulWidget {
  static const routeName = '/edit-restaurant';
  final Restaurant initialRestaurantData;

  const EditRestaurantScreen({super.key, required this.initialRestaurantData});

  @override
  State<EditRestaurantScreen> createState() => _EditRestaurantScreenState();
}

class _EditRestaurantScreenState extends State<EditRestaurantScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _postalCodeController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _logoUrlController;
  late TextEditingController _coverPhotoUrlController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing data
    _nameController = TextEditingController(text: widget.initialRestaurantData.name);
    _descriptionController = TextEditingController(text: widget.initialRestaurantData.description ?? '');
    _addressController = TextEditingController(text: widget.initialRestaurantData.address);
    _cityController = TextEditingController(text: widget.initialRestaurantData.city);
    _stateController = TextEditingController(text: widget.initialRestaurantData.state);
    _postalCodeController = TextEditingController(text: widget.initialRestaurantData.postalCode);
    _phoneNumberController = TextEditingController(text: widget.initialRestaurantData.phoneNumber ?? '');
    _logoUrlController = TextEditingController(text: widget.initialRestaurantData.logoUrl ?? '');
    _coverPhotoUrlController = TextEditingController(text: widget.initialRestaurantData.coverPhotoUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _phoneNumberController.dispose();
    _logoUrlController.dispose();
    _coverPhotoUrlController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Create a map of the updated data
      final updatedData = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'address': _addressController.text,
        'city': _cityController.text,
        'state': _stateController.text,
        'postal_code': _postalCodeController.text,
        'phone_number': _phoneNumberController.text,
        'logo_url': _logoUrlController.text,
        'cover_photo_url': _coverPhotoUrlController.text,
        // Include other fields that might be editable
      };

      try {
        final provider = Provider.of<RestaurantProvider>(context, listen: false);
        bool success = await provider.updateRestaurantDetails(updatedData);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
          );
          // Optionally fetch fresh data after update
          // await provider.fetchRestaurantDetails(); 
          Navigator.pop(context); // Go back to the profile screen
        } else {
          _showErrorDialog('Failed to update profile. ${provider.errorMessage}');
        }
      } catch (error) {
        _showErrorDialog('An unexpected error occurred: $error');
      } finally {
        if (mounted) { // Check if the widget is still in the tree
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _showErrorDialog(String message) {
     if (!mounted) return; // Check if widget is mounted before showing dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Failed'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('Okay'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Restaurant Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: <Widget>[
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Restaurant Name'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a restaurant name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 3,
                      // No validation needed for description (optional field)
                    ),
                     const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'Address'),
                       validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                     TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(labelText: 'City'),
                       validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a city';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                     TextFormField(
                      controller: _stateController,
                      decoration: const InputDecoration(labelText: 'State'),
                       validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a state';
                        }
                        return null;
                      },
                    ),
                     const SizedBox(height: 12),
                     TextFormField(
                      controller: _postalCodeController,
                      decoration: const InputDecoration(labelText: 'Postal Code'),
                       validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a postal code';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneNumberController,
                      decoration: const InputDecoration(labelText: 'Phone Number (Optional)'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                     TextFormField(
                      controller: _logoUrlController,
                      decoration: const InputDecoration(labelText: 'Logo URL (Optional)'),
                      keyboardType: TextInputType.url,
                    ),
                     const SizedBox(height: 12),
                     TextFormField(
                      controller: _coverPhotoUrlController,
                      decoration: const InputDecoration(labelText: 'Cover Photo URL (Optional)'),
                       keyboardType: TextInputType.url,
                    ),
                    // Add more fields as needed (e.g., latitude, longitude)
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
