import 'package:foodondoor_delivery/models/item_model.dart';
import 'package:intl/intl.dart'; // For date parsing/formatting

class OrderModel {
  final String orderId;
  final String status;
  final DateTime orderTime; // Store as DateTime
  final String orderBy; // User ID or name who placed the order
  final String addressId;
  final double addressLatitude;
  final double addressLongitude;
  final double totalAmount;
  final List<ItemModel> items;
  final String? riderUID; // Optional: If API includes assigned rider

  OrderModel({
    required this.orderId,
    required this.status,
    required this.orderTime,
    required this.orderBy,
    required this.addressId,
    required this.addressLatitude,
    required this.addressLongitude,
    required this.totalAmount,
    required this.items,
    this.riderUID,
  });

  // Factory constructor to create an OrderModel from JSON
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    // Parse items list
    var itemsFromJson = json['items'] as List? ?? []; // Handle null or missing 'items'
    List<ItemModel> itemsList = itemsFromJson.map((itemJson) => ItemModel.fromJson(itemJson)).toList();

    // Parse timestamp - adjust format based on API output
    DateTime parsedDate;
    try {
      // Example: Expecting ISO 8601 format like "2023-10-27T10:30:00Z" or "2023-10-27T10:30:00.123456+00:00"
      parsedDate = DateTime.parse(json['order_time'] ?? DateTime.now().toIso8601String());
    } catch (e) {
      print("Error parsing order_time: ${json['order_time']}. Using current time. Error: $e");
      parsedDate = DateTime.now(); // Fallback
    }

    return OrderModel(
      orderId: json['order_id'] ?? json['id'] ?? '', // Adapt based on API
      status: json['status'] ?? 'unknown',
      orderTime: parsedDate,
      orderBy: json['ordered_by'] ?? json['user_id'] ?? 'unknown_user', // Adapt
      addressId: json['address_id'] ?? '',
      addressLatitude: (json['address_latitude'] ?? 0.0).toDouble(),
      addressLongitude: (json['address_longitude'] ?? 0.0).toDouble(),
      totalAmount: (json['total_amount'] ?? 0.0).toDouble(),
      items: itemsList,
      riderUID: json['rider_uid'], // Assigns null if not present
    );
  }

  // Method to convert OrderModel to JSON (less common for fetching, but can be useful)
  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'status': status,
      'order_time': orderTime.toIso8601String(), // Standard format
      'ordered_by': orderBy,
      'address_id': addressId,
      'address_latitude': addressLatitude,
      'address_longitude': addressLongitude,
      'total_amount': totalAmount,
      'items': items.map((item) => item.toJson()).toList(),
      'rider_uid': riderUID,
    };
  }

  // Helper for formatted date string (optional)
  String get formattedOrderTime {
    // Example format: "October 27, 2023 at 10:30 AM"
    return DateFormat('MMMM d, yyyy \'at\' hh:mm a').format(orderTime.toLocal());
  }
}
