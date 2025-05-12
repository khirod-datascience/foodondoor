import 'package:flutter/material.dart';
// Purpose: Displays the contents of the shopping cart and allows quantity adjustments and removal of items.

import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import './checkout_screen.dart'; // To navigate to checkout
import '../config.dart'; // For potential image URL correction
import '../utils/auth_utils.dart'; // Import the refresh utility

class CartScreen extends StatelessWidget {
  const CartScreen({Key? key}) : super(key: key);

  // Helper to build image widget (similar to FoodCard)
  Widget _buildCartItemImage(String imageUrl) {
    Uri? uri = Uri.tryParse(imageUrl);
    bool isNetworkUrl = uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    bool isLocalAsset = imageUrl.startsWith('assets/');

    // Handle relative paths from server
    if (!isNetworkUrl && !isLocalAsset && imageUrl.startsWith('/')) {
      imageUrl = '${AppConfig.baseUrl}$imageUrl';
      uri = Uri.tryParse(imageUrl);
      isNetworkUrl = uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    }

    if (imageUrl.isEmpty || (!isNetworkUrl && !isLocalAsset)) {
      return const Icon(Icons.fastfood, size: 40, color: Colors.grey); // Placeholder icon
    }

    if (isNetworkUrl) {
      return Image.network(
        imageUrl,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 40, color: Colors.grey), // Error placeholder
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const SizedBox(width: 50, height: 50, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        },
      );
    } else { // isLocalAsset
      return Image.asset(
        imageUrl,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 40, color: Colors.grey),
      );
    }
  }

  void _showMultiRestaurantError(BuildContext context, String? currentRestaurantName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Your cart contains items from ${currentRestaurantName ?? 'another restaurant'}. '
          'You can only order from one restaurant at a time.',
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Clear Cart',
          onPressed: () {
            Provider.of<CartProvider>(context, listen: false).clearCart();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to changes in CartProvider
    final cart = Provider.of<CartProvider>(context);

    // Check for valid checkout conditions
    final bool canCheckout = cart.items.isNotEmpty && cart.currentRestaurantId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          cart.currentRestaurantName != null 
              ? 'Order from ${cart.currentRestaurantName}'
              : 'My Cart'
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: cart.items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Your cart is empty!',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8), // Restore padding
                    itemCount: cart.items.length,
                    itemBuilder: (ctx, i) {
                      final itemEntry = cart.items.entries.elementAt(i);
                      final itemId = itemEntry.key;
                      final cartItem = itemEntry.value;
                      // Extract data safely
                      final itemName = cartItem['name']?.toString() ?? 'Unknown Item';
                      final itemPrice = (cartItem['price'] as num?)?.toDouble() ?? 0.0;
                      final itemQuantity = (cartItem['quantity'] as num?)?.toInt() ?? 0;
                      final imageUrl = cartItem['image']?.toString() ?? '';

                      // Restore Card + ListTile structure
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: _buildCartItemImage(imageUrl),
                            ),
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  itemName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), // Keep smaller font
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₹${itemPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 12, color: Colors.black54), // Keep smaller font
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 24),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => cart.decreaseQuantity(itemId),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                  child: Text('$itemQuantity', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 24),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => cart.increaseQuantity(itemId),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 22),
                                  padding: const EdgeInsets.only(left: 6),
                                  constraints: const BoxConstraints(),
                                  onPressed: () => cart.removeFromCart(itemId),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Total and Checkout Button Section
          if (cart.items.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                      Text(
                        '₹${cart.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.payment),
                    label: const Text('Checkout', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 3,
                    ),
                    onPressed: () {
                      if (cart.items.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Your cart is empty!'))
                        );
                        return;
                      }
                      
                      if (!canCheckout) {
                        _showMultiRestaurantError(context, cart.currentRestaurantName);
                        return;
                      }
                      
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const CheckoutScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
} 