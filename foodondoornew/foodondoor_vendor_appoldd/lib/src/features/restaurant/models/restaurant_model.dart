class Restaurant {
  final int id;
  final String name;
  final String? description;
  final String? address;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? phoneNumber;
  final String? logoUrl;
  final String? coverPhotoUrl;
  // Add other relevant fields like ratings, timings, cuisine type etc. as needed

  Restaurant({
    required this.id,
    required this.name,
    this.description,
    this.address,
    this.city,
    this.state,
    this.postalCode,
    this.phoneNumber,
    this.logoUrl,
    this.coverPhotoUrl,
  });

  // Factory constructor to create a Restaurant from JSON
  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      postalCode: json['postal_code'] as String?,
      phoneNumber: json['phone_number'] as String?,
      logoUrl: json['logo_url'] as String?,
      coverPhotoUrl: json['cover_photo_url'] as String?,
    );
  }

  // Method to convert a Restaurant instance to JSON
  // Useful if you need to send update data back to the server
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'address': address,
      'city': city,
      'state': state,
      'postal_code': postalCode,
      'phone_number': phoneNumber,
      'logo_url': logoUrl,
      'cover_photo_url': coverPhotoUrl,
    };
  }
}
