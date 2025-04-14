import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/order_provider.dart';
import '../globals.dart';
import '../config.dart';
import 'order_details_screen.dart';
import '../services/simple_notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    
    // Listen to FCM notification stream
    _notificationSubscription = SimpleNotificationService.instance.notifications.listen((notification) {
      setState(() {
        // Add new notifications at the top
        _notifications.insert(0, notification);
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  // Get initial notifications list / Refresh manually
  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Call the service to fetch latest notifications
      // This will trigger the stream if new ones are found
      await SimpleNotificationService.instance.refreshNotifications();
      
      // Set loading to false after a short delay to allow stream to update
      await Future.delayed(Duration(milliseconds: 200)); 
      if (mounted) {
        setState(() {
          _isLoading = false; 
        });
      }
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Error fetching notifications";
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_error!)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Notifications"),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchNotifications,
          ),
        ],
      ),
      body: Container(
        color: Colors.orange[50],
        child: RefreshIndicator(
          onRefresh: _fetchNotifications,
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red),
                          SizedBox(height: 16),
                          Text(_error!, style: TextStyle(color: Colors.red)),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchNotifications,
                            child: Text("Retry"),
                          ),
                        ],
                      ),
                    )
                  : _notifications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_none, size: 48, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                "No notifications available",
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final notification = _notifications[index];
                            return Card(
                              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: ListTile(
                                leading: Icon(
                                  notification['type'] == 'order' ? Icons.shopping_cart : Icons.notifications,
                                  color: Colors.orange,
                                ),
                                title: Text(notification['title'] ?? 'Notification'),
                                subtitle: Text(notification['message'] ?? ''),
                                trailing: Text(
                                  notification['timestamp'] ?? '',
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => NotificationDetailsScreen(notification: notification),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}

class NotificationDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> notification;

  NotificationDetailsScreen({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Notification Details"),
        backgroundColor: Colors.orange,
      ),
      body: Container(
        color: Colors.orange[50],
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            notification['type'] == 'order' ? Icons.shopping_cart : Icons.notifications,
                            color: Colors.orange,
                            size: 32,
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              notification['title'] ?? 'Notification',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        notification['message'] ?? '',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 16),
                      Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Time:",
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            notification['timestamp'] ?? 'N/A',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      if (notification['type'] == 'order') ...[
                        SizedBox(height: 16),
                        Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Order Status:",
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              notification['order_status'] ?? 'N/A',
                              style: TextStyle(
                                color: _getStatusColor(notification['order_status']),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (notification['order_id'] != null) ...[
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              // Navigate to order details
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OrderDetailScreen(
                                    orderId: notification['order_id'],
                                  ),
                                ),
                              );
                            },
                            child: Text("View Order Details"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
