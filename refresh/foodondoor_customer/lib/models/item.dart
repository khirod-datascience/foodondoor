class Item {
  final String itemId; // Or int, depends on API
  final String menuId;
  final String sellerUid;
  final String title;
  final String? shortInfo;
  final String? longDescription;
  final int? price;
  final String? thumbnailUrl;
  final String? status;
  // Add other fields like publishDate etc.

  Item({
    required this.itemId,
    required this.menuId,
    required this.sellerUid,
    required this.title,
    this.shortInfo,
    this.longDescription,
    this.price,
    this.thumbnailUrl,
    this.status,
    // Add others
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      // Adjust keys to match your API response for items
      itemId: json['itemID'] as String, // e.g., 'itemID' or 'id'
      menuId: json['menuID'] as String, // e.g., 'menuID' or 'menu_id'
      sellerUid: json['sellerUID'] as String,
      title: json['title'] as String,
      shortInfo: json['shortInfo'] as String?,
      longDescription: json['longDescription'] as String?,
      price: json['price'] as int?, // Ensure correct type (int or double?)
      thumbnailUrl: json['thumbnailUrl'] as String?,
      status: json['status'] as String?,
      // Parse others
    );
  }

  Map<String, dynamic> toJson() {
     return {
       'itemID': itemId,
       'menuID': menuId,
       'sellerUID': sellerUid,
       'title': title,
       'shortInfo': shortInfo,
       'longDescription': longDescription,
       'price': price,
       'thumbnailUrl': thumbnailUrl,
       'status': status,
       // Add others
     };
   }
} 