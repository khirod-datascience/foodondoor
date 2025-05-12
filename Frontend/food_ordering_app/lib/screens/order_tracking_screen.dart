import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../widgets/app_scaffold.dart';

class OrderTrackingScreen extends StatelessWidget {
  final String orderNumber;
  const OrderTrackingScreen({Key? key, required this.orderNumber}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    return AppScaffold(
      appBar: AppBar(title: Text('Order Tracking')),
      body: provider.loadingTracking
          ? Center(child: CircularProgressIndicator())
          : provider.trackingData == null
              ? Center(child: Text('No tracking info'))
              : Column(
                  children: [
                    Text('Status: ${provider.trackingData!['status']}'),
                    Text('Estimated Delivery: ${provider.trackingData!['estimated_delivery']}'),
                    Text('Current Location: ${provider.trackingData!['tracking_details']['current_location']}'),
                    Text('Delivery Partner: ${provider.trackingData!['tracking_details']['delivery_partner']}'),
                    ElevatedButton(
                      onPressed: () => provider.fetchTracking(orderNumber),
                      child: Text('Refresh'),
                    ),
                  ],
                ),
    );
  }
}
