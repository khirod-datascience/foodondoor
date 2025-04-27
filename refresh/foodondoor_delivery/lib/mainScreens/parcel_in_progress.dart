import 'package:flutter/material.dart';
import 'package:foodondoor_delivery/assistant_methods/assistant_methods.dart';
import 'package:foodondoor_delivery/global/global.dart';
import 'package:foodondoor_delivery/widgets/order_card.dart';
import 'package:foodondoor_delivery/widgets/progress_bar.dart';
import 'package:foodondoor_delivery/widgets/simple_Appbar.dart';
import 'package:foodondoor_delivery/models/order_model.dart';
import 'package:foodondoor_delivery/services/api_service.dart';

class ParcelInProgressScreen extends StatefulWidget {
  const ParcelInProgressScreen({super.key});

  @override
  State<ParcelInProgressScreen> createState() => _ParcelInProgressScreenState();
}

class _ParcelInProgressScreenState extends State<ParcelInProgressScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<OrderModel>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _apiService.getOrders('picking');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: SimpleAppBar(
          title: "Parcels In Progress",
        ),
        body: FutureBuilder<List<OrderModel>>(
          future: _ordersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: circularProgress());
            } else if (snapshot.hasError) {
              print("Error fetching 'picking' orders: ${snapshot.error}");
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Error loading orders in progress: ${snapshot.error}\nPlease check your connection or try again later.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red[700]),
                  ),
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Text(
                  "No orders currently in progress.",
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              );
            } else {
              List<OrderModel> orders = snapshot.data!;
              return ListView.builder(
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  return OrderCard(orderModel: orders[index]);
                },
              );
            }
          },
        ),
      ),
    );
  }
}
