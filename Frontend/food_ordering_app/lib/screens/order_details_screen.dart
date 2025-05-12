import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../config.dart';
import '../utils/auth_storage.dart';
import '../widgets/order_status_banner.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String? orderId;
  
  const OrderDetailsScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _orderDetails;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.orderId != null) {
      _fetchOrderDetails();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = "No order ID provided";
      });
    }
  }

  Future<void> _fetchOrderDetails() async {
    try {
      final token = await AuthStorage.getToken();
      final dio = Dio();
      
      if (token != null) {
        dio.options.headers['Authorization'] = 'Bearer $token';
      }
      
      final response = await dio.get(
        '${AppConfig.baseUrl}/orders/${widget.orderId}/',
      );
      
      if (response.statusCode == 200) {
        setState(() {
          _orderDetails = response.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Failed to load order details";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _buildOrderDetails(),
    );
  }

  Widget _buildOrderDetails() {
    if (_orderDetails == null) {
      return const Center(child: Text('No order details available'));
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order status banner
          const OrderStatusBanner(),
          
          const SizedBox(height: 20),
          
          // Order ID and date
          Text(
            'Order #${_orderDetails!['order_id'] ?? widget.orderId}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Placed on: ${_orderDetails!['created_at'] ?? 'Unknown date'}',
            style: const TextStyle(color: Colors.grey),
          ),
          
          const Divider(height: 30),
          
          // Restaurant info
          if (_orderDetails!.containsKey('restaurant')) ...[
            Text(
              'Restaurant: ${_orderDetails!['restaurant']['name'] ?? 'Unknown restaurant'}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
          ],
          
          // Items
          const Text(
            'Items',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          
          if (_orderDetails!.containsKey('items') && _orderDetails!['items'] is List) ...[
            ..._buildOrderItems(_orderDetails!['items'] as List),
          ] else ...[
            const Text('No items found'),
          ],
          
          const Divider(height: 30),
          
          // Price details
          _buildPriceDetails(),
          
          const SizedBox(height: 20),
          
          // Delivery address
          const Text(
            'Delivery Address',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(_orderDetails!['delivery_address'] ?? 'Address not available'),
          
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  List<Widget> _buildOrderItems(List items) {
    return items.map<Widget>((item) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item['quantity']}x',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'] ?? 'Unknown item',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  if (item.containsKey('variations') && item['variations'] != null)
                    Text(
                      item['variations'] ?? '',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Container(
              constraints: BoxConstraints(maxWidth: 80),
              child: Text(
                '₹${item['price'] ?? '0.00'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildPriceDetails() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 3,
              child: const Text('Subtotal', overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 1,
              child: Text(
                '₹${_orderDetails!['subtotal'] ?? '0.00'}',
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        if (_orderDetails!.containsKey('delivery_fee')) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 3,
                child: const Text('Delivery Fee', overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  '₹${_orderDetails!['delivery_fee'] ?? '0.00'}',
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
        ],
        if (_orderDetails!.containsKey('tax')) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 3,
                child: const Text('Tax', overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  '₹${_orderDetails!['tax'] ?? '0.00'}',
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
        ],
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 3,
              child: const Text(
                'Total',
                style: TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                '₹${_orderDetails!['total'] ?? '0.00'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
} 