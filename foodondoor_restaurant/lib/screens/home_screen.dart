import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'food_listing_screen.dart';
import 'orders_screen.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Dashboard'),
          backgroundColor: Colors.orange,
          actions: [
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: () {
                context.read<AuthService>().logout();
              },
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Food Listing'),
              Tab(text: 'Orders'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            FoodListingScreen(),
            OrdersScreen(),
          ],
        ),
      ),
    );
  }
} 