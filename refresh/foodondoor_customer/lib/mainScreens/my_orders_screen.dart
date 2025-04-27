// import 'package:cloud_firestore/cloud_firestore.dart'; // Removed
import 'package:flutter/material.dart';
import '../assistant_methods/assistant_methods.dart';
import '../global/global.dart';
import '../widgets/order_card.dart';
import '../widgets/progress_bar.dart';
import '../widgets/simple_Appbar.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: SimpleAppBar(
          title: "My Orders",
        ),
        body: Center(child: Text("Orders will be loaded from API later.")),
      ),
    );
  }
}
