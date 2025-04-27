class Menu {
  final String menuId; // Assuming ID is String, adjust if int
  final String sellerUid; // Or sellerId, depending on API
  final String menuTitle;
  final String? menuInfo;
  final String? thumbnailUrl; // Nullable?
  // Add other relevant fields like status, publishDate etc.

  Menu({
    required this.menuId,
    required this.sellerUid,
    required this.menuTitle,
    this.menuInfo,
    this.thumbnailUrl,
    // Add others
  });

  factory Menu.fromJson(Map<String, dynamic> json) {
    return Menu(
      // Adjust keys to match your API response for menus
      menuId: json['menuID'] as String? ?? '',
      sellerUid: json['sellerUID'] as String? ?? '',
      menuTitle: json['menuTitle'] as String? ?? '',
      menuInfo: json['menuInfo'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      // Parse others
    );
  }

   Map<String, dynamic> toJson() {
     return {
       'menuID': menuId,
       'sellerUID': sellerUid,
       'menuTitle': menuTitle,
       'menuInfo': menuInfo,
       'thumbnailUrl': thumbnailUrl,
       // Add others
     };
   }
} 