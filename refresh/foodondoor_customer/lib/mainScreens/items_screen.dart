import 'package:flutter/material.dart';
import 'package:dots_indicator/dots_indicator.dart'; 
import 'package:fluttertoast/fluttertoast.dart';
import 'package:foodondoor_customer/widgets/progress_bar.dart';

import '../models/food_item.dart'; 
import '../services/api_service.dart'; 
import '../widgets/app_bar.dart'; 

class ItemsScreen extends StatefulWidget {
  final FoodItem model; 
  final String vendorId; 

  const ItemsScreen({super.key, required this.model, required this.vendorId});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  int _quantity = 1; 
  final ApiService _apiService = ApiService();
  bool _isAddingToCart = false;
  String? _addToCartError;
  final _pageController = PageController();
  double _currentPage = 0;

  @override
  void initState() {
    super.initState();
    if (widget.model.imageUrls.length > 1) {
      _pageController.addListener(() {
        setState(() {
          _currentPage = _pageController.page ?? 0;
        });
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _incrementQuantity() {
    setState(() {
      _quantity++;
      _addToCartError = null; 
    });
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() {
        _quantity--;
        _addToCartError = null; 
      });
    }
  }

  Future<void> _addToCart() async {
    if (_isAddingToCart) return; 

    setState(() {
      _isAddingToCart = true;
      _addToCartError = null;
    });

    try {
      final payload = {
        'item_id': widget.model.id, 
        'quantity': _quantity,
      };
      final response = await _apiService.post('/api/cart/add/', payload);

      if (response is Map<String, dynamic> && response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Item added to cart!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        setState(() {
          _addToCartError = response['error']?.toString() ?? 'Failed to add item to cart.';
        });
      }
    } catch (e) {
      setState(() {
        _addToCartError = 'An error occurred: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isAddingToCart = false;
      });
    }
  }

  String _calculateTotalPrice() {
    try {
      double price = double.parse(widget.model.price);
      double total = price * _quantity;
      return total.toStringAsFixed(2); 
    } catch (e) {
      return widget.model.price; 
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String totalPrice = _calculateTotalPrice();

    return Scaffold(
      appBar: AppBar(
        title: Text('Item Details', style: Theme.of(context).appBarTheme.titleTextStyle),
        centerTitle: true,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.model.imageUrls.isNotEmpty)
              SizedBox(
                height: 250, 
                child: widget.model.imageUrls.length > 1
                  ? Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          itemCount: widget.model.imageUrls.length,
                          itemBuilder: (context, index) {
                            return Image.network(
                              widget.model.imageUrls[index],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              loadingBuilder: (context, child, progress) => 
                                progress == null ? child : Center(child: circularProgress()),
                              errorBuilder: (context, error, stack) => 
                                const Center(child: Icon(Icons.broken_image, size: 60, color: Colors.grey)),
                            );
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: DotsIndicator(
                            dotsCount: widget.model.imageUrls.length,
                            position: _currentPage.round(),
                            decorator: DotsDecorator(
                              color: Colors.grey, 
                              activeColor: Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Image.network( 
                      widget.model.imageUrls[0],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 250,
                      loadingBuilder: (context, child, progress) => 
                        progress == null ? child : Center(child: circularProgress()),
                      errorBuilder: (context, error, stack) => 
                        const Center(child: Icon(Icons.broken_image, size: 60, color: Colors.grey)),
                    ),
              )
            else 
              Container(
                height: 250,
                color: Colors.grey[200],
                child: const Center(child: Icon(Icons.fastfood, size: 100, color: Colors.grey)),
              ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.model.name,
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "₹${widget.model.price}",
                    style: theme.textTheme.titleLarge?.copyWith(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (widget.model.description != null && widget.model.description!.isNotEmpty)
                    Text(
                      widget.model.description!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 24),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                        onPressed: _decrementQuantity,
                        iconSize: 30,
                      ),
                      const SizedBox(width: 15),
                      Text(
                        _quantity.toString(),
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(width: 15),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.green),
                        onPressed: _incrementQuantity,
                        iconSize: 30,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_addToCartError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Center(
                        child: Text(
                          _addToCartError!,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
           color: theme.cardColor, 
           boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), spreadRadius: 1, blurRadius: 5)],
        ),
        child: ElevatedButton.icon(
          icon: _isAddingToCart 
              ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
              : const Icon(Icons.shopping_cart_checkout),
          label: Text(_isAddingToCart ? 'Adding...' : 'Add $_quantity to Cart • ₹$totalPrice'),
          onPressed: _isAddingToCart ? null : _addToCart, 
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
               borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}
