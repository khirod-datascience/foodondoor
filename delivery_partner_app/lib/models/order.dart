import 'package:flutter/foundation.dart'; // For @required

enum OrderStatus {
  pending,      // Assigned to delivery partner, awaiting acceptance
  accepted,     // Delivery partner accepted
  rejected,     // Delivery partner rejected
  preparing,    // Restaurant is preparing (optional, might be handled by restaurant app)
  readyForPickup, // Ready for pickup
  pickedUp,     // Picked up by delivery partner
  outForDelivery, // On the way to customer
  delivered,    // Delivered to customer
  cancelled     // Order cancelled
}

class Address {
  final String street;
  final String city;
  final String state;
  final String postalCode;
  final double? latitude; // Optional, for map integration
  final double? longitude; // Optional, for map integration

  Address({
    required this.street,
    required this.city,
    required this.state,
    required this.postalCode,
    this.latitude,
    this.longitude,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      street: json['street'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      postalCode: json['postal_code'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'street': street,
      'city': city,
      'state': state,
      'postal_code': postalCode,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  @override
  String toString() {
    return '$street, $city, $state $postalCode';
  }
}

class OrderItem {
  final String productId;
  final String name;
  final int quantity;
  final double price; // Price per item at the time of order

  OrderItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['product_id'] ?? '',
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'name': name,
      'quantity': quantity,
      'price': price,
    };
  }
}

class Order {
  final String id;
  final String orderNumber; // User-friendly order number
  final OrderStatus status;
  final String customerName;
  final String customerPhoneNumber;
  final String restaurantName;
  final Address restaurantAddress;
  final Address deliveryAddress;
  final List<OrderItem> items;
  final double orderTotal; // Includes items, taxes, delivery fee etc.
  final double deliveryFee;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;

  Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.customerName,
    required this.customerPhoneNumber,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.deliveryAddress,
    required this.items,
    required this.orderTotal,
    required this.deliveryFee,
    required this.createdAt,
    this.acceptedAt,
    this.pickedUpAt,
    this.deliveredAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    var statusString = json['status'] ?? 'pending';
    OrderStatus statusEnum = OrderStatus.values.firstWhere(
      (e) => describeEnum(e) == statusString,
      orElse: () => OrderStatus.pending // Default status if parse fails
    );

    var itemsList = (json['items'] as List<dynamic>? ?? [])
        .map((itemJson) => OrderItem.fromJson(itemJson as Map<String, dynamic>))
        .toList();

    return Order(
      id: json['id'] ?? '',
      orderNumber: json['order_number'] ?? '',
      status: statusEnum,
      customerName: json['customer_name'] ?? '',
      customerPhoneNumber: json['customer_phone_number'] ?? '',
      restaurantName: json['restaurant_name'] ?? '',
      restaurantAddress: Address.fromJson(json['restaurant_address'] ?? {}),
      deliveryAddress: Address.fromJson(json['delivery_address'] ?? {}),
      items: itemsList,
      orderTotal: (json['order_total'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      acceptedAt: DateTime.tryParse(json['accepted_at'] ?? ''),
      pickedUpAt: DateTime.tryParse(json['picked_up_at'] ?? ''),
      deliveredAt: DateTime.tryParse(json['delivered_at'] ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'status': describeEnum(status), // Convert enum to string
      'customer_name': customerName,
      'customer_phone_number': customerPhoneNumber,
      'restaurant_name': restaurantName,
      'restaurant_address': restaurantAddress.toJson(),
      'delivery_address': deliveryAddress.toJson(),
      'items': items.map((item) => item.toJson()).toList(),
      'order_total': orderTotal,
      'delivery_fee': deliveryFee,
      'created_at': createdAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'picked_up_at': pickedUpAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
    };
  }
}
