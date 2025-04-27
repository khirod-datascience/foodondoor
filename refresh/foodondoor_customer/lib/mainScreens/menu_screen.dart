import 'package:flutter/material.dart';
// Purpose: Displays the menu items for a specific restaurant and allows adding items to the cart.

import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../providers/cart_provider.dart';
import './home_screen.dart' show FoodCard; // Import FoodCard from home_screen
import 'dart:ui'; // For ImageFilter

class MenuScreen extends StatefulWidget {
  final String restaurantId;

  const MenuScreen({Key? key, required this.restaurantId}) : super(key: key);

  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  List<Map<String, dynamic>> _foodItems = [];
  Map<String, dynamic>? _restaurantDetails; // State for restaurant details
  bool _isLoadingMenu = true;
  bool _isLoadingDetails = true; // Separate loading for details
  String? _error;

  @override
  void initState() {
    super.initState();
    // Fetch both concurrently
    _fetchRestaurantDetails();
    _fetchFoodItems();
  }

  Future<void> _fetchRestaurantDetails() async {
    setState(() { _isLoadingDetails = true; _error = null; });
    try {
      final dio = Dio();
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      final url = '${AppConfig.baseUrl}/api/restaurants/${widget.restaurantId}/';
      final response = await dio.get(
        url,
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : {},
        ),
      );
      if (response.statusCode == 200) {
        setState(() {
          _restaurantDetails = response.data;
          _isLoadingDetails = false;
        });
      } else {
        setState(() {
          _error = response.data?['error']?.toString() ?? 'Failed to fetch restaurant details.';
          _isLoadingDetails = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching restaurant details: $e');
      setState(() { _error = 'Error fetching restaurant details.'; _isLoadingDetails = false; });
    }
  }

  Future<void> _fetchFoodItems() async {
    setState(() { _isLoadingMenu = true; }); // Use _isLoadingMenu
    try {
      final dio = Dio();
      // Assuming food items are fetched based on restaurant (vendor) ID
      final url = '${ApiService.baseUrl}/food-listings/${widget.restaurantId}/'; // Endpoint for menu items
      debugPrint('Fetching food items from: $url');
      final response = await dio.get(url);
      debugPrint('Food Items Response (${response.statusCode}): ${response.data}');

      if (response.statusCode == 200 && response.data is List) {
        _foodItems = List<Map<String, dynamic>>.from(response.data);
      } else {
        _error = (_error ?? '') + '\nFailed to load menu.'; // Append error
      }
    } catch (e) {
       _error = (_error ?? '') + '\nError loading menu: $e'; // Append error
      debugPrint('Error fetching food items: $e');
    } finally {
       if (mounted) {
         setState(() { _isLoadingMenu = false; });
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Combine loading states
    final bool isLoading = _isLoadingDetails || _isLoadingMenu;

    return Scaffold(
      // Use CustomScrollView for combining header and grid
      body: CustomScrollView(
        slivers: <Widget>[
          // AppBar that collapses
          SliverAppBar(
            expandedHeight: 200.0, // Height when fully expanded
            floating: false,
            pinned: true, // Keep visible when scrolling
            snap: false,
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                  _restaurantDetails?['name'] ?? (_isLoadingDetails ? 'Loading...' : 'Restaurant'),
                  style: const TextStyle(fontSize: 16.0, color: Colors.white, fontWeight: FontWeight.w600)
              ),
              background: _isLoadingDetails || _restaurantDetails?['image'] == null
                 ? Container(color: Colors.grey.shade300) // Placeholder background
                 : Stack(
                     fit: StackFit.expand,
                     children: [
                       Image.network(
                         _restaurantDetails!['image']!,
                         fit: BoxFit.cover,
                         errorBuilder: (c,e,s) => Container(color: Colors.grey.shade400, child: Icon(Icons.storefront, size: 60, color: Colors.white54)),
                       ),
                       // Add a gradient overlay for better title visibility
                       const DecoratedBox(
                         decoration: BoxDecoration(
                           gradient: LinearGradient(
                             begin: Alignment(0.0, 0.7),
                             end: Alignment(0.0, 0.0),
                             colors: <Color>[Color(0x60000000), Color(0x00000000)],
                           ),
                         ),
                       ),
                     ],
                   ),
               centerTitle: true, // Center title when collapsed
            ),
          ),

          // Section for Restaurant Details (optional, could be in FlexibleSpaceBar)
          if (!_isLoadingDetails && _restaurantDetails != null)
             SliverToBoxAdapter(
               child: Padding(
                 padding: const EdgeInsets.all(12.0),
                 child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text('Cuisine: ${_restaurantDetails!['cuisine_type'] ?? 'N/A'}', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                       const SizedBox(height: 4),
                       Row(
                         children: [
                            Icon(Icons.star, color: Colors.amber.shade700, size: 16),
                            const SizedBox(width: 4),
                            Text('${_restaurantDetails!['rating']?.toStringAsFixed(1) ?? 'New'}', style: const TextStyle(fontWeight: FontWeight.w500)),
                           // Add more details like address, timing if available
                         ],
                       ),
                       // Add a Divider
                       const Divider(height: 24, thickness: 1),
                       const Text('Menu Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                 ),
               ),
             ),
          
          // Show loading indicator for menu below details
          if (isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: Colors.orange)),
            )
          // Show error message if loading is done and error exists
          else if (_error != null)
             SliverFillRemaining(
               child: Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center))),
             )
          // Show message if no menu items found
          else if (_foodItems.isEmpty)
             const SliverFillRemaining(
               child: Center(child: Text('No menu items found for this restaurant.')),
             )
          // Display Menu Grid
          else 
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                ),
                itemCount: _foodItems.length,
                itemBuilder: (context, index) {
                   // Ensure vendorId is passed to FoodCard if needed for cart
                   final foodItemWithVendor = Map<String, dynamic>.from(_foodItems[index]);
                   if (foodItemWithVendor['vendor_id'] == null && _restaurantDetails?['id'] != null) {
                      foodItemWithVendor['vendor_id'] = _restaurantDetails!['id'];
                   }
                   // Wrap FoodCard with GestureDetector for tap handling
                   return GestureDetector(
                     onTap: () => _showFoodDetailsDialog(context, foodItemWithVendor),
                     child: FoodCard(food: foodItemWithVendor),
                   );
                },
              ),
            ),
        ],
      ),
    );
  }

  // --- Helper Method to Show Food Details Dialog ---
  void _showFoodDetailsDialog(BuildContext context, Map<String, dynamic> foodItem) {
    final imageUrl = foodItem['image']?.toString() ?? '';
    final description = foodItem['description']?.toString() ?? 'No description available.';
    final rating = (foodItem['rating'] as num?)?.toDouble(); // Can be null

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: EdgeInsets.zero, // Remove default padding
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image Header
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  child: _buildDialogImage(imageUrl), // Helper for dialog image
                ),
              ),
              // Details Padding
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(foodItem['name'] ?? 'Food Item', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (rating != null)
                       Padding(
                         padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                         child: Row(
                            children: [
                               Icon(Icons.star, color: Colors.amber.shade700, size: 16),
                               const SizedBox(width: 4),
                               Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w500)),
                            ],
                         ),
                       ),
                    const SizedBox(height: 8),
                    Text(description, style: const TextStyle(fontSize: 14, color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          // Optionally add "Add to Cart" button here too
          ElevatedButton(
             child: const Text('Add to Cart'),
             style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
             onPressed: () => _addToCart(context, foodItem),
          )
        ],
      ),
    );
  }

  // Helper to build image for the dialog (copied/adapted from elsewhere)
   Widget _buildDialogImage(String imageUrl) {
    Uri? uri = Uri.tryParse(imageUrl);
    bool isNetworkUrl = uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    bool isLocalAsset = imageUrl.startsWith('assets/');

    if (!isNetworkUrl && !isLocalAsset && imageUrl.startsWith('/')) {
      imageUrl = '${ApiService.baseUrl}$imageUrl';
      uri = Uri.tryParse(imageUrl);
      isNetworkUrl = uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    }

    Widget placeholder = const FittedBox(
      fit: BoxFit.contain,
      child: Icon(Icons.fastfood, size: 60, color: Colors.grey),
    );

    if (imageUrl.isEmpty || (!isNetworkUrl && !isLocalAsset)) {
      return placeholder;
    }

    if (isNetworkUrl) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        },
      );
    } else { // isLocalAsset
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    }
  }

  // Add this method to handle adding to cart with restaurant check
  Future<void> _addToCart(BuildContext context, Map<String, dynamic> foodItem) async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    
    // Make sure the food item has the restaurant info
    if (!foodItem.containsKey('restaurant_name') && _restaurantDetails?['name'] != null) {
      foodItem['restaurant_name'] = _restaurantDetails!['name'];
    }
    
    // Ensure food item has vendor_id
    if (!foodItem.containsKey('vendor_id') || foodItem['vendor_id'] == null) {
      foodItem['vendor_id'] = widget.restaurantId;
    }
    
    final result = await cart.addToCart(foodItem);
    
    if (!result['success']) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error']),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Clear Cart',
            onPressed: () => cart.clearCart(),
          ),
        ),
      );
    } else {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${foodItem['name']} added to cart'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
} 