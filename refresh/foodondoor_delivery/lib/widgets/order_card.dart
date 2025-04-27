// ignore_for_file: unrelated_type_equality_checks

import 'package:flutter/material.dart';
import 'package:foodondoor_delivery/mainScreens/order_details_screen.dart';
import 'package:foodondoor_delivery/models/order_model.dart';
import 'package:foodondoor_delivery/models/item_model.dart';
import 'status_banner.dart'; // Fix path - remove ../

class OrderCard extends StatelessWidget {
  final OrderModel orderModel;

  const OrderCard({
    super.key,
    required this.orderModel,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (c) => OrderDetailsScreen(orderModel: orderModel)));
      },
      child: Container(
        decoration: BoxDecoration(
            gradient: LinearGradient(
          colors: [
            Colors.black12.withOpacity(0.2),
            Colors.black12.withOpacity(0.1),
          ],
          begin: FractionalOffset(0.0, 0.0),
          end: FractionalOffset(1.0, 0.0),
          stops: [0.0, 1.0],
          tileMode: TileMode.clamp,
        )),
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.all(10),
        height: orderModel.items.length * 125,
        child: ListView(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Order ID: ${orderModel.orderId}",
                  style: const TextStyle(color: Colors.black, fontSize: 16.0),
                ),
                Text(
                  orderModel.formattedOrderTime,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),

            ListView.builder(
              itemCount: orderModel.items.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                ItemModel item = orderModel.items[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "x ${item.quantity}",
                              style: const TextStyle(color: Colors.black54, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "€ ${(item.price * item.quantity).toStringAsFixed(2)}",
                        style: const TextStyle(fontSize: 16.0, color: Colors.blue),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(thickness: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total: € ${orderModel.totalAmount.toStringAsFixed(2)}",
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                StatusBanner(
                  status: orderModel.status == "ended", // Pass bool based on status
                  orderStatus: orderModel.status // Pass status string
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
