class Vendor {
  final int id; // Assuming integer ID from backend
  final String sellerName;
  final String sellerEmail;
  final String? sellerAvatarUrl; // Make nullable if it might be absent
  final String? sellerAddress;   // Make nullable if it might be absent
  // Add other relevant fields based on your API response (e.g., rating, cuisine type)

  Vendor({
    required this.id,
    required this.sellerName,
    required this.sellerEmail,
    this.sellerAvatarUrl,
    this.sellerAddress,
    // Add other fields to constructor
  });

  // Factory constructor to parse JSON data from API response
  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      sellerName: json['sellerName'] as String? ?? '',
      sellerEmail: json['sellerEmail'] as String? ?? '',
      sellerAvatarUrl: json['sellerAvatarUrl'] as String? ?? '',
      sellerAddress: json['sellerAddress'] as String? ?? '',
      // Parse other fields, always use null-aware defaulting for String fields
    );
  }

  // Optional: Method to convert Vendor object back to JSON (if needed for sending data)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sellerName': sellerName,
      'sellerEmail': sellerEmail,
      'sellerAvatarUrl': sellerAvatarUrl,
      'sellerAddress': sellerAddress,
      // Add other fields
    };
  }
}

// Replace the old Sellers model if it exists in another file (e.g., models/sellers.dart)
// or ensure it's no longer used where Vendor is used. 