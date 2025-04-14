import 'package:flutter/material.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'food_form_screen.dart';
import 'food_listing_screen.dart';
import 'orders_screen.dart';

class BlankScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Welcome"),
          actions: [
            IconButton(
              icon: Icon(Icons.notifications),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NotificationsScreen()),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.person),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileScreen()),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FoodFormScreen()),
                );
              },
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: "Food Listing"),
              Tab(text: "Orders"),
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