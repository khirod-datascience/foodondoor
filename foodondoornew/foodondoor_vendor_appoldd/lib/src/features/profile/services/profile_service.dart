import 'package:dio/dio.dart';
import 'package:foodondoor_vendor_app/src/constants/api_constants.dart';
import 'package:foodondoor_vendor_app/src/features/auth/services/auth_service.dart'; // To get the token
import 'package:foodondoor_vendor_app/src/features/profile/models/vendor_profile.dart';

class ProfileService {
  final Dio _dio;
  final AuthService _authService;

  ProfileService(this._dio, this._authService);

  Future<VendorProfile?> getVendorProfile() async {
    final token = await _authService.getAccessToken();
    if (token == null) {
      print('Error: No access token found for fetching vendor profile.');
      return null;
    }

    try {
      final response = await _dio.get(
        '${ApiConstants.apiBaseUrl}/vendor/profile/', // Endpoint for vendor profile
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return VendorProfile.fromJson(response.data as Map<String, dynamic>);
      } else {
        print('Error fetching vendor profile: Status Code ${response.statusCode}');
        return null;
      }
    } on DioException catch (e) {
      print('DioError fetching vendor profile: ${e.response?.data ?? e.message}');
      if (e.response?.statusCode == 401) {
        await _authService.logout(); // Simple logout for now
      }
      return null;
    } catch (e) {
      print('Unexpected error fetching vendor profile: $e');
      return null;
    }
  }

  // Add methods for updating profile later
}
