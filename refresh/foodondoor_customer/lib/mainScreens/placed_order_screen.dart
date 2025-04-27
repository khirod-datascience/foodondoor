// import 'package:cloud_firestore/cloud_firestore.dart'; // Removed
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:foodondoor_customer/assistant_methods/assistant_methods.dart';
import 'package:foodondoor_customer/global/global.dart';
import 'package:foodondoor_customer/mainScreens/home_screen.dart';

class PlacedOrderScreen extends StatefulWidget {
  final String? addressID;
  final double? totalAmount;
  final String? sellerUID;
  final String? orderID; // Add orderID if needed

  const PlacedOrderScreen({
    super.key,
    this.addressID,
    this.totalAmount,
    this.sellerUID,
    this.orderID, // Add orderID if needed
  });

  @override
  State<PlacedOrderScreen> createState() => _PlacedOrderScreenState();
}

class _PlacedOrderScreenState extends State<PlacedOrderScreen> {
  String orderId = DateTime.now().millisecondsSinceEpoch.toString();

  addOrderDetails() {
    // Placeholder: Logic to write order details likely using API
    // writeOrderDetailsForUser({
    //   // ... user order data
    // });
    // writeOrderDetailsForSeller({
    //  // ... seller order data
    // });

    // Call the API based clear cart method
    clearCartAPI(context);

    setState(() {
      orderId = ""; // Reset local orderId variable if needed
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const HomeScreen()));
    });

    Fluttertoast.showToast(
        msg: "Congratulations, Order has been placed successfully.");
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red, Colors.redAccent],
            begin: FractionalOffset(0.0, 0.0),
            end: FractionalOffset(1.0, 0.0),
            stops: [0.0, 1.0],
            tileMode: TileMode.clamp,
          ),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Image.asset("images/delivery.jpg"),
          const SizedBox(
            height: 12,
          ),
          ElevatedButton(
            onPressed: () {
              // This button likely shouldn't call clearCartAPI directly.
              // It should navigate back or to orders screen.
              // The cart clearing happens after successful order placement (in addOrderDetails).
              Navigator.push(context, MaterialPageRoute(builder: (context)=> const HomeScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text("Go Back"),
          )
        ]),
      ),
    );
  }
}
