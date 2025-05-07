import 'package:flutter/foundation.dart';

@immutable
class VendorProfile {
  final int id;
  final String? email;
  final String phoneNumber;
  final String businessName;
  final String? fcmToken;
  final bool isActive;
  final bool isApproved;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VendorProfile({
    required this.id,
    this.email,
    required this.phoneNumber,
    required this.businessName,
    this.fcmToken,
    required this.isActive,
    required this.isApproved,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VendorProfile.fromJson(Map<String, dynamic> json) {
    if (json['id'] == null || json['phone_number'] == null || json['business_name'] == null || json['is_active'] == null || json['is_approved'] == null || json['created_at'] == null || json['updated_at'] == null) {
      throw FormatException("Missing required fields in VendorProfile JSON: $json");
    }

    return VendorProfile(
      id: json['id'] as int,
      email: json['email'] as String?,
      phoneNumber: json['phone_number'] as String,
      businessName: json['business_name'] as String,
      fcmToken: json['fcm_token'] as String?,
      isActive: json['is_active'] as bool,
      isApproved: json['is_approved'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phone_number': phoneNumber,
      'business_name': businessName,
      'fcm_token': fcmToken,
      'is_active': isActive,
      'is_approved': isApproved,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get displayName => businessName.isNotEmpty ? businessName : phoneNumber;
}
