import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/order.dart';
import '../providers/order_provider.dart';
import '../services/order_service.dart'; // Direct service call for details
import '../widgets/error_display.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<Map<String, dynamic>> _orderDetailsFuture;
  final OrderService _orderService = OrderService();

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
  }

  void _fetchOrderDetails() {
    _orderDetailsFuture = _orderService.fetchOrderDetails(widget.orderId);
  }

  Future<void> _launchMapsUrl(double? lat, double? lng, String address) async {
    if (lat != null && lng != null) {
      final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
         _showErrorSnackbar('Could not launch map for coordinates');
      }
    } else {
       // Fallback to address search if lat/lng missing
       final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
       if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
          _showErrorSnackbar('Could not launch map for address');
       }
    }
  }

 void _showErrorSnackbar(String message) {
     if (!mounted) return;
     ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context); // For actions

    return Scaffold(
      appBar: AppBar(title: Text('Order #${widget.orderId.substring(0, 6)}...')), // Show partial ID
      body: FutureBuilder<Map<String, dynamic>>(
        future: _orderDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!['success']) {
            return Center(
              child: ErrorDisplay(
                message: snapshot.data?['message'] ?? snapshot.error?.toString() ?? 'Failed to load order details.',
                onRetry: () {
                  setState(() {
                    _fetchOrderDetails();
                  });
                },
              ),
            );
          }

          final order = snapshot.data!['order'] as Order;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle(context, 'Order Summary'),
                _buildDetailRow(context, 'Order Number:', order.orderNumber),
                _buildDetailRow(context, 'Status:', order.status.toString().split('.').last),
                _buildDetailRow(context, 'Placed At:', DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt)),
                _buildDetailRow(context, 'Total Amount:', '₹${order.orderTotal.toStringAsFixed(2)}'),
                _buildDetailRow(context, 'Delivery Fee:', '₹${order.deliveryFee.toStringAsFixed(2)}'),

                const Divider(height: 30),

                _buildSectionTitle(context, 'Restaurant Details'),
                _buildDetailRow(context, 'Name:', order.restaurantName),
                _buildAddressCard(context, 'Pickup Address:', order.restaurantAddress),

                const Divider(height: 30),

                _buildSectionTitle(context, 'Customer Details'),
                _buildDetailRow(context, 'Name:', order.customerName),
                _buildDetailRow(context, 'Phone:', order.customerPhoneNumber),
                _buildAddressCard(context, 'Delivery Address:', order.deliveryAddress),

                const Divider(height: 30),

                _buildSectionTitle(context, 'Order Items'),
                ...order.items.map((item) => ListTile(
                      title: Text(item.name),
                      trailing: Text('${item.quantity} x ₹${item.price.toStringAsFixed(2)}'),
                    )),

                const SizedBox(height: 30),

                // --- Action Buttons ---
                _buildActionButtons(context, order, orderProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
     return Padding(
       padding: const EdgeInsets.only(bottom: 8.0),
       child: Text(title, style: Theme.of(context).textTheme.titleLarge),
     );
  }

   Widget _buildDetailRow(BuildContext context, String label, String value) {
     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 4.0),
       child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceBetween,
         children: [
           Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
           Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
         ],
       ),
     );
   }

   Widget _buildAddressCard(BuildContext context, String title, Address address) {
      return Card(
         margin: const EdgeInsets.symmetric(vertical: 8.0),
         child: ListTile(
            title: Text(title),
            subtitle: Text(address.toString()),
            trailing: IconButton(
               icon: const Icon(Icons.directions, color: Colors.blue),
               tooltip: 'Get Directions',
               onPressed: () => _launchMapsUrl(address.latitude, address.longitude, address.toString()),
            ),
         ),
      );
   }

  Widget _buildActionButtons(BuildContext context, Order order, OrderProvider orderProvider) {
    bool isLoading = orderProvider.isUpdatingOrder;
    String? error = orderProvider.updateErrorMessage;

    List<Widget> buttons = [];

    // Pending Order Actions
    if (order.status == OrderStatus.pending) {
      buttons.add(ElevatedButton.icon(
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Accept Order'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        onPressed: isLoading ? null : () async {
           final success = await orderProvider.acceptOrder(order.id);
           if (success && mounted) Navigator.pop(context); // Go back if successful
        },
      ));
       buttons.add(const SizedBox(height: 10));
       buttons.add(ElevatedButton.icon(
         icon: const Icon(Icons.cancel_outlined),
         label: const Text('Reject Order'),
         style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
         onPressed: isLoading ? null : () async {
            // TODO: Optionally add a reason for rejection
            final success = await orderProvider.rejectOrder(order.id);
            if (success && mounted) Navigator.pop(context);
         },
       ));
    }

    // Ongoing Order Actions
    if (order.status == OrderStatus.accepted || order.status == OrderStatus.readyForPickup) {
       buttons.add(ElevatedButton.icon(
         icon: const Icon(Icons.shopping_bag_outlined),
         label: const Text('Mark as Picked Up'),
         style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
         onPressed: isLoading ? null : () async {
            final success = await orderProvider.markAsPickedUp(order.id);
            if (success && mounted) setState(() { _fetchOrderDetails(); }); // Refresh details on success
         },
       ));
    }

     if (order.status == OrderStatus.pickedUp || order.status == OrderStatus.outForDelivery) {
       buttons.add(ElevatedButton.icon(
         icon: const Icon(Icons.delivery_dining_outlined),
         label: const Text('Mark as Delivered'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
         onPressed: isLoading ? null : () async {
            final success = await orderProvider.markAsDelivered(order.id);
            if (success && mounted) Navigator.pop(context); // Go back home on final step
         },
       ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
         if (isLoading) const Center(child: Padding(
           padding: EdgeInsets.all(8.0),
           child: CircularProgressIndicator(),
         )),
         if (error != null) Padding(
           padding: const EdgeInsets.only(bottom: 10.0),
           child: Text(error, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
         ),
        ...buttons,
      ],
    );
  }

}

