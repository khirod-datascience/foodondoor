import 'package:flutter/material.dart';
// Purpose: Displays the checkout summary, uses the selected global address, and navigates to payment.

import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/cart_provider.dart';
import '../config.dart'; // For backend URL
import '../utils/globals.dart'; // For globalCustomerId, globalCurrentAddress
import '../utils/auth_storage.dart'; // For AuthStorage
import '../utils/auth_utils.dart'; // Import the refresh utility
import '../utils/auth_api.dart'; // Import AuthApi for authenticated requests
import './payment_screen.dart'; // Navigate to PaymentScreen
// import '../screens/home_screen.dart'; // Remove this to avoid ListTile ambiguity // For _formatDisplayAddress
import 'add_edit_address_screen.dart'; // For Add/Edit Address

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({Key? key}) : super(key: key);

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  // STUB: Use Current Location (to resolve build error)
  // Future<void> _useCurrentLocation(Function(Function()) setSheetState) async {
  //   setSheetState(() {});
  //   if (mounted) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Use Current Location is not implemented yet.')),
  //     );
  //   }
  // }

  List<Map<String, dynamic>> _savedAddresses = [];
  bool _isLoadingAddresses = false;
  String? _fetchError;

  Future<void> _showAddressSelectionSheet(BuildContext context) async {
    // --- Local state for the sheet ---
    bool isLocating = false;
    String? locationError;

    // --- Proactively refresh token before fetching addresses ---
    await refreshTokenIfNeeded(context);
    if (globalCustomerId == null) {
      setState(() {
        _fetchError = 'Please log in to select address.';
        _isLoadingAddresses = false;
      });
    } else {
      try {
        // Always fetch the latest token inside the closure to avoid using a stale/expired token.
        final response = await AuthApi.authenticatedRequest(() async {
          final token = await AuthStorage.getToken();
          return Dio().get(
            '${AppConfig.baseUrl}/customer/$globalCustomerId/addresses/',
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );
        });
        if (response != null && response.statusCode == 200 && response.data is List) {
          setState(() {
            _savedAddresses = List<Map<String, dynamic>>.from(response.data);
            if (globalCurrentAddress == null && _savedAddresses.isNotEmpty) {
              Map<String, dynamic>? defaultAddr = _savedAddresses.firstWhere(
                (addr) => addr['is_default'] == true,
                orElse: () => _savedAddresses.first,
              );
              globalCurrentAddress = defaultAddr;
              saveCurrentAddressId(defaultAddr['id']?.toString());
            }
          });
        } else {
          setState(() {
            _fetchError = 'Failed to load addresses. Status: ${response?.statusCode}';
          });
        }
      } catch (e) {
        setState(() {
          _fetchError = 'Error loading addresses: ${e.toString()}';
        });
      }
      setState(() {
        _isLoadingAddresses = false;
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isLoadingAddresses
                ? Center(child: CircularProgressIndicator(color: Colors.orange))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Select Delivery Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            icon: Icon(Icons.add_location_alt_outlined),
                            label: Text('Add New'),
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
                      if (_fetchError != null)
                        Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: Text(_fetchError!, style: TextStyle(color: Colors.red)))),
                      if (!_isLoadingAddresses && _fetchError == null && _savedAddresses.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(child: Text('No saved addresses found.')),
                        ),
                      ..._savedAddresses.map((address) {
                        // Use address_line_1, fallback to line1/address1
                        final addressLine1 = address['address_line_1']?.toString() ?? address['line1']?.toString() ?? address['address1']?.toString() ?? '';
                        final formatted = addressLine1.isNotEmpty ? addressLine1 : _formatDisplayAddress(address);
                        return ListTile(
                          leading: Icon(Icons.home_outlined, color: Colors.orange),
                          title: Text(formatted),
                          trailing: (globalCurrentAddress != null && globalCurrentAddress!['id'] == address['id'])
                              ? Icon(Icons.check_circle, color: Colors.green)
                              : null,
                          onTap: () async {
                            setState(() { globalCurrentAddress = address; });
                            Navigator.pop(context);
                            await _fetchDeliveryFee();
                          },
                        );
                      }).toList(),
                      // Add "Use Current Location" option
                      // ListTile(
                      //   leading: Icon(Icons.my_location, color: Colors.blue),
                      //   title: Text('Use Current Location'),
                      //   onTap: () async {
                      //     await _useCurrentLocation((fn) => setState(fn));
                      //   },
                      //   trailing: isLocating ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                      //   subtitle: locationError != null ? Text(locationError!, style: TextStyle(color: Colors.red)) : null,
                      // ),
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint('[CheckoutScreen] Refreshing token in initState...');
      await refreshTokenIfNeeded(context);
    });
    refreshTokenIfNeeded(context);
    _fetchAddressesAndSetDefault();
    _fetchDeliveryFee();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint('[CheckoutScreen] Refreshing token in didChangeDependencies...');
      await refreshTokenIfNeeded(context);
    });
  }

  Future<void> _fetchAddressesAndSetDefault() async {
    try {
      // Always fetch the latest token inside the closure to avoid using a stale/expired token.
      if (globalCustomerId == null) return;
      final response = await AuthApi.authenticatedRequest(() async {
        final token = await AuthStorage.getToken();
        return Dio().get(
          '${AppConfig.baseUrl}/customer/$globalCustomerId/addresses/',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      });
      if (response != null && response.statusCode == 200 && response.data is List) {
        _savedAddresses = List<Map<String, dynamic>>.from(response.data);
        if (globalCurrentAddress == null && _savedAddresses.isNotEmpty) {
          Map<String, dynamic>? defaultAddr = _savedAddresses.firstWhere(
            (addr) => addr['is_default'] == true,
            orElse: () => _savedAddresses.first,
          );
          setState(() {
            globalCurrentAddress = defaultAddr;
            saveCurrentAddressId(defaultAddr['id']?.toString());
          });
        }
      }
    } catch (e) {
      // ignore
    }
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

      final response = await AuthApi.authenticatedRequest(() => Dio().get(
        '${AppConfig.baseUrl}/delivery-fee/$formattedVendorId/?pin=$pincode',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      ));

      if (response != null && response.statusCode == 200) {
        setState(() {
          _deliveryFee = (response.data['delivery_fee'] as num).toDouble();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response?.data?['error']?.toString() ?? 'Failed to fetch delivery fee. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error fetching delivery fee. Please try again.';
        _isLoading = false;
      });
    }
    // Handle null response from authenticatedRequest (token/refresh failure)
    if (_error == null && _deliveryFee == null) {
      setState(() {
        _error = 'Session expired or unauthorized. Please re-login.';
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
        final itemId = entry.key;
        final item = entry.value;
        final itemName = item['name']?.toString() ?? 'Item';
        final itemQuantity = (item['quantity'] as num?)?.toInt() ?? 0;
        final itemPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
        final vendorId = item['vendor_id']?.toString() ?? '';
        final formattedVendorId = vendorId.startsWith('V') 
            ? vendorId 
            : 'V${vendorId.padLeft(3, '0')}';
        
        return {
          'food_id': itemId,
          'quantity': itemQuantity,
          'price': itemPrice,
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
                          final itemId = entry.key;
                          final itemName = item['name']?.toString() ?? 'Item';
                          final itemQuantity = (item['quantity'] as num?)?.toInt() ?? 0;
                          final itemPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '$itemQuantity x $itemName',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 22),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        Provider.of<CartProvider>(context, listen: false).decreaseQuantity(itemId);
                                        setState(() {});
                                      },
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                      child: Text('$itemQuantity', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 22),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        Provider.of<CartProvider>(context, listen: false).increaseQuantity(itemId);
                                        setState(() {});
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                                      padding: const EdgeInsets.only(left: 6),
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        Provider.of<CartProvider>(context, listen: false).removeFromCart(itemId);
                                        setState(() {});
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Removed $itemName from cart'), duration: Duration(seconds: 1)),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    Text('₹${itemPrice.toStringAsFixed(2)}'),
                                  ],
                                ),
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