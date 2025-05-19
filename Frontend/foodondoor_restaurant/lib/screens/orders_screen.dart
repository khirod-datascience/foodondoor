import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../config.dart';
import 'package:foodondoor_restaurant/utils/globals.dart'; // Import the global file

class OrdersScreen extends StatefulWidget {
  @override
  _OrdersScreenState createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (_) => _fetchOrders());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    if (Globals.vendorId == null) {
      setState(() {
        _error = "Please login again";
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/auth/orders/${Globals.vendorId}/'),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          setState(() {
            _orders = jsonDecode(response.body);
            _isLoading = false;
            _error = null;
          });
        } else {
          setState(() {
            _error = "Failed to fetch orders";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Network error";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchOrders,
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red),
                        SizedBox(height: 16),
                        Text(_error!, style: TextStyle(color: Colors.red)),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchOrders,
                          child: Text("Retry"),
                        ),
                      ],
                    ),
                  )
                : _orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              "No orders available",
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _orders.length,
                        itemBuilder: (context, index) {
                          final order = _orders[index];
                          return Card(
                            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: ListTile(
                              leading: Icon(
                                _getOrderStatusIcon(order['status']),
                                color: _getOrderStatusColor(order['status']),
                              ),
                              title: Text("Order No: ${order['order_no']}"),
                              subtitle: Text("Status: ${order['status']}"),
                              trailing: Text(
                                order['timestamp'] ?? '',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => OrderDetailsScreen(order: order),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  IconData _getOrderStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'completed':
        return Icons.done_all;
      default:
        return Icons.shopping_cart;
    }
  }

  Color _getOrderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class OrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  OrderDetailsScreen({required this.order});

  @override
  _OrderDetailsScreenState createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late Map<String, dynamic> _order;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _order = Map<String, dynamic>.from(widget.order);
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final response = await http.put(
        Uri.parse('${Config.baseUrl}/auth/orders/${Globals.vendorId}/${_order['id']}/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': newStatus}),
      );
      if (response.statusCode == 200) {
        setState(() {
          _order['status'] = newStatus;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order status updated to $newStatus.')),
        );
      } else {
        setState(() { _isLoading = false; _error = 'Failed to update order status.'; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update order status.')),
        );
      }
    } catch (e) {
      setState(() { _isLoading = false; _error = 'Network error.'; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error.')),
      );
    }
  }

  Widget _buildActionButtons() {
    final status = (_order['status'] ?? '').toLowerCase();
    if (status == 'pending') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            icon: Icon(Icons.check),
            label: Text('Accept'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: _isLoading ? null : () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Accept Order'),
                  content: Text('Are you sure you want to accept this order?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Accept')),
                  ],
                ),
              );
              if (confirm == true) _updateOrderStatus('accepted');
            },
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.cancel),
            label: Text('Reject'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: _isLoading ? null : () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Reject Order'),
                  content: Text('Are you sure you want to reject this order?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Reject')),
                  ],
                ),
              );
              if (confirm == true) _updateOrderStatus('rejected');
            },
          ),
        ],
      );
    } else if (status == 'accepted') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            icon: Icon(Icons.kitchen),
            label: Text('Preparing'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: _isLoading ? null : () => _updateOrderStatus('preparing'),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.delivery_dining),
            label: Text('Ready'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: _isLoading ? null : () => _updateOrderStatus('ready'),
          ),
        ],
      );
    } else if (status == 'preparing') {
      return Center(
        child: ElevatedButton.icon(
          icon: Icon(Icons.delivery_dining),
          label: Text('Ready'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: _isLoading ? null : () => _updateOrderStatus('ready'),
        ),
      );
    } else if (status == 'ready') {
      return Center(
        child: ElevatedButton.icon(
          icon: Icon(Icons.done_all),
          label: Text('Completed'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
          onPressed: _isLoading ? null : () => _updateOrderStatus('completed'),
        ),
      );
    }
    return SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Order Details"),
        backgroundColor: Colors.orange,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Order No: ${_order['order_no']}",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Status: ${_order['status']}",
                          style: TextStyle(
                            fontSize: 16,
                            color: _getOrderStatusColor(_order['status']),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Time: ${_order['timestamp'] ?? 'N/A'}",
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  "Items:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: (_order['items'] as List).length,
                  itemBuilder: (context, index) {
                    final item = _order['items'][index];
                    return Card(
                      child: ListTile(
                        title: Text(item['name']),
                        subtitle: Text("Quantity: ${item['quantity']}"),
                        trailing: Text(
                          "₹${item['price']}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Bill Summary",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Subtotal:"),
                            Text("₹${_order['subtotal'] ?? '0.00'}"),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Tax:"),
                            Text("₹${_order['tax'] ?? '0.00'}"),
                          ],
                        ),
                        Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Total:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "₹${_order['total'] ?? '0.00'}",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                if (_error != null) ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(_error!, style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
                _buildActionButtons(),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.2),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Color _getOrderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
