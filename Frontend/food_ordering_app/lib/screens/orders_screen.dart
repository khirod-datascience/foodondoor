import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../config.dart';
import '../utils/globals.dart';
import '../utils/auth_storage.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'order_details_screen.dart';
import 'order_tracking_screen.dart';

class OrdersScreen extends StatefulWidget {
  final bool showInProgressSnackbar;
  const OrdersScreen({Key? key, this.showInProgressSnackbar = false}) : super(key: key);

  @override
  _OrdersScreenState createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> _allOrders = [];
  final List<Map<String, dynamic>> _inProgressOrders = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _fetchOrders(inProgressOnly: _tabController.index == 1);
    });
    _fetchOrders(inProgressOnly: false);
    // If requested, show snackbar for recent in-progress order after fetching
    if (widget.showInProgressSnackbar) {
      Future.delayed(const Duration(milliseconds: 600), () async {
        await _fetchOrders(inProgressOnly: true);
        if (mounted) showRecentInProgressOrderSnackbar(context);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders({bool inProgressOnly = true}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      debugPrint('Fetching ' + (inProgressOnly ? 'in-progress' : 'all') + ' orders for customer ID: $globalCustomerId');
      
      if (globalCustomerId == null) {
        setState(() {
          _error = 'You need to be logged in to view orders';
          _isLoading = false;
        });
        return;
      }

      // Get auth token
      final token = await AuthStorage.getToken();
      if (token == null) {
        setState(() {
          _error = 'Authentication required';
          _isLoading = false;
        });
        return;
      }
      
      debugPrint('(AuthStorage) Retrieved token: ${token.substring(0, min(10, token.length))}...');
      
      // Use HTTP POST method (backend expects this)
      try {
        final response = await http.post(
          Uri.parse('${AppConfig.baseUrl}/my-orders/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
          body: jsonEncode({
            'customer_id': globalCustomerId,
            if (inProgressOnly) 'inprogress': true,
          }),
        );
        
        debugPrint('Orders API response status: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final List<dynamic> orderData = jsonDecode(response.body);
          setState(() {
            if (inProgressOnly) {
              _inProgressOrders.clear();
              _inProgressOrders.addAll(orderData.map((order) => Map<String, dynamic>.from(order)).toList());
            } else {
              _allOrders.clear();
              _allOrders.addAll(orderData.map((order) => Map<String, dynamic>.from(order)).toList());
            }
            _isLoading = false;
          });
        } else {
          debugPrint('Error response: ${response.statusCode} - ${response.body}');
          setState(() {
            _error = 'Failed to load orders. Please try again later.';
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint('Error during POST request: $e');
        // Try backup approach using a GET request with query parameters
        try {
          final url = '${AppConfig.baseUrl}/customer-orders/?customer_id=$globalCustomerId';
          debugPrint('Trying alternate URL: $url');
          
          final response = await http.get(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $token'
            },
          );
          
          debugPrint('Orders API (alternate) response status: ${response.statusCode}');
          
          if (response.statusCode == 200) {
            final List<dynamic> orderData = jsonDecode(response.body);
            setState(() {
              _allOrders.clear();
              _allOrders.addAll(orderData.map((order) => Map<String, dynamic>.from(order)).toList());
              _isLoading = false;
            });
          } else {
            debugPrint('Error response from alternate endpoint: ${response.statusCode} - ${response.body}');
            setState(() {
              _error = 'Failed to load orders. Please try again later.';
              _isLoading = false;
            });
          }
        } catch (altError) {
          debugPrint('Error during alternative request: $altError');
          setState(() {
            _error = 'Network error. Please check your connection and try again.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Unexpected error fetching orders: $e');
      if (mounted) {
        setState(() {
          _error = 'An unexpected error occurred';
          _isLoading = false;
        });
      }
    }
  }

  // Helper method for min calculation
  static int min(int a, int b) {
    return a < b ? a : b;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'All Orders'),
              Tab(text: 'Track Orders'),
            ],
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.orange,
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _fetchOrders(inProgressOnly: _tabController.index == 1),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : (_tabController.index == 1 ? _inProgressOrders : _allOrders).isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('No orders found'),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: (_tabController.index == 1 ? _inProgressOrders : _allOrders).length,
                            itemBuilder: (ctx, i) => _buildOrderCard((_tabController.index == 1 ? _inProgressOrders : _allOrders)[i]),
                          ),
          ),
        ],
      ),
    );
  }

  // Call this after placing an order to show a snackbar for the most recent in-progress order
  void showRecentInProgressOrderSnackbar(BuildContext context) {
    if (_inProgressOrders.isNotEmpty) {
      final order = _inProgressOrders.first;
      debugPrint('Snackbar in-progress order object: ' + order.toString());
      final orderNumber = order['order_number'] ?? order['id'] ?? order['order_id'];
      final vendorName = order['vendor']?['name'] ?? 'Vendor';
      final total = order['total_amount'] ?? order['total'] ?? 0.0;
      final snackBar = SnackBar(
        content: Text('Order #$orderNumber at $vendorName is in progress (₹${total.toStringAsFixed(2)})'),
        action: SnackBarAction(
          label: 'Track',
          onPressed: () {
            if (orderNumber != null && orderNumber.toString().isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderTrackingScreen(orderNumber: orderNumber.toString()),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Error: Could not get Order Number to track order.')),
              );
            }
          },
          textColor: Colors.orange,
        ),
        duration: const Duration(seconds: 8),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderId = order['order_id'] ?? order['order_number'] ?? order['id'] ?? 'Unknown ID';
    final orderStatus = order['status'] ?? 'Processing';
    final orderDate = order['created_at'] ?? order['timestamp'] ?? 'N/A';
    final totalAmount = (order['total_amount'] ?? order['total'] ?? 0.0).toDouble();
    
    // Get total items
    int itemCount = 0;
    if (order.containsKey('items') && order['items'] is List) {
      itemCount = (order['items'] as List).length;
    }
    
    // Determine status color
    Color statusColor;
    switch(orderStatus.toString().toLowerCase()) {
      case 'completed':
      case 'delivered':
        statusColor = Colors.green;
        break;
      case 'cancelled':
      case 'failed':
        statusColor = Colors.red;
        break;
      case 'processing':
      case 'confirmed':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.orange;
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Order #$orderId',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      orderStatus,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Date: $orderDate',
                    style: const TextStyle(color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 2,
                  child: Text(
                    'Total: ₹${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Items: $itemCount',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  debugPrint('(OrdersScreen) View Details Tapped. Order ID: $orderId');
                  if (orderId != 'Unknown ID') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderDetailsScreen(orderId: orderId.toString()),
                      ),
                    );
                  } else {
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('Error: Could not get Order ID to view details.')),
                     );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('View Details'),
              ),
            )
          ],
        ),
      ),
    );
  }
} 