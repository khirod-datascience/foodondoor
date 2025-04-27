class FoodItem {
  final int id;
  final String name;
  final String price; // Assuming price is returned as a string/decimal string
  final String? description;
  final bool isAvailable;
  final String? category; // Adjust type if category has its own model/ID
  final List<String> imageUrls; // List of image URLs

  FoodItem({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    required this.isAvailable,
    this.category,
    required this.imageUrls,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    // Safely handle potential null or incorrect types from API
    List<String> images = [];
    if (json['image_urls'] != null && json['image_urls'] is List) {
      images = List<String>.from(json['image_urls'].map((item) => item.toString()));
    }
    
    return FoodItem(
      id: json['id'] as int? ?? 0, // Provide default if null
      name: json['name'] as String? ?? 'Unknown Item',
      price: json['price']?.toString() ?? '0.00', // Ensure price is a string
      description: json['description'] as String?,
      isAvailable: json['is_available'] as bool? ?? false,
      category: json['category'] as String?, // Keep as String for now
      imageUrls: images,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'description': description,
      'is_available': isAvailable,
      'category': category,
      'image_urls': imageUrls,
    };
  }
}
