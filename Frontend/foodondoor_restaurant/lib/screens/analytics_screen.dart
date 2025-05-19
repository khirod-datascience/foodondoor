import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'package:foodondoor_restaurant/utils/globals.dart';

class AnalyticsScreen extends StatefulWidget {
  @override
  _AnalyticsScreenState createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/auth/vendor-analytics/${Globals.vendorId}/'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _analytics = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to fetch analytics';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error';
        _isLoading = false;
      });
    }
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.orange.shade100,
              child: Icon(icon, color: Colors.orange.shade800),
            ),
            SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 16, color: Colors.orange.shade800)),
                SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Analytics'),
        backgroundColor: Colors.orange,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: Colors.red)))
              : _analytics == null
                  ? Center(child: Text('No analytics data available'))
                  : RefreshIndicator(
                      onRefresh: _fetchAnalytics,
                      child: ListView(
                        padding: EdgeInsets.all(16),
                        children: [
                          _buildAnalyticsCard('Total Orders', (_analytics!['total_orders'] ?? '0').toString(), Icons.shopping_cart),
                          _buildAnalyticsCard('Total Revenue', '₹${_analytics!['total_revenue'] ?? '0'}', Icons.attach_money),
                          _buildAnalyticsCard('Pending Orders', (_analytics!['pending_orders'] ?? '0').toString(), Icons.hourglass_empty),
                          _buildAnalyticsCard('Completed Orders', (_analytics!['completed_orders'] ?? '0').toString(), Icons.check_circle),
                          _buildAnalyticsCard('Popular Item', (_analytics!['popular_item'] ?? 'N/A').toString(), Icons.star),
                          SizedBox(height: 24),
                          Text('More analytics coming soon...', style: TextStyle(color: Colors.orange.shade700)),
                        ],
                      ),
                    ),
    );
  }
}
