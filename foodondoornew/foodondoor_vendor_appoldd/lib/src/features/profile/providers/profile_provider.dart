import 'package:flutter/material.dart';
import 'package:foodondoor_vendor_app/src/features/profile/models/vendor_profile.dart';
import 'package:foodondoor_vendor_app/src/features/profile/services/profile_service.dart';
import 'package:foodondoor_vendor_app/src/features/auth/services/auth_service.dart';

enum ProfileStatus { initial, loading, loaded, error }

class ProfileProvider with ChangeNotifier {
  final ProfileService _profileService;
  final AuthService _authService;

  ProfileStatus _status = ProfileStatus.initial;
  VendorProfile? _profile;
  String _errorMessage = '';

  ProfileStatus get status => _status;
  VendorProfile? get profile => _profile;
  String get errorMessage => _errorMessage;

  ProfileProvider(this._profileService, this._authService);

  Future<void> fetchProfile() async {
    _status = ProfileStatus.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final fetchedProfile = await _profileService.getVendorProfile();
      if (fetchedProfile != null) {
        _profile = fetchedProfile;
        _status = ProfileStatus.loaded;
      } else {
        _errorMessage = 'Failed to load vendor profile data.';
        _status = ProfileStatus.error;
      }
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      _status = ProfileStatus.error;
    } finally {
      if (_status != ProfileStatus.loaded) { 
          _status = ProfileStatus.error; 
      }
      notifyListeners();
    }
  }

  void clearProfile() {
    _profile = null;
    _status = ProfileStatus.initial;
    _errorMessage = '';
    notifyListeners();
  }

  // Add methods for updating profile later
}
