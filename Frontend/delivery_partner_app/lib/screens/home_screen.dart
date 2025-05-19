import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // For date formatting

import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../models/order.dart';
import 'order_detail_screen.dart'; // Import for navigation
import '../widgets/order_list_item.dart'; // Import list item widget
import '../widgets/error_display.dart'; // Import error display widget
import 'profile_screen.dart'; // Import ProfileScreen

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // 3 tabs: Pending, Ongoing, Completed
    // Initial fetch is triggered by AuthWrapper in main.dart
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshOrders(OrderListType type) async {
    // Use the provider's refresh method
    await Provider.of<OrderProvider>(context, listen: false).fetchOrders(type, forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    int _selectedIndex = 0;
    final List<Widget> _screens = [
      _buildOrderList(OrderListType.pending),
      _buildOrderList(OrderListType.ongoing),
      _buildOrderList(OrderListType.completed),
      // Add EarningsScreen, NotificationsScreen, ProfileScreen as needed
    ];

    return StatefulBuilder(
      builder: (context, setState) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Delivery Dashboard'),
            backgroundColor: Colors.orange,
            actions: [
              IconButton(
                icon: const Icon(Icons.person),
                tooltip: 'Profile',
                onPressed: () {
                  Navigator.push(
                     context,
                     MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: () => _showLogoutConfirmation(context, authProvider),
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
                icon: Icon(Icons.assignment_outlined),
                label: 'Pending',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.directions_bike_outlined),
                label: 'Ongoing',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.check_circle_outline),
                label: 'Completed',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_outlined),
                label: 'Earnings',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.notifications_outlined),
                label: 'Alerts',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
    );
  }

  Widget _buildOrderList(OrderListType type) {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, child) {
        final orders = orderProvider.ordersFor(type);
        final isLoading = orderProvider.isLoading(type);
        final errorMessage = orderProvider.errorMessage(type);

        // Handle loading state
        if (isLoading && orders.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        // Handle error state
        if (errorMessage != null && orders.isEmpty) {
          return Center(
            child: ErrorDisplay(
              message: errorMessage,
              onRetry: () => _refreshOrders(type),
            ),
          );
        }

        // Handle empty list state
        if (orders.isEmpty) {
          return Center(
            child: Text(
              'No ${type.toString().split('.').last} orders.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        }

        // Display the list with RefreshIndicator
        return RefreshIndicator(
          onRefresh: () => _refreshOrders(type),
          child: ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return OrderListItem( // Use a custom widget for the list item
                 order: order,
                 onTap: () {
                    Navigator.push(
                       context,
                       MaterialPageRoute(
                          builder: (context) => OrderDetailScreen(orderId: order.id),
                       ),
                     );
                  },
              );
            },
          ),
        );
      },
    );
  }

  void _showLogoutConfirmation(BuildContext context, AuthProvider authProvider) {
     showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Logout',
                style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.of(ctx).pop(); // Close dialog
              authProvider.logout(); // Perform logout
            },
          ),
        ],
      ),
    );
  }
}
