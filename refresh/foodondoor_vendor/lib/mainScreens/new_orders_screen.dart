import 'package:flutter/material.dart';
import '../global/global.dart';
import '../widgets/order_card.dart';
import '../widgets/progress_bar.dart';
import '../widgets/simple_Appbar.dart';
import '../api/api_service.dart';
// import 'order_detail_screen.dart';

class NewOrdersScreen extends StatefulWidget {
  const NewOrdersScreen({super.key});

  @override
  State<NewOrdersScreen> createState() => _NewOrdersScreenState();
}

class _NewOrdersScreenState extends State<NewOrdersScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Map<String, dynamic>>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _loadNewOrders();
  }

  Future<List<Map<String, dynamic>>> _loadNewOrders() async {
    final pendingResponse = await _apiService.get('/vendor_auth/vendor/orders/?status=Pending');
    final acceptedResponse = await _apiService.get('/vendor_auth/vendor/orders/?status=Accepted');

    List<Map<String, dynamic>> combinedOrders = [];

    if (pendingResponse.containsKey('data') && pendingResponse['data'] is List) {
      combinedOrders.addAll(List<Map<String, dynamic>>.from(pendingResponse['data']));
    }
    if (acceptedResponse.containsKey('data') && acceptedResponse['data'] is List) {
       combinedOrders.addAll(List<Map<String, dynamic>>.from(acceptedResponse['data']));
    }

    if (pendingResponse.containsKey('error')) {
      debugPrint("Error loading pending orders: ${pendingResponse['error']}");
    }
     if (acceptedResponse.containsKey('error')) {
      debugPrint("Error loading accepted orders: ${acceptedResponse['error']}");
    }

    combinedOrders.sort((a, b) {
       final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(0);
       final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(0);
       return dateB.compareTo(dateA);
    });

    return combinedOrders;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleAppBar(
        title: "New Orders",
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: circularProgress());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error loading orders: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No new orders found."));
          }

          final orders = snapshot.data!;

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final orderData = orders[index];
              return OrderCard(
                orderData: orderData,
                onTap: () {
                   // Comment out navigation to non-existent screen
                   // Navigator.push(context, MaterialPageRoute(builder: (c) {
                   //    return OrderDetailScreen(orderData: orderData);
                   // }));
                   debugPrint("Order card tapped: ${orderData['order_number']}");
                }
              );
            },
          );
        },
      ),
    );
  }
}
