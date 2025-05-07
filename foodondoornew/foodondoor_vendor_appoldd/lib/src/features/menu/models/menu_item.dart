import 'package:flutter/foundation.dart';

@immutable
class MenuItem {
  final String id;
  final String categoryId; // Keep as ID for simplicity in the model
  final String categoryName; // Add category name for display
  final String name;
  final String? description;
  final double price;
  final String? imageUrl; // Changed from dynamic/File to String URL
  final bool isAvailable;
  final bool isVegetarian;
  final DateTime createdAt;
  final String restaurantId; // Link back to the restaurant

  const MenuItem({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    required this.isAvailable,
    required this.isVegetarian,
    required this.createdAt,
    required this.restaurantId,
  });

  // Factory constructor for creating a new MenuItem instance from a map.
  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as String,
      categoryId: json['category_id'] as String, // Use category_id from serializer
      categoryName: json['category_name'] as String? ?? 'Unknown Category', // Use category_name
      name: json['name'] as String,
      description: json['description'] as String?,
      price: double.parse(json['price'].toString()), // Ensure price is parsed correctly
      imageUrl: json['image_url'] as String?, // Use image_url from serializer
      isAvailable: json['is_available'] as bool? ?? true,
      isVegetarian: json['is_vegetarian'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      restaurantId: json['restaurant'] as String, // Assuming restaurant ID is nested
    );
  }

  // Method for converting a MenuItem instance to a map.
  Map<String, dynamic> toJson() {
    return {
      'category_id': categoryId,
      'name': name,
      'description': description,
      'price': price.toString(),
      'is_available': isAvailable,
      'is_vegetarian': isVegetarian,
      'restaurant': restaurantId,
    };
  }

  // CopyWith method for creating a new instance with updated fields.
  MenuItem copyWith({
    String? id,
    String? categoryId,
    String? categoryName,
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    bool? isAvailable,
    bool? isVegetarian,
    DateTime? createdAt,
    String? restaurantId,
  }) {
    return MenuItem(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      isVegetarian: isVegetarian ?? this.isVegetarian,
      createdAt: createdAt ?? this.createdAt,
      restaurantId: restaurantId ?? this.restaurantId,
    );
  }

  @override
  String toString() {
    return 'MenuItem(id: $id, categoryId: $categoryId, categoryName: $categoryName, name: $name, description: $description, price: $price, imageUrl: $imageUrl, isAvailable: $isAvailable, isVegetarian: $isVegetarian, createdAt: $createdAt, restaurantId: $restaurantId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MenuItem &&
      other.id == id &&
      other.categoryId == categoryId &&
      other.categoryName == categoryName &&
      other.name == name &&
      other.description == description &&
      other.price == price &&
      other.imageUrl == imageUrl &&
      other.isAvailable == isAvailable &&
      other.isVegetarian == isVegetarian &&
      other.createdAt == createdAt &&
      other.restaurantId == restaurantId;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      categoryId.hashCode ^
      categoryName.hashCode ^
      name.hashCode ^
      description.hashCode ^
      price.hashCode ^
      imageUrl.hashCode ^
      isAvailable.hashCode ^
      isVegetarian.hashCode ^
      createdAt.hashCode ^
      restaurantId.hashCode;
  }
}
