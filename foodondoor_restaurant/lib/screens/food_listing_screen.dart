import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../globals.dart';
import '../config.dart';
import 'food_form_screen.dart'; // Import the food form screen
import 'login_signup_screen.dart'; // Import the login/signup screen

class FoodListingScreen extends StatefulWidget {
  @override
  _FoodListingScreenState createState() => _FoodListingScreenState();
}

class _FoodListingScreenState extends State<FoodListingScreen> {
  List<dynamic> _foodListings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    print("FoodListingScreen initState - vendorId: ${Globals.vendorId}");
    _loadFoodListings();
  }

  Future<void> _loadFoodListings() async {
    print("Loading food listings - vendorId: ${Globals.vendorId}");
    if (Globals.vendorId == null) {
      print("Vendor ID is null, cannot load food listings");
      _handleMissingVendorId(context);
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/auth/food-listings/${Globals.vendorId}/'),
      );
      
      print("Loading food listings for vendor ID: ${Globals.vendorId}");

      if (mounted) {
        if (response.statusCode == 200) {
          setState(() {
            _foodListings = jsonDecode(response.body);
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = "Failed to fetch food listings";
            _isLoading = false;
          });
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(_error!)),
            );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Network error";
          _isLoading = false;
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(_error!)),
          );
      }
    }
  }

  Future<void> _deleteFood(int foodId) async {
    try {
      final response = await http.delete(
        Uri.parse('${Config.baseUrl}/auth/food-listings/${Globals.vendorId}/$foodId/'), // Include vendor_id and food_id
      );

      if (response.statusCode == 204) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar() // Dismiss any existing SnackBar
          ..showSnackBar(
            SnackBar(content: Text("Food item deleted successfully")),
          );
        _loadFoodListings(); // Refresh the food listings after deletion
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar() // Dismiss any existing SnackBar
          ..showSnackBar(
            SnackBar(content: Text("Failed to delete food item")),
          );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar() // Dismiss any existing SnackBar
        ..showSnackBar(
          SnackBar(content: Text("Network error")),
        );
    }
  }

  void _handleMissingVendorId(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginSignupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Food Listings"),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FoodFormScreen()),
              ).then((_) {
                _loadFoodListings(); // Refresh food listings after returning
              });
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.orange[50],
        child: RefreshIndicator(
          onRefresh: _loadFoodListings,
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : _foodListings.isEmpty
                  ? ListView(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(height: 100),
                              Icon(Icons.no_food, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                "No food items available",
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _foodListings.length,
                      itemBuilder: (context, index) {
                        final food = _foodListings[index];
                        // Ensure food['images'] is not null and is a list before checking isNotEmpty
                        final images = food['images'];
                        final bool hasImages = images is List && images.isNotEmpty;

                        return Card(
                          elevation: 4,
                          margin: EdgeInsets.all(8),
                          child: ListTile(
                            leading: hasImages // Use the checked variable
                                ? Image.network(
                                    '${Config.baseUrl}${images[0]}', // Use the checked variable
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(Icons.broken_image, size: 50, color: Colors.grey);
                                    },
                                  )
                                : Icon(Icons.fastfood, size: 50, color: Colors.orange),
                            title: Text(food['name'] ?? 'No Name', style: TextStyle(fontWeight: FontWeight.bold)), // Add null check for name
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Price: ₹${food['price'] ?? 'N/A'}"), // Add null check for price
                                Text("Quantity: ${food['quantity'] ?? 'N/A'} ${food['unit'] ?? ''}"), // Add null checks
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => FoodFormScreen(food: food), // Pass food data for editing
                                      ),
                                    ).then((_) {
                                      _loadFoodListings(); // Refresh the food listings after editing
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    // Ensure food['id'] is not null before deleting
                                    if (food['id'] != null) {
                                      _deleteFood(food['id']);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("Cannot delete item: Missing ID")),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FoodDetailsScreen(food: food),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}

class FoodDetailsScreen extends StatelessWidget {
  final dynamic food;

  FoodDetailsScreen({required this.food});

  @override
  Widget build(BuildContext context) {
    // Ensure food['images'] is not null and is a list before checking isNotEmpty
    final images = food['images'];
    final bool hasImages = images is List && images.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(food['name'] ?? 'Food Details'), // Add null check
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            hasImages // Use the checked variable
                ? Image.network(
                    '${Config.baseUrl}${images[0]}', // Use the checked variable
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.broken_image, size: 200, color: Colors.grey);
                    },
                  )
                : Icon(Icons.fastfood, size: 200, color: Colors.orange),
            SizedBox(height: 16),
            Text("Price: ₹${food['price'] ?? 'N/A'}", style: TextStyle(fontSize: 18)), // Add null check
            Text("Quantity: ${food['quantity'] ?? 'N/A'} ${food['unit'] ?? ''}", style: TextStyle(fontSize: 18)), // Add null checks
            SizedBox(height: 16),
            Text(food['description'] ?? "No description available", style: TextStyle(fontSize: 16)), // Add null check
          ],
        ),
      ),
    );
  }
}
