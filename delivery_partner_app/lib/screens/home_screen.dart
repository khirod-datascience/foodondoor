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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Dashboard'),
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Ongoing'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList(OrderListType.pending),
          _buildOrderList(OrderListType.ongoing),
          _buildOrderList(OrderListType.completed),
        ],
      ),
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
