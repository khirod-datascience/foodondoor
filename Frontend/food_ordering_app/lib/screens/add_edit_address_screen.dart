import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../config.dart';
import '../utils/globals.dart';
import '../utils/auth_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'map_address_picker_screen.dart';

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
  final List<String> _addressTypes = ['Home', 'Work', 'Other'];
  final _stateController = TextEditingController();

  bool _isLoading = false;
  String? _apiError;
  bool _setAsDefault = false;

  bool get _isEditing => widget.address != null;

  @override
  void initState() {
    super.initState();
    _setAsDefault = widget.address?['is_default'] ?? false;
    if (_isEditing && widget.address != null) {
      // Populate controllers if editing an existing address
      _addressLine1Controller.text = widget.address!['address_line1']?.toString() ?? '';
      _addressLine2Controller.text = widget.address!['address_line2']?.toString() ?? '';
      _cityController.text = widget.address!['city']?.toString() ?? '';
      _postalCodeController.text = widget.address!['postal_code']?.toString() ?? '';
      _typeController.text = widget.address!['type']?.toString() ?? 'Home';
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

  Future<bool> _isDuplicateAddress() async {
    try {
      final dio = Dio();
      final String? token = await AuthStorage.getToken();
      if (token == null || token.isEmpty || globalCustomerId == null) return false;
      final url = '${AppConfig.baseUrl}/$globalCustomerId/addresses/';
      final response = await dio.get(url, options: Options(headers: {'Authorization': 'Bearer $token'}));
      if (response.statusCode == 200 && response.data is List) {
        final List addresses = response.data;
        for (final addr in addresses) {
          if (_isEditing && addr['id'] == widget.address?['id']) continue; // skip current if editing
          if ((addr['address_line1'] ?? '').toString().trim().toLowerCase() == _addressLine1Controller.text.trim().toLowerCase() &&
              (addr['city'] ?? '').toString().trim().toLowerCase() == _cityController.text.trim().toLowerCase() &&
              (addr['postal_code'] ?? '').toString().trim() == _postalCodeController.text.trim()) {
            return true;
          }
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) {
      setState(() { _apiError = 'Please fill all required fields.'; });
      return; // Don't proceed if form is invalid
    }

    // Check for duplicate address
    setState(() { _apiError = null; });
    if (await _isDuplicateAddress()) {
      setState(() { _apiError = 'This address already exists in your saved addresses.'; });
      return;
    }

    if (globalCustomerId == null) {
       setState(() { _apiError = 'Cannot save address: Not logged in.'; });
       return;
    }

    setState(() { _isLoading = true; _apiError = null; });

    final addressData = {
      'customer_id': globalCustomerId,
      'address_line1': _addressLine1Controller.text,
      'address_line2': _addressLine2Controller.text.isNotEmpty ? _addressLine2Controller.text : null,
      'city': _cityController.text,
      'postal_code': _postalCodeController.text,
      'state': _stateController.text,
      'type': _typeController.text.isNotEmpty ? _typeController.text : 'Other',
      'is_default': _setAsDefault,
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
        url = '${AppConfig.baseUrl}/addresses/$addressId/'; // Adjust endpoint if needed
        debugPrint('Updating address ($addressId) at: $url with data: $addressData');
        response = await dio.put(url, data: addressData); 
      } else {
        // Add new address (POST request)
        url = '${AppConfig.baseUrl}/addresses/'; // Adjust endpoint if needed
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
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.my_location, color: Colors.white),
                    label: const Text('Use Current Location'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onPressed: _isLoading ? null : () async {
                      setState(() { _isLoading = true; });
                      try {
                        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
                        if (placemarks.isNotEmpty) {
                          final place = placemarks.first;
                          setState(() {
                            _addressLine1Controller.text = place.street ?? '';
                            _cityController.text = place.locality ?? '';
                            _stateController.text = place.administrativeArea ?? '';
                            _postalCodeController.text = place.postalCode ?? '';
                          });
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not fetch location: $e'), backgroundColor: Colors.red),
                        );
                      } finally {
                        setState(() { _isLoading = false; });
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  // ElevatedButton.icon(
                  //   icon: const Icon(Icons.map, color: Colors.white),
                  //   label: const Text('Pick on Map'),
                  //   style: ElevatedButton.styleFrom(
                  //     backgroundColor: Colors.orange,
                  //     foregroundColor: Colors.white,
                  //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  //   ),
                  //   onPressed: _isLoading ? null : () async {
                  //     final LatLng? picked = await Navigator.push(
                  //       context,
                  //       MaterialPageRoute(
                  //         builder: (context) => MapAddressPickerScreen(),
                  //       ),
                  //     );
                  //     if (picked != null) {
                  //       setState(() { _isLoading = true; });
                  //       try {
                  //         // Call backend reverse-geocode API
                  //         final dio = Dio();
                  //         final url = '${AppConfig.baseUrl}/reverse-geocode/';
                  //         final response = await dio.post(url, data: {
                  //           'latitude': picked.latitude,
                  //           'longitude': picked.longitude,
                  //         });
                  //         if (response.statusCode == 200 && response.data is Map) {
                  //           final data = response.data;
                  //           setState(() {
                  //             _addressLine1Controller.text = data['address_line1'] ?? '';
                  //             _cityController.text = data['city'] ?? '';
                  //             _stateController.text = data['state'] ?? '';
                  //             _postalCodeController.text = data['postal_code'] ?? '';
                  //           });
                  //         } else {
                  //           ScaffoldMessenger.of(context).showSnackBar(
                  //             const SnackBar(content: Text('Could not fetch address from map location'), backgroundColor: Colors.red),
                  //           );
                  //         }
                  //       } catch (e) {
                  //         ScaffoldMessenger.of(context).showSnackBar(
                  //           SnackBar(content: Text('Error fetching address: $e'), backgroundColor: Colors.red),
                  //         );
                  //       } finally {
                  //         setState(() { _isLoading = false; });
                  //       }
                  //     }
                  //   },
                  // ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(left: 12.0),
                      child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
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
              DropdownButtonFormField<String>(
                value: _typeController.text.isNotEmpty ? _typeController.text : 'Home',
                items: _addressTypes.map((type) => DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Icon(
                        type == 'Home' ? Icons.home : type == 'Work' ? Icons.work : Icons.location_on,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(type),
                    ],
                  ),
                )).toList(),
                onChanged: (val) {
                  setState(() {
                    _typeController.text = val ?? 'Home';
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Address Type',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select address type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              CheckboxListTile(
                value: _setAsDefault,
                onChanged: (val) {
                  setState(() { _setAsDefault = val ?? false; });
                },
                title: const Text('Set as default address'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
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