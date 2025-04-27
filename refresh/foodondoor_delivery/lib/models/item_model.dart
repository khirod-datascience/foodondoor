class ItemModel {
  final String itemId; // Assuming API provides an ID
  final String title;
  final String shortInfo;
  final int price;
  final int quantity; // Quantity for this specific item in the order

  ItemModel({
    required this.itemId,
    required this.title,
    required this.shortInfo,
    required this.price,
    required this.quantity,
  });

  // Factory constructor to create an ItemModel from JSON
  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      itemId: json['item_id'] ?? json['id'] ?? '', // Adapt based on API
      title: json['title'] ?? 'No Title',
      shortInfo: json['short_info'] ?? '',
      price: (json['price'] ?? 0).toInt(),
      quantity: (json['quantity'] ?? 0).toInt(),
    );
  }

  // Method to convert ItemModel to JSON (useful for sending data)
  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'title': title,
      'short_info': shortInfo,
      'price': price,
      'quantity': quantity,
    };
  }
}
