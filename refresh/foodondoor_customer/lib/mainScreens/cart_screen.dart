import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../mainScreens/address_screen.dart';
import '../models/cart_item.dart';
import '../services/api_service.dart';
import '../widgets/cart_item_design.dart';
import '../widgets/progress_bar.dart';
import '../widgets/text_widget_header.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<CartItem> _cartItems = [];
  bool _isLoading = true;
  String? _errorMessage;
  double _totalAmount = 0.0;
  String? _vendorId;
  bool _isUpdating = false;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchCartItems();
  }

  Future<void> _fetchCartItems({bool showLoading = true}) async {
    if (mounted) {
      setState(() {
        if (showLoading) _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await _apiService.getCart();

      if (mounted && response['success'] == true) {
        final List<dynamic> itemsData = response['items'] ?? [];
        final dynamic rawTotal = response['total_amount'] ?? 0;
        final dynamic vendorData = response['vendor'];

        _cartItems = itemsData.map((json) => CartItem.fromJson(json)).toList();
        _vendorId = vendorData?['id']?.toString();

        _totalAmount = _calculateTotal(_cartItems);
      } else if (mounted) {
        _errorMessage = "Error fetching cart: ${response['error'] ?? 'Unknown API error'}";
        _cartItems = [];
        _totalAmount = 0.0;
        _vendorId = null;
        print("Error fetching cart items: ${response['error']}");
      }
    } catch (e) {
      if (mounted) {
        _errorMessage = "An error occurred: ${e.toString()}";
        _cartItems = [];
        _totalAmount = 0.0;
        _vendorId = null;
      }
      print("Exception fetching cart items: $e");
    } finally {
      if (mounted) {
        setState(() {
          if (showLoading) _isLoading = false;
        });
      }
    }
  }

  double _calculateTotal(List<CartItem> items) {
    double total = 0.0;
    for (var item in items) {
      double price = double.tryParse(item.food.price) ?? 0.0;
      total += price * item.quantity;
    }
    return total;
  }

  Future<void> _updateItemQuantity(int cartItemId, int newQuantity) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);

    try {
      final endpoint = '/api/cart/update/$cartItemId/';
      final response = await _apiService.put(endpoint, {'quantity': newQuantity});

      if (response['success'] == true) {
        Fluttertoast.showToast(msg: response['message'] ?? 'Quantity updated');
        await _fetchCartItems(showLoading: false);
      } else {
        Fluttertoast.showToast(msg: response['error'] ?? 'Failed to update quantity', backgroundColor: Colors.red);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error: ${e.toString()}', backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _removeItem(int cartItemId) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);

    try {
      final endpoint = '/api/cart/update/$cartItemId/';
      final response = await _apiService.delete(endpoint);

      if (response['success'] == true) {
        Fluttertoast.showToast(msg: response['message'] ?? 'Item removed');
        await _fetchCartItems(showLoading: false);
      } else {
        Fluttertoast.showToast(msg: response['error'] ?? 'Failed to remove item', backgroundColor: Colors.red);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error: ${e.toString()}', backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Cart', style: Theme.of(context).appBarTheme.titleTextStyle),
        centerTitle: true,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _cartItems.isNotEmpty && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _isUpdating
                  ? null
                  : () {
                      if (_vendorId == null) {
                        Fluttertoast.showToast(msg: 'Vendor information missing. Cannot proceed.');
                        return;
                      }
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => AddressScreen(
                                    totalAmount: _totalAmount,
                                    sellerUID: _vendorId!,
                                  )));
                    },
              label: Text("Proceed to Checkout (₹${_totalAmount.toStringAsFixed(2)})", style: const TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: _isUpdating ? Colors.grey : Colors.redAccent,
              icon: _isUpdating
                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.payment),
            )
          : null,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: TextWidgetHeader(title: "Review Your Items"),
              ),
              if (_isLoading)
                SliverFillRemaining(
                  child: Center(child: circularProgress()),
                ),
              if (!_isLoading && _errorMessage != null)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    ),
                  ),
                ),
              if (!_isLoading && _errorMessage == null && _cartItems.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.remove_shopping_cart_outlined, size: 80, color: Colors.grey),
                        SizedBox(height: 10),
                        Text("Your cart is empty.", style: TextStyle(fontSize: 18, color: Colors.grey)),
                        Text("Add items from restaurants to see them here.", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              if (!_isLoading && _errorMessage == null && _cartItems.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 80),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        CartItem model = _cartItems[index];
                        return CartItemDesign(
                          model: model,
                          onQuantityIncreased: () => _updateItemQuantity(model.id, model.quantity + 1),
                          onQuantityDecreased: model.quantity > 1 ? () => _updateItemQuantity(model.id, model.quantity - 1) : null,
                          onItemRemoved: () => _removeItem(model.id),
                        );
                      },
                      childCount: _cartItems.length,
                    ),
                  ),
                ),
            ],
          ),
          if (_isUpdating)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: circularProgress(),
              ),
            ),
        ],
      ),
    );
  }
}
