import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../utils/app_config.dart';

// Purpose: Provides a form for adding a new address or editing an existing one.

class AddEditAddressScreen extends StatefulWidget {
  final Map<String, dynamic>? address; // Pass address map for editing, null for adding

  const AddEditAddressScreen({Key? key, this.address}) : super(key: key);

  @override
  _AddEditAddressScreenState createState() => _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends State<AddEditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController(); // Optional
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _typeController = TextEditingController(); // e.g., Home, Work, Other
  final _stateController = TextEditingController(); // <<<--- ADDED State Controller

  bool _isLoading = false;
  String? _apiError;

  bool get _isEditing => widget.address != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing && widget.address != null) {
      // Populate controllers if editing an existing address
      _addressLine1Controller.text = widget.address!['address_line1']?.toString() ?? '';
      _addressLine2Controller.text = widget.address!['address_line2']?.toString() ?? '';
      _cityController.text = widget.address!['city']?.toString() ?? '';
      _postalCodeController.text = widget.address!['postal_code']?.toString() ?? '';
      _typeController.text = widget.address!['type']?.toString() ?? '';
      _stateController.text = widget.address!['state']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _typeController.dispose();
    _stateController.dispose(); // <<<--- ADDED Dispose State Controller
    super.dispose();
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) {
      return; // Don't proceed if form is invalid
    }

    setState(() { _isLoading = true; _apiError = null; });

    final addressData = {
      'customer_id': Provider.of<AuthProvider>(context, listen: false).customerId,
      'address_line1': _addressLine1Controller.text,
      'address_line2': _addressLine2Controller.text.isNotEmpty ? _addressLine2Controller.text : null,
      'city': _cityController.text,
      'postal_code': _postalCodeController.text,
      'state': _stateController.text,
      'type': _typeController.text.isNotEmpty ? _typeController.text : 'Other',
      // Add any other required fields by your backend (e.g., state, country)
    };

    try {
      Response response;
      final String url;
      final dio = Dio();
      // TODO: Add auth headers if needed: dio.options.headers['Authorization'] = ...

      if (_isEditing) {
        // Update existing address (PUT or PATCH request)
        final addressId = widget.address!['id']; 
        url = '${AppConfig.baseUrl}/api/addresses/$addressId/'; // Corrected endpoint
        debugPrint('Updating address ($addressId) at: $url with data: $addressData');
        response = await dio.put(url, data: addressData); 
      } else {
        // Add new address (POST request)
        url = '${AppConfig.baseUrl}/api/addresses/'; // Corrected endpoint
        debugPrint('Adding new address at: $url with data: $addressData');
        response = await dio.post(url, data: addressData);
      }

      debugPrint('Save Address Response (${response.statusCode}): ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Address ${_isEditing ? 'updated' : 'added'} successfully!'), backgroundColor: Colors.green)
        );
        Navigator.of(context).pop(true); // Pop screen and return true to signal success
      } else {
         setState(() {
             _apiError = 'Failed to save address. Status: ${response.statusCode}';
         });
      }

    } on DioException catch (e) {
       debugPrint('Dio Error saving address: ${e.response?.data ?? e.message}');
       setState(() {
           _apiError = 'Error: ${e.response?.data?['detail'] ?? e.message ?? 'Failed to save address.'}';
       });
    } catch (e) {
       debugPrint('Error saving address: $e');
       setState(() {
           _apiError = 'An unexpected error occurred.';
       });
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Address' : 'Add New Address'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _addressLine1Controller,
                decoration: const InputDecoration(labelText: 'Address Line 1', border: OutlineInputBorder()),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the first line of the address.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressLine2Controller,
                decoration: const InputDecoration(labelText: 'Address Line 2 (Optional)', border: OutlineInputBorder()),
                // No validator needed for optional field
              ),
              const SizedBox(height: 16),
              Row(
                 children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
                         validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the city.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                         controller: _stateController,
                         decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()),
                         validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter the state.';
                            }
                            // Add validation like checking abbreviation length if needed
                            return null;
                          },
                      ),
                    ),
                 ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                 controller: _postalCodeController,
                 decoration: const InputDecoration(labelText: 'Postal Code', border: OutlineInputBorder()),
                 keyboardType: TextInputType.number, // Adjust keyboard type
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the postal code.';
                    }
                     // Add more specific validation if needed (e.g., length, format)
                    return null;
                  },
               ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _typeController,
                decoration: const InputDecoration(labelText: 'Address Type (e.g., Home, Work)', border: OutlineInputBorder()),
                 // Consider using DropdownButtonFormField if types are predefined
              ),
              const SizedBox(height: 24),
              if (_apiError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(_apiError!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ),
              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                  : ElevatedButton.icon(
                      icon: Icon(_isEditing ? Icons.save_alt : Icons.add_location_alt),
                      label: Text(_isEditing ? 'Update Address' : 'Save Address'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                      onPressed: _saveAddress,
                    ),
            ],
          ),
        ),
      ),
    );
  }
} 