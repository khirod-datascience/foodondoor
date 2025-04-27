// ignore_for_file: prefer_interpolation_to_compose_strings

import 'package:flutter/material.dart';
import '../models/address.dart';
import '../models/order_model.dart';
import '../widgets/progress_bar.dart';
import '../global/global.dart';
import '../widgets/shipment_address_design.dart';
import '../widgets/status_banner.dart';
import 'package:intl/intl.dart';

class OrderDetailsScreen extends StatefulWidget {
  final OrderModel orderModel;

  const OrderDetailsScreen({super.key, required this.orderModel});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final order = widget.orderModel;

    return Scaffold(
      appBar: AppBar(
        title: Text("Order #${order.orderId.substring(0, 6)}..."),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.cyan,
                Colors.amber,
              ],
              begin: FractionalOffset(0.0, 0.0),
              end: FractionalOffset(1.0, 0.0),
              stops: [0.0, 1.0],
              tileMode: TileMode.clamp,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              order.status != "normal" ? 
              StatusBanner(
                 status: order.status == "ended", 
                 orderStatus: order.status 
              )
              : Container(),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Total: € ${order.totalAmount.toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Text(
                  "Order ID: ${order.orderId}",
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Text(
                  "Ordered at: ${order.formattedOrderTime}",
                  style: const TextStyle(fontSize: 15, color: Colors.grey),
                ),
              ),
              const Divider(thickness: 3, height: 30),
              Center(
                child: order.status == "completed" || order.status == "ended"
                  ? Image.asset('assets/images/delivered.png', height: 150)
                  : order.status == "pending"
                     ? Image.asset('assets/images/state.png', height: 150)
                     : Image.asset('assets/images/confirm_pick.png', height: 150),
              ),
              const Divider(thickness: 3, height: 30),
              ShipmentAddressDesign(
                orderModel: order,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
