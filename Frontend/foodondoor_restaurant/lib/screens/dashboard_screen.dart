import 'package:flutter/material.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'food_form_screen.dart';
import 'food_listing_screen.dart';
import 'orders_screen.dart';
import 'package:foodondoor_restaurant/utils/globals.dart';
import 'login_signup_screen.dart';
import 'analytics_screen.dart';
import 'promotions_screen.dart';
import 'category_screen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    print("DashboardScreen initState - vendorId: ${Globals.vendorId}");
    if (Globals.vendorId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => LoginSignupScreen()),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    int _selectedIndex = 0;
    final List<Widget> _screens = [
      FoodListingScreen(),
      OrdersScreen(),
      // AnalyticsScreen(), // commented out for v1
      // PromotionsScreen(), // commented out for v1
      // CategoryScreen(), // commented out for v1
      NotificationsScreen(),
      ProfileScreen(),
    ];

    return StatefulBuilder(
      builder: (context, setState) {
        return Scaffold(
          appBar: AppBar(
            title: Text("Dashboard"),
            backgroundColor: Colors.orange,
            actions: [
              IconButton(
                icon: Icon(Icons.add),
                tooltip: 'Add Food',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => FoodFormScreen()),
                  );
                },
              ),
            ],
          ),
          body: _screens[_selectedIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.orange,
            unselectedItemColor: Colors.grey,
            backgroundColor: Colors.white,
            type: BottomNavigationBarType.fixed,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.restaurant_menu),
                label: 'Menu',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long),
                label: 'Orders',
              ),
              // BottomNavigationBarItem(
              //   icon: Icon(Icons.analytics),
              //   label: 'Analytics',
              // ),
              // BottomNavigationBarItem(
              //   icon: Icon(Icons.local_offer),
              //   label: 'Promos',
              // ),
              // BottomNavigationBarItem(
              //   icon: Icon(Icons.category),
              //   label: 'Categories',
              // ),
              BottomNavigationBarItem(
                icon: Icon(Icons.notifications),
                label: 'Alerts',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}
