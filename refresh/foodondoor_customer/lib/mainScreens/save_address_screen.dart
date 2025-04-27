import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../widgets/progress_bar.dart';

class SaveAddressScreen extends StatefulWidget {
  const SaveAddressScreen({super.key});

  @override
  State<SaveAddressScreen> createState() => _SaveAddressScreenState();
}

class _SaveAddressScreenState extends State<SaveAddressScreen> {
  final TextEditingController _addressLine1 = TextEditingController();
  final TextEditingController _addressLine2 = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _state = TextEditingController();
  final TextEditingController _pincode = TextEditingController();

  final formKey = GlobalKey<FormState>();
  List<Placemark>? placemarks;
  Position? position;
  bool _isLoading = false; 
  final ApiService _apiService = ApiService(); 

  @override
  void dispose() {
    _addressLine1.dispose();
    _addressLine2.dispose();
    _city.dispose();
    _state.dispose();
    _pincode.dispose();
    super.dispose();
  }

  Future<void> _getUserLocationAddress() async { 
    if (_isLoading) return;
    setState(() { _isLoading = true; }); 
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
       Fluttertoast.showToast(msg: "Location permission denied.");
       if (mounted) setState(() { _isLoading = false; });
       return;
    }

    try {
      Position newPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      position = newPosition;
      placemarks = await placemarkFromCoordinates(position!.latitude, position!.longitude);

      if (placemarks != null && placemarks!.isNotEmpty) {
        Placemark pMarks = placemarks![0];

        if (mounted) {
            setState(() {
              _addressLine1.text = "${pMarks.subThoroughfare ?? ''} ${pMarks.thoroughfare ?? ''}".trim();
              _addressLine2.text = "${pMarks.subLocality ?? ''} ${pMarks.locality ?? ''}".trim(); 
              _city.text = pMarks.subAdministrativeArea ?? ''; 
              _state.text = pMarks.administrativeArea ?? ''; 
              _pincode.text = pMarks.postalCode ?? '';
            });
        }
      } else {
        Fluttertoast.showToast(msg: "Could not determine address from location.");
      }
    } catch (e) {
       Fluttertoast.showToast(msg: "Failed to get location or address: ${e.toString()}");
    } finally {
       if (mounted) setState(() { _isLoading = false; }); 
    }
  }

  Future<void> _saveAddress() async { 
    if (formKey.currentState!.validate()) {
      if (_isLoading) return;
      setState(() { _isLoading = true; });

      final Map<String, dynamic> addressData = {
        'address_line1': _addressLine1.text.trim(),
        'address_line2': _addressLine2.text.trim(),
        'city': _city.text.trim(),
        'state': _state.text.trim(),
        'pincode': _pincode.text.trim(),
      };

      try {
         await _apiService.addAddress(addressData);
         Fluttertoast.showToast(msg: "New Address Saved Successfully.");
         formKey.currentState!.reset(); 
         if (mounted) Navigator.pop(context, true);
      } catch (e) {
         Fluttertoast.showToast(msg: "Error saving address: ${e.toString()}");
          if (mounted) {
           setState(() { _isLoading = false; });
         }
      } 
    } else {
       Fluttertoast.showToast(msg: "Please fill the form completely.");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Save Address"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
            colors: [
              Colors.cyan,
              Colors.amber,
            ],
            begin: FractionalOffset(0.0, 0.0),
            end: FractionalOffset(1.0, 0.0),
            stops: [0.0, 1.0],
            tileMode: TileMode.clamp,
          )),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _saveAddress, 
        label: _isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
            : const Text("Save Now"),
        icon: _isLoading ? null : const Icon(Icons.save), 
        backgroundColor: Colors.cyan,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15.0), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, 
          children: [
            const SizedBox(height: 10),
             ElevatedButton.icon(
              onPressed: _isLoading ? null : _getUserLocationAddress,
              icon: const Icon(Icons.location_on, color: Colors.white),
              style: ElevatedButton.styleFrom(
                 backgroundColor: Colors.amber,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                 padding: const EdgeInsets.symmetric(vertical: 12), 
              ),
              label: const Text("Get My Current Location", style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
            const SizedBox(height: 20),
            const Text(
              "Enter Address Details:",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.left,
            ),
             const SizedBox(height: 10),
            Form(
              key: formKey,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextFormField(
                      controller: _addressLine1,
                      decoration: const InputDecoration(
                        labelText: 'Address Line 1 *',
                        hintText: 'House No, Building, Street, Area',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Please enter Address Line 1' : null,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextFormField(
                      controller: _addressLine2,
                      decoration: const InputDecoration(
                        labelText: 'Address Line 2',
                        hintText: 'Landmark, etc. (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextFormField(
                      controller: _city,
                      decoration: const InputDecoration(
                        labelText: 'City *',
                        hintText: 'Enter your city',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Please enter City' : null,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextFormField(
                      controller: _state,
                      decoration: const InputDecoration(
                        labelText: 'State / Country *',
                        hintText: 'Enter your state or country',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Please enter State/Country' : null,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextFormField(
                      controller: _pincode,
                      decoration: const InputDecoration(
                        labelText: 'Pin Code *',
                        hintText: 'Enter your pin code',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value == null || value.isEmpty ? 'Please enter Pin Code' : null,
                    ),
                  ),
                   const SizedBox(height: 80), 
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
