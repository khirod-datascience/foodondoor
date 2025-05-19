import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart'; // Only if needed for cart clearing, but better done before navigation
import '../config.dart';
import '../utils/globals.dart';
import '../utils/auth_storage.dart'; // <<< Import AuthStorage
import './order_success_screen.dart';
import './orders_screen.dart';
import '../providers/cart_provider.dart'; // To clear cart
import 'package:shared_preferences/shared_preferences.dart';
import '../services/paytm_service.dart';

// Purpose: Handles the selection of payment method and final order placement.

enum PaymentMethod { creditCard, upi, wallet, cod }

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final double totalAmount; // Total amount for display

  const PaymentScreen({
    Key? key,
    required this.orderData,
    required this.totalAmount,
  }) : super(key: key);

  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  PaymentMethod _selectedMethod = PaymentMethod.cod; // Default to COD
  bool _isLoading = false;
  String? _error;

  Future<void> _finalizeOrder() async {
    debugPrint('=============== PAYMENT DEBUG ===============');
    debugPrint('(PaymentScreen) _finalizeOrder called.');
    setState(() { _isLoading = true; _error = null; });

    try {
      // 1. Get auth token
      final String? token = await AuthStorage.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('ERROR: No authentication token found');
        setState(() {
          _error = 'Authentication error. Please log in again.';
          _isLoading = false;
        });
        return;
      }

      // Get the vendor ID from the first item
      final firstItem = (widget.orderData['items'] as List).first;
      final rawVendorId = firstItem['vendor_id']?.toString() ?? '';
      
      // Ensure vendor ID is in the format V001, V002, etc.
      final String formattedVendorId = _formatVendorId(rawVendorId);
      debugPrint('Using vendor ID: $formattedVendorId (original: $rawVendorId)');

      // 2. Prepare order data - use pre-calculated values from checkout
      final finalOrderData = {
        'payment_method': _selectedMethod == PaymentMethod.cod ? 'cod' : 'paytm',
        'payment_status': 'success', // Set as success for COD and online payments for testing
        'order_details': {
          'customer_id': widget.orderData['customer_id'],
          'items': (widget.orderData['items'] as List).map((item) {
            return {
              'food_id': item['food_id']?.toString() ?? item['id']?.toString() ?? '',
              'quantity': item['quantity'],
              'price': item['price'],
              'vendor_id': formattedVendorId,
            };
          }).toList(),
          'address': widget.orderData['address_id'],
          'vendor_id': formattedVendorId,
          'total_price': widget.totalAmount - (widget.orderData['delivery_fee'] ?? 0), // Subtract delivery fee from total
          'delivery_fee': widget.orderData['delivery_fee'], // Add delivery fee separately
        },
      };

      debugPrint('Order Data: $finalOrderData');

      // 3. Handle payment based on selected method
      if (_selectedMethod == PaymentMethod.cod) {
        // For COD or for online payment (simplified for now)
        final dio = Dio();
        final response = await dio.post(
          '${AppConfig.baseUrl}/place-order/',
          data: finalOrderData,
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            validateStatus: (status) => status! < 500,
          ),
        );

        debugPrint('Response status: ${response.statusCode}');
        debugPrint('Response data: ${response.data}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Clear cart after successful order
          Provider.of<CartProvider>(context, listen: false).clearCart();

          // Get order ID from response
          final orderId = response.data?['order_id']?.toString() ?? 'N/A';
          debugPrint('Order placed successfully with ID: $orderId');

          // Navigate to OrderSuccessScreen with the actual orderId
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => OrderSuccessScreen(orderId: orderId),
              ),
              (route) => route.isFirst,
            );
          }
        } else {
          setState(() {
            _error = response.data?['error']?.toString() ?? 'Failed to place order. Please try again.';
            _isLoading = false;
          });
        }
      } else {
        // For online payments - simplified for now, just use COD flow
        setState(() {
          _error = 'Online payment is not fully implemented yet. Please use COD.';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error placing order: $e');
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        if (statusCode == 401 || statusCode == 403) {
          _error = 'Authentication error. Please log in again.';
        } else if (statusCode == 400) {
          _error = e.response?.data?['error']?.toString() ?? 'Invalid order data.';
        } else if (statusCode == 404) {
          _error = 'Order service unavailable. Please try again later.';
        } else if (statusCode == 500) {
          _error = 'Server error. Please try again later or contact support.';
        } else {
          _error = 'Failed to place order. Please try again.';
        }
      } else {
        _error = 'An unexpected error occurred. Please try again.';
      }
      setState(() { _isLoading = false; });
    }
    debugPrint('=============== END PAYMENT DEBUG ===============');
  }

  // Helper method to format vendor ID to match backend expectations
  String _formatVendorId(String vendorId) {
    if (vendorId.isEmpty) return 'V001'; // Default fallback
    
    // If already in correct format (e.g., V001), return as is
    if (vendorId.startsWith('V') && vendorId.length >= 2) {
      return vendorId;
    }
    
    // Try to extract numeric part if it's just a number
    int? numericId;
    try {
      numericId = int.tryParse(vendorId);
    } catch (e) {
      numericId = null;
    }
    
    if (numericId != null) {
      // Format as V001, V002, etc.
      return 'V${numericId.toString().padLeft(3, '0')}';
    }
    
    // If we can't parse it, just prepend V
    return 'V$vendorId';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Payment Method'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Payment Summary ---
            Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 18),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Order Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ...List.generate((widget.orderData['items'] as List).length, (i) {
                      final item = widget.orderData['items'][i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text('${item['name'] ?? 'Item'} x${item['quantity']}', style: const TextStyle(fontSize: 14))),
                            Text('₹${(item['price'] as num?)?.toStringAsFixed(2) ?? '--'}', style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      );
                    }),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal:'),
                        Text('₹${(widget.orderData['subtotal'] as num?)?.toStringAsFixed(2) ?? '--'}'),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Delivery Fee:'),
                        Text('₹${(widget.orderData['delivery_fee'] as num?)?.toStringAsFixed(2) ?? '--'}'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('₹${widget.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // --- End Payment Summary ---
            Text(
              'Total Amount Payable: ₹${widget.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            const SizedBox(height: 24),
            const Text(
              'Choose Payment Option:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),

            // Payment Options
            _buildPaymentOptionTile(
              title: 'Credit/Debit Card',
              icon: Icons.credit_card,
              value: PaymentMethod.creditCard,
            ),
            _buildPaymentOptionTile(
              title: 'UPI',
              icon: Icons.currency_rupee, // Example icon
              value: PaymentMethod.upi,
            ),
            _buildPaymentOptionTile(
              title: 'Wallet',
              icon: Icons.account_balance_wallet_outlined,
              value: PaymentMethod.wallet,
            ),
            _buildPaymentOptionTile(
              title: 'Cash on Delivery (COD)',
              icon: Icons.money_outlined,
              value: PaymentMethod.cod,
            ),

            const SizedBox(height: 24), // Push button to bottom

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Column(
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _finalizeOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry Payment'),
                    ),
                  ],
                ),
              ),

            // Confirm/Pay Button
            Center(
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.orange)
                  : ElevatedButton.icon(
                      icon: Icon(_selectedMethod == PaymentMethod.cod ? Icons.check_circle_outline : Icons.payment),
                      label: Text(
                        _selectedMethod == PaymentMethod.cod ? 'Confirm Order (COD)' : 'Proceed to Pay',
                        style: const TextStyle(fontSize: 18)
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 3,
                      ),
                      onPressed: _finalizeOrder,
                    ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildPaymentOptionTile({
    required String title,
    required IconData icon,
    required PaymentMethod value,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: RadioListTile<PaymentMethod>(
        title: Text(title),
        secondary: Icon(icon, color: Colors.orange),
        value: value,
        groupValue: _selectedMethod,
        onChanged: (PaymentMethod? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedMethod = newValue;
            });
          }
        },
        activeColor: Colors.orange,
      ),
    );
  }
}
