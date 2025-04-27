import 'package:flutter/material.dart';

import '../global/global.dart';
import '../widgets/progress_bar.dart';
import '../widgets/simple_Appbar.dart';
import '../api/api_service.dart';
import '../widgets/order_card.dart';
// import 'order_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Map<String, dynamic>>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _loadHistoryOrders();
  }

  Future<List<Map<String, dynamic>>> _loadHistoryOrders() async {
    final deliveredResponse = await _apiService.get('/vendor_auth/vendor/orders/?status=Delivered');
    final cancelledResponse = await _apiService.get('/vendor_auth/vendor/orders/?status=Cancelled');

    List<Map<String, dynamic>> combinedOrders = [];

    if (deliveredResponse.containsKey('data') && deliveredResponse['data'] is List) {
      combinedOrders.addAll(List<Map<String, dynamic>>.from(deliveredResponse['data']));
    }
     if (cancelledResponse.containsKey('data') && cancelledResponse['data'] is List) {
      combinedOrders.addAll(List<Map<String, dynamic>>.from(cancelledResponse['data']));
    }

    if (deliveredResponse.containsKey('error')) {
      debugPrint("Error loading delivered orders: ${deliveredResponse['error']}");
    }
     if (cancelledResponse.containsKey('error')) {
      debugPrint("Error loading cancelled orders: ${cancelledResponse['error']}");
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
    return SafeArea(
      child: Scaffold(
        appBar: SimpleAppBar(
          title: "History",
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _ordersFuture,
          builder: (context, snapshot) {
             if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: circularProgress());
             }
             if (snapshot.hasError) {
                return Center(child: Text("Error loading history: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
             }
             if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("No order history found."));
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
                      //   return OrderDetailScreen(orderData: orderData);
                      // }));
                      debugPrint("History Order card tapped: ${orderData['order_number']}");
                   }
                 );
               },
             );
          },
        ),
      ),
    );
  }
}
