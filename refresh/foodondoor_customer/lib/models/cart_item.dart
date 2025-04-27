import 'food_item.dart'; // Import the FoodItem model

class CartItem {
  final int id; // Unique ID of the cart entry
  final FoodItem food; // The actual food item being ordered
  final int quantity; // How many of this item are in the cart

  CartItem({
    required this.id,
    required this.food,
    required this.quantity,
  });

  // Factory constructor to parse JSON from the API response
  factory CartItem.fromJson(Map<String, dynamic> json) {
    // Validate that 'food' exists and is a map before parsing
    if (json['food'] == null || json['food'] is! Map<String, dynamic>) {
      throw FormatException("Invalid or missing 'food' data in CartItem JSON: ${json['id']}");
    }
    
    return CartItem(
      id: json['id'] as int,
      // Parse the nested 'food' object using FoodItem.fromJson
      food: FoodItem.fromJson(json['food'] as Map<String, dynamic>),
      quantity: json['quantity'] as int,
    );
  }

  // Optional: Add a toJson method if needed for sending data (not used for GET)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'food': food.toJson(), // Assuming FoodItem has a toJson method
      'quantity': quantity,
    };
  }
}