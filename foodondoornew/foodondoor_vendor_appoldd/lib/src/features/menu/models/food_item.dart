import 'package:flutter/foundation.dart';

@immutable
class FoodItem {
  final String id;
  final String categoryId; // From backend serializer field 'category'
  final String restaurantId; // From backend serializer field 'restaurant'
  final String name;
  final String? description;
  final double price; // Use double for price
  final String? imageUrl;
  final bool isAvailable;
  final bool isVegetarian;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FoodItem({
    required this.id,
    required this.categoryId,
    required this.restaurantId,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    required this.isAvailable,
    required this.isVegetarian,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'] as String,
      categoryId: json['category'] as String, // Matches backend serializer field name
      restaurantId: json['restaurant'] as String, // Matches backend serializer field name
      name: json['name'] as String,
      description: json['description'] as String?,
      // Ensure price is parsed correctly (Django DecimalField -> String -> double)
      price: double.tryParse(json['price']?.toString() ?? '0.0') ?? 0.0,
      imageUrl: json['image_url'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
      isVegetarian: json['is_vegetarian'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': categoryId, // Use backend field name
      'restaurant': restaurantId, // Use backend field name
      'name': name,
      'description': description,
      'price': price.toString(), // Convert back to string if needed for API
      'image_url': imageUrl,
      'is_available': isAvailable,
      'is_vegetarian': isVegetarian,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
