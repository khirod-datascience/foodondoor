// import 'package:shared_preferences.dart';

// class AuthController {
//   // ...existing code...
  
//   Future<void> saveVendorId(String vendorId) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('vendor_id', vendorId);
//   }

//   Future<String?> getStoredVendorId() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString('vendor_id');
//   }

//   Future<bool> signIn(String email, String password) async {
//     try {
//       // ...existing code...
//       if (userCredential.user != null) {
//         await saveVendorId(userCredential.user!.uid);
//       }
//       // ...existing code...
//     } catch (e) {
//       // ...existing code...
//     }
//   }

//   Future<bool> signUp(String email, String password) async {
//     try {
//       // ...existing code...
//       if (userCredential.user != null) {
//         await saveVendorId(userCredential.user!.uid);
//       }
//       // ...existing code...
//     } catch (e) {
//       // ...existing code...
//     }
//   }
// }
