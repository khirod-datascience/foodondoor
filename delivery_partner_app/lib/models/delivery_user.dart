class DeliveryUser {
  final String id;
  final String name;
  final String phoneNumber;
  final String? email;
  final String? profilePictureUrl; // Optional

  DeliveryUser({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.email,
    this.profilePictureUrl,
  });

  // Factory constructor to create a DeliveryUser from JSON
  factory DeliveryUser.fromJson(Map<String, dynamic> json) {
    return DeliveryUser(
      id: json['id'] ?? '', // Provide default or handle error
      name: json['name'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      email: json['email'],
      profilePictureUrl: json['profile_picture_url'],
    );
  }

  // Method to convert a DeliveryUser instance to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone_number': phoneNumber,
      'email': email,
      'profile_picture_url': profilePictureUrl,
    };
  }
}
