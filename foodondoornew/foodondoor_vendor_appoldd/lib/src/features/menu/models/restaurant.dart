import 'package:flutter/foundation.dart' hide Category;
import 'package:foodondoor_vendor_app/src/features/menu/models/category.dart';

@immutable
class Restaurant {
  final String id;
  final String vendorId; // From backend serializer field 'vendor'
  final String name;
  final String? description;
  final String address;
  final String city;
  final String state;
  final String postalCode;
  final String? phoneNumber;
  final String? logoUrl;
  final String? coverPhotoUrl;
  final double? latitude;
  final double? longitude;
  final bool isActive;
  final List<Category> categories;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Restaurant({
    required this.id,
    required this.vendorId,
    required this.name,
    this.description,
    required this.address,
    required this.city,
    required this.state,
    required this.postalCode,
    this.phoneNumber,
    this.logoUrl,
    this.coverPhotoUrl,
    this.latitude,
    this.longitude,
    required this.isActive,
    required this.categories,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    var categoriesFromJson = json['categories'] as List?;
    List<Category> categoriesList = categoriesFromJson != null
        ? categoriesFromJson.map((c) => Category.fromJson(c as Map<String, dynamic>)).toList()
        : [];

    return Restaurant(
      id: json['id'] as String,
      vendorId: json['vendor'] as String, // Matches backend field name
      name: json['name'] as String,
      description: json['description'] as String?,
      address: json['address'] as String,
      city: json['city'] as String,
      state: json['state'] as String,
      postalCode: json['postal_code'] as String,
      phoneNumber: json['phone_number'] as String?,
      logoUrl: json['logo_url'] as String?,
      coverPhotoUrl: json['cover_photo_url'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(), // Handle potential null and type
      longitude: (json['longitude'] as num?)?.toDouble(), // Handle potential null and type
      isActive: json['is_active'] as bool? ?? true,
      categories: categoriesList,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    // Primarily used for reading data, serialization might not be fully needed yet
    return {
      'id': id,
      'vendor': vendorId, // Use backend field name
      'name': name,
      'description': description,
      'address': address,
      'city': city,
      'state': state,
      'postal_code': postalCode,
      'phone_number': phoneNumber,
      'logo_url': logoUrl,
      'cover_photo_url': coverPhotoUrl,
      'latitude': latitude,
      'longitude': longitude,
      'is_active': isActive,
      // Note: categories is typically read-only in GET
      'categories': categories.map<Map<String, dynamic>>((Category cat) => cat.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
