import 'package:flutter/material.dart';
// Purpose: Displays the checkout summary, uses the selected global address, and navigates to payment.

import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../providers/cart_provider.dart';
import '../config.dart'; // For backend URL
import '../utils/globals.dart'; // For globalCustomerId, globalCurrentAddress
import '../utils/auth_storage.dart'; // For AuthStorage
import '../utils/auth_utils.dart'; // Import the refresh utility
import './payment_screen.dart'; // Navigate to PaymentScreen
import './home_screen.dart'; // For _formatDisplayAddress
import 'add_edit_address_screen.dart'; // For Add/Edit Address

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({Key? key}) : super(key: key);

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  List<Map<String, dynamic>> _savedAddresses = [];
  bool _isLoadingAddresses = false;

  Future<void> _showAddressSelectionSheet(BuildContext context) async {
    setState(() { _isLoadingAddresses = true; });
    try {
      final String? token = await AuthStorage.getToken();
      if (token == null || token.isEmpty || globalCustomerId == null) {
        setState(() { _isLoadingAddresses = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to select address')));
        return;
      }
      final dio = Dio();
      final url = '${AppConfig.baseUrl}/customer/$globalCustomerId/addresses/';
      final response = await dio.get(url, options: Options(headers: {'Authorization': 'Bearer $token'}));
      if (response.statusCode == 200 && response.data is List) {
        _savedAddresses = List<Map<String, dynamic>>.from(response.data);
      } else {
        _savedAddresses = [];
      }
    } catch (e) {
      _savedAddresses = [];
    } finally {
      setState(() { _isLoadingAddresses = false; });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isLoadingAddresses
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Select Delivery Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            icon: const Icon(Icons.add_location_alt_outlined),
                            label: const Text('Add New'),
                            onPressed: () async {
                              Navigator.pop(context);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => AddEditAddressScreen()),
                              );
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                      const Divider(),
                      if (_savedAddresses.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(child: Text('No saved addresses found.')),
                        ),
                      ..._savedAddresses.map((address) {
                        final formatted = _formatDisplayAddress(address);
                        return ListTile(
                          leading: const Icon(Icons.home_outlined, color: Colors.orange),
                          title: Text(formatted),
                          trailing: (globalCurrentAddress != null && globalCurrentAddress!['id'] == address['id'])
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : null,
                          onTap: () async {
                            setState(() { globalCurrentAddress = address; });
                            Navigator.pop(context);
                            await _fetchDeliveryFee();
                          },
                        );
                      }).toList(),
                    ],
                  ),
          ),
        );
      },
    );
  }

  bool _isLoading = false;
  double? _deliveryFee;
  String? _error;

  @override
  void initState() {
    super.initState();
    refreshTokenIfNeeded(context);
    _fetchDeliveryFee();
  }

  Future<void> _fetchDeliveryFee() async {
    setState(() { _isLoading = true; _error = null; });
    
    try {
      final String? token = await AuthStorage.getToken();
      if (token == null || token.isEmpty) {
        setState(() {
          _error = 'Authentication error. Please log in again.';
          _isLoading = false;
        });
        return;
      }

      // Get the first item's vendor_id to fetch delivery fee
      final cart = Provider.of<CartProvider>(context, listen: false);
      if (cart.items.isEmpty) {
        setState(() {
          _error = 'Cart is empty';
          _isLoading = false;
        });
        return;
      }

      // Check if address is selected
      if (globalCurrentAddress == null) {
        setState(() {
          _error = 'Please select a delivery address first';
          _isLoading = false;
        });
        return;
      }

      // Get the pincode from the address
      final pincode = globalCurrentAddress!['pincode']?.toString() ?? '';
      if (pincode.isEmpty) {
        setState(() {
          _error = 'Invalid delivery address: missing pincode';
          _isLoading = false;
        });
        return;
      }

      final firstItem = cart.items.entries.first.value;
      final vendorId = firstItem['vendor_id']?.toString() ?? '';
      final formattedVendorId = vendorId.startsWith('V') 
          ? vendorId 
          : 'V${vendorId.padLeft(3, '0')}';

      final dio = Dio();
      print(pincode);
      final response = await dio.get(
        '${AppConfig.baseUrl}/delivery-fee/$formattedVendorId/?pin=$pincode',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        setState(() {
          _deliveryFee = (response.data['delivery_fee'] as num).toDouble();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.data?['error']?.toString() ?? 'Failed to fetch delivery fee. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error fetching delivery fee. Please try again.';
        _isLoading = false;
      });
    }
  }

  // Reusing address formatting logic (could be moved to utils)
  String _formatDisplayAddress(Map<String, dynamic>? address) {
    if (address == null) return 'No address selected';
    
    final line1 = address['address_line_1']?.toString() ?? '';
    final line2 = address['address_line_2']?.toString() ?? '';
    final city = address['city']?.toString() ?? '';
    final state = address['state']?.toString() ?? '';
    final pincode = address['pincode']?.toString() ?? '';
    
    List<String> parts = [];
    if (line1.isNotEmpty) parts.add(line1);
    if (line2.isNotEmpty) parts.add(line2);
    if (city.isNotEmpty) parts.add(city);
    if (state.isNotEmpty) parts.add(state);
    if (pincode.isNotEmpty) parts.add(pincode);

    return parts.isEmpty ? 'Address Details Missing' : parts.join(', '); 
  }

  // This function now prepares data and navigates to PaymentScreen
  void _proceedToPayment(CartProvider cart) {
    if (_error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error!), backgroundColor: Colors.red),
      );
      return;
    }
    if (globalCurrentAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery address from the Home screen.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (globalCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: User not logged in.'), backgroundColor: Colors.red),
      );
      return;
    }
    
    // Get the selected address ID
    final addressId = globalCurrentAddress!['id'];
    if (addressId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Error: Selected address has no ID.'), backgroundColor: Colors.red),
       );
       return;
    }

    if (_deliveryFee == null) {
      // Silently fetch delivery fee without showing a message
      _fetchDeliveryFee().then((_) {
        if (_deliveryFee != null) {
          _proceedToPayment(cart);
        }
      });
      return;
    }

    // Calculate total amount including delivery fee
    final totalAmount = cart.totalAmount + _deliveryFee!;

    // Prepare order data with all calculations done
    final orderData = {
      'customer_id': globalCustomerId,
      'address_id': addressId,
      'total_amount': totalAmount,
      'delivery_fee': _deliveryFee,
      'items': cart.items.entries.map((entry) {
        final item = entry.value;
        final vendorId = item['vendor_id']?.toString() ?? '';
        final formattedVendorId = vendorId.startsWith('V') 
            ? vendorId 
            : 'V${vendorId.padLeft(3, '0')}';
        
        return {
          'food_id': entry.key,
          'quantity': item['quantity'],
          'price': item['price'],
          'vendor_id': formattedVendorId,
          'name': item['name'] ?? '',
          'image': item['image'] ?? '',
        };
      }).toList(),
    };

    debugPrint('Proceeding to payment with order data: $orderData');

    // Navigate to Payment Screen with pre-calculated total
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          orderData: orderData,
          totalAmount: totalAmount, // Pass the total amount including delivery fee
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final displayAddress = _formatDisplayAddress(globalCurrentAddress);
    
    // Use fetched delivery fee or show loading
    final deliveryFee = _deliveryFee ?? 0.0;
    final finalTotal = cart.totalAmount + deliveryFee;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.orange))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Delivery Address Section - Now displays globalCurrentAddress
                const Text('Delivery Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Card(
                  elevation: 2,
                  child: InkWell(
                    onTap: () async {
                      await _showAddressSelectionSheet(context);
                    },
                    child: ListTile(
                      leading: const Icon(Icons.location_on_outlined, color: Colors.orange),
                      title: Text(displayAddress),
                      trailing: const Icon(Icons.arrow_drop_down),
                      subtitle: (globalCurrentAddress != null && (globalCurrentAddress!['pincode'] == null || globalCurrentAddress!['pincode'].toString().isEmpty))
                        ? Text(
                            'Current location missing pincode. Please save as address or select from saved.',
                            style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                          )
                        : null,
                    ),
                  ),
                ),
                if (globalCurrentAddress == null || (globalCurrentAddress!['pincode'] == null || globalCurrentAddress!['pincode'].toString().isEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            (globalCurrentAddress == null)
                              ? 'Please select a delivery address.'
                              : 'Selected location is missing pincode. Please save as address or select from saved.',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_location_alt),
                          label: const Text('Add Address'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => AddEditAddressScreen()),
                            );
                            setState(() {}); // Refresh after returning
                          },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),

                // Order Summary Section
                const Text('Order Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        ...cart.items.entries.map((entry) {
                          final item = entry.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item['quantity']}x ${item['name'] ?? 'Item'}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text('₹${((item['price'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}'),
                              ],
                            ),
                          );
                        }).toList(),
                        const Divider(height: 20, thickness: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal'),
                              Text('₹${cart.totalAmount.toStringAsFixed(2)}'),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Delivery Fee'),
                              Text('₹${deliveryFee.toStringAsFixed(2)}'),
                            ],
                          ),
                        ),
                        const Divider(height: 20, thickness: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(
                                '₹${finalTotal.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),

                // Proceed to Payment Button
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.payment),
                    label: const Text('Proceed to Payment', style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 3,
                    ),
                    onPressed: (globalCurrentAddress == null || cart.items.isEmpty || _error != null)
                        ? null
                        : () => _proceedToPayment(cart),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }
} 