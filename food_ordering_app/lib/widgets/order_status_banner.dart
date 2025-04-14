import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import '../config.dart';
import '../utils/auth_storage.dart';

class OrderStatusBanner extends StatefulWidget {
  const OrderStatusBanner({Key? key}) : super(key: key);

  @override
  _OrderStatusBannerState createState() => _OrderStatusBannerState();
}

class _OrderStatusBannerState extends State<OrderStatusBanner> {
  Map<String, dynamic>? _latestOrder;
  bool _isLoading = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchLatestOrder();
    // Refresh order status every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchLatestOrder());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLatestOrder() async {
    if (_isLoading) return;

    try {
      setState(() => _isLoading = true);
      final String? token = await AuthStorage.getToken();
      if (token == null) return;

      final dio = Dio();
      final response = await dio.get(
        '${AppConfig.baseUrl}/orders/latest/',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        setState(() => _latestOrder = response.data);
      }
    } catch (e) {
      debugPrint('Error fetching latest order: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
        return Colors.purple;
      case 'out_for_delivery':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_latestOrder == null) return const SizedBox.shrink();

    final status = _latestOrder!['order_status'] as String;
    final orderId = _latestOrder!['order_id'] as String;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: _getStatusColor(status).withOpacity(0.1),
      child: Row(
        children: [
          Icon(
            Icons.local_shipping,
            color: _getStatusColor(status),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Order #$orderId is ${status.toUpperCase()}',
              style: TextStyle(
                color: _getStatusColor(status),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, '/orders');
            },
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }
} 