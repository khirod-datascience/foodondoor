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
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('No tracking info'),
                      if (provider.lastTrackingError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text('Error: ${provider.lastTrackingError}', style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Text('Status: ${provider.trackingData!['status']}'),
                    if (provider.trackingData!['delivery_lat'] != null && provider.trackingData!['delivery_lng'] != null)
                      Column(
                        children: [
                          Text('Delivery Agent Location:'),
                          Text('Lat: ${provider.trackingData!['delivery_lat']}, Lng: ${provider.trackingData!['delivery_lng']}'),
                          // TODO: Replace with Google Maps widget or similar
                          Container(
                            margin: EdgeInsets.symmetric(vertical: 8),
                            height: 180,
                            color: Colors.grey[300],
                            child: Center(child: Text('Map Preview Placeholder')),
                          ),
                        ],
                      )
                    else
                      Text('Delivery agent location not available yet.'),
                    ElevatedButton(
                      onPressed: () => provider.fetchTracking(orderNumber),
                      child: Text('Refresh'),
                    ),
                  ],
                ),
    );
  }
}
