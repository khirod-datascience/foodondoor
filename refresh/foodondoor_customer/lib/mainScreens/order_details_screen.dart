// ignore_for_file: prefer_interpolation_to_compose_strings

import 'package:flutter/material.dart';
import 'package:foodondoor_customer/widgets/progress_bar.dart';
import 'package:intl/intl.dart';
import '../models/address.dart';

import '../widgets/shipment_address_design.dart';
import '../widgets/status_banner.dart';

import '../global/global.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String? orderID;

  const OrderDetailsScreen({this.orderID});

  @override
  _OrderDetailsScreenState createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  String orderStatus = "";
  String orderByUser = "";
  String sellerId = "";

  getOrderInfo() {
    print("getOrderInfo needs API integration.");
    // Set default values for now
    setState(() {
       orderStatus = "unknown";
       orderByUser = "unknown";
       sellerId = "unknown";
    });
  }

  @override
  void initState() {
    super.initState();

    getOrderInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Order Details Placeholder", // Placeholder
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // StatusBanner(
            //       status: dataSnapshot.data()!["isSuccess"],
            //       orderStatus: orderStatus,
            //     )
             // Placeholder for StatusBanner or simplified version
             if (orderStatus.isNotEmpty) StatusBanner(status: true, orderStatus: orderStatus), // Keep StatusBanner if useful

            // FutureBuilder<DocumentSnapshot>(
            //   future: FirebaseFirestore.instance
            //       .collection("orders")
            //       .doc(widget.orderID)
            //       .get(),
            //   builder: (c, snapshot)
            //   {
            //     Map? dataMap;
            //     if(snapshot.hasData)
            //     {
            //       dataMap = snapshot.data!.data()! as Map<String, dynamic>;
            //       orderStatus = dataMap["status"].toString();
            //     }
            //     return snapshot.hasData
            //         ? Container(
            //             child: Column(
            //               children: [
            //                 StatusBanner(
            //                   status: dataMap!["isSuccess"],
            //                   orderStatus: orderStatus,
            //                 ),
            //                 const SizedBox(
            //                   height: 10.0,
            //                 ),
            //                 Padding(
            //                   padding: const EdgeInsets.all(8.0),
            //                   child: Align(
            //                     alignment: Alignment.centerLeft,
            //                     child: Text(
            //                       "€ " + dataMap["totalAmount"].toString(),
            //                       style: const TextStyle(
            //                         fontSize: 24,
            //                         fontWeight: FontWeight.bold,
            //                       ),
            //                     ),
            //                   ),
            //                 ),
            //                 Padding(
            //                   padding: const EdgeInsets.all(8.0),
            //                   child: Text(
            //                     "Order Id = " + widget.orderID!,
            //                     style: const TextStyle(fontSize: 16),
            //                   ),
            //                 ),
            //                 Padding(
            //                   padding: const EdgeInsets.all(8.0),
            //                   child: Text(
            //                     "Order at: " + DateFormat("dd MMMM, yyyy - hh:mm aa")
            //                           .format(DateTime.fromMillisecondsSinceEpoch(int.parse(dataMap["orderTime"]))),
            //                     style: const TextStyle(fontSize: 16, color: Colors.grey),
            //                   ),
            //                 ),
            //                 const Divider(thickness: 4,),
            //                 orderStatus == "ended"
            //                     ? Image.asset("images/delivered.jpg")
            //                     : Image.asset("images/state.jpg"),
            //                 const Divider(thickness: 4,),
            //                 FutureBuilder<DocumentSnapshot>(
            //                   future: FirebaseFirestore.instance
            //                       .collection("users")
            //                       .doc(orderByUser)
            //                       .collection("userAddress")
            //                       .doc(dataMap["addressID"])
            //                       .get(),
            //                   builder: (c, snap)
            //                   {
            //                     return snap.hasData
            //                         ? ShipmentAddressDesign(
            //                             model: Address.fromJson(
            //                               snap.data!.data()! as Map<String, dynamic>
            //                             ),
            //                             orderStatus: orderStatus,
            //                             orderId: widget.orderID,
            //                             sellerId: sellerId,
            //                             orderByUser: orderByUser,
            //                           )
            //                         : Center(child: circularProgress(),);
            //                   },
            //                 ),
            //               ],
            //             ),
            //           )
            //         : Center(child: circularProgress(),);
            //   },
            // ),
          ],
        ),
      ),
    );
  }
}
