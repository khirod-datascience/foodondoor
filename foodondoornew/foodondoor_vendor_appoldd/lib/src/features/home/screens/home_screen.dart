import 'package:flutter/material.dart';
import 'package:foodondoor_vendor_app/src/features/auth/providers/auth_provider.dart'; 
import 'package:provider/provider.dart';
import 'package:foodondoor_vendor_app/src/features/menu/screens/menu_list_screen.dart'; 
import 'package:foodondoor_vendor_app/src/features/profile/screens/profile_tab_screen.dart'; 

// Define a simple Home Dashboard screen (replace with actual dashboard later)
class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Vendor Dashboard - Coming Soon!', style: TextStyle(fontSize: 18)),
    );
  }
}

// Convert HomeScreen to StatefulWidget
class HomeScreen extends StatefulWidget {
  static const routeName = '/home';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // State for selected tab index

  // List of screens to navigate between
  static const List<Widget> _widgetOptions = <Widget>[
    HomeDashboardScreen(), // Index 0: Home/Dashboard
    Center(child: Text('Orders Screen Placeholder')), // Index 1: Orders (Temporary Placeholder)
    MenuListScreen(), // Index 2: Menu
    ProfileTabScreen(), // Index 3: Profile
  ];

  // List of AppBar titles corresponding to screens
  static const List<String> _appBarTitles = <String>[
    'Dashboard',
    'Orders',
    'Menu Management',
    'Profile & Settings',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false); 

    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitles[_selectedIndex]), // Dynamic title
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext ctx) {
                  return AlertDialog(
                    title: const Text('Confirm Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () {
                          Navigator.of(ctx).pop(); 
                        },
                      ),
                      TextButton(
                        child: const Text('Logout'),
                        onPressed: () {
                          Navigator.of(ctx).pop(); 
                          authProvider.logout(); 
                          // Navigation back to login is handled by the main listener
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Center(
        // Display the widget from _widgetOptions based on the selected index
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Menu',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor, // Use theme color
        unselectedItemColor: Colors.grey, // Color for unselected items
        showUnselectedLabels: true, // Show labels for unselected items
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Ensures all items are visible
      ),
    );
  }
}
