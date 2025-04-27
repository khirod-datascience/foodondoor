import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      
      final response = await apiService.getNotifications();
      
      if (response.statusCode == 200 && response.data is List) {
        final List<dynamic> data = response.data;
        setState(() {
          _notifications = data.map((item) => Map<String, dynamic>.from(item)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Failed to load notifications";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _buildNotificationsList(),
    );
  }

  Widget _buildNotificationsList() {
    if (_notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchNotifications,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _buildNotificationItem(notification);
        },
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    // Format the date
    String formattedDate = notification['created_at'] ?? 'Unknown date';
    try {
      final DateTime dateTime = DateTime.parse(notification['created_at']);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inDays > 0) {
        formattedDate = '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
      } else if (difference.inHours > 0) {
        formattedDate = '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
      } else if (difference.inMinutes > 0) {
        formattedDate = '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
      } else {
        formattedDate = 'Just now';
      }
    } catch (e) {
      // If date parsing fails, use the original string
    }

    // Get the correct icon based on notification type
    IconData iconData = Icons.notifications;
    if (notification.containsKey('type')) {
      switch (notification['type']) {
        case 'order_update':
          iconData = Icons.receipt;
          break;
        case 'special_offer':
          iconData = Icons.local_offer;
          break;
        case 'promotion':
          iconData = Icons.card_giftcard;
          break;
        default:
          iconData = Icons.notifications;
      }
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
        child: Icon(
          iconData,
          color: Theme.of(context).primaryColor,
        ),
      ),
      title: Text(
        notification['title'] ?? 'Notification',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(notification['message'] ?? ''),
          const SizedBox(height: 4),
          Text(
            formattedDate,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
      onTap: () {
        // Handle notification tap
        _handleNotificationTap(notification);
      },
    );
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    // Example: Navigate based on notification type
    if (notification.containsKey('type') && notification.containsKey('data')) {
      final type = notification['type'];
      final data = notification['data'];
      
      switch (type) {
        case 'order_update':
          if (data != null && data.containsKey('order_id')) {
            Navigator.pushNamed(
              context, 
              '/order-details',
              arguments: {'order_id': data['order_id']},
            );
          }
          break;
          
        case 'special_offer':
          // Navigate to offers page or specific restaurant
          if (data != null && data.containsKey('vendor_id')) {
            Navigator.pushNamed(
              context,
              '/restaurant-detail',
              arguments: {'vendor_id': data['vendor_id']},
            );
          }
          break;
          
        default:
          // Do nothing or show details in a dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(notification['title'] ?? 'Notification'),
              content: Text(notification['message'] ?? ''),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
      }
    }
  }
} 