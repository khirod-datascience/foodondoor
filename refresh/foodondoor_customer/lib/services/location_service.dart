// // Make sure to add 'location: ^5.0.0' (or latest) to pubspec.yaml dependencies
// import 'package:location/location.dart';

// class LocationService {
//   static Future<Map<String, double>?> getCurrentLocation() async {
//     Location location = Location();
//     bool _serviceEnabled;
//     PermissionStatus _permissionGranted;
//     LocationData _locationData;

//     _serviceEnabled = await location.serviceEnabled();
//     if (!_serviceEnabled) {
//       _serviceEnabled = await location.requestService();
//       if (!_serviceEnabled) {
//         return null;
//       }
//     }

//     _permissionGranted = await location.hasPermission();
//     if (_permissionGranted == PermissionStatus.denied) {
//       _permissionGranted = await location.requestPermission();
//       if (_permissionGranted != PermissionStatus.granted) {
//         return null;
//       }
//     }

//     _locationData = await location.getLocation();
//     if (_locationData.latitude == null || _locationData.longitude == null) {
//       return null;
//     }
//     return {
//       'latitude': _locationData.latitude!,
//       'longitude': _locationData.longitude!,
//     };
//   }
// }
