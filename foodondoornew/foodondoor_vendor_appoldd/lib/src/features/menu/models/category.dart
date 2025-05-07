import 'package:flutter/foundation.dart';
import 'package:foodondoor_vendor_app/src/features/menu/models/food_item.dart';

@immutable
class Category {
  final String id;
  final String restaurantId; // From backend serializer field 'restaurant'
  final String name;
  final String? description;
  final List<FoodItem> foodItems;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Category({
    required this.id,
    required this.restaurantId,
    required this.name,
    this.description,
    required this.foodItems,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    var itemsFromJson = json['food_items'] as List?;
    List<FoodItem> foodItemsList = itemsFromJson != null
        ? itemsFromJson.map((i) => FoodItem.fromJson(i as Map<String, dynamic>)).toList()
        : [];

    return Category(
      id: json['id'] as String,
      restaurantId: json['restaurant'] as String, // Matches backend field name
      name: json['name'] as String,
      description: json['description'] as String?,
      foodItems: foodItemsList,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurant': restaurantId, // Use backend field name
      'name': name,
      'description': description,
      // Note: food_items is typically read-only in GET, might not need to serialize back
      'food_items': foodItems.map<Map<String, dynamic>>((FoodItem item) => item.toJson()).toList(), 
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
