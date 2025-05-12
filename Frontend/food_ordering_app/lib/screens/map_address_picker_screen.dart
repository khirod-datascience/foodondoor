import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class MapAddressPickerScreen extends StatefulWidget {
  final LatLng? initialPosition;
  const MapAddressPickerScreen({Key? key, this.initialPosition}) : super(key: key);

  @override
  State<MapAddressPickerScreen> createState() => _MapAddressPickerScreenState();
}

class _MapAddressPickerScreenState extends State<MapAddressPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _pickedPosition;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _determineInitialPosition();
  }

  Future<void> _determineInitialPosition() async {
    if (widget.initialPosition != null) {
      setState(() {
        _pickedPosition = widget.initialPosition;
        _loading = false;
      });
      return;
    }
    Location location = Location();
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;
    LocationData _locationData;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        setState(() { _loading = false; });
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        setState(() { _loading = false; });
        return;
      }
    }

    _locationData = await location.getLocation();
    setState(() {
      _pickedPosition = LatLng(_locationData.latitude ?? 0, _locationData.longitude ?? 0);
      _loading = false;
    });
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _pickedPosition = position;
    });
  }

  void _onConfirm() {
    if (_pickedPosition != null) {
      Navigator.of(context).pop(_pickedPosition);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Address on Map'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _pickedPosition ?? const LatLng(20.5937, 78.9629),
                    zoom: 16,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onMapCreated: (controller) => _mapController = controller,
                  onTap: _onMapTap,
                  markers: _pickedPosition != null
                      ? {
                          Marker(
                            markerId: const MarkerId('picked'),
                            position: _pickedPosition!,
                          ),
                        }
                      : {},
                ),
                Positioned(
                  bottom: 24,
                  left: 24,
                  right: 24,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text('Confirm Location'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _pickedPosition == null ? null : _onConfirm,
                  ),
                ),
              ],
            ),
    );
  }
}
