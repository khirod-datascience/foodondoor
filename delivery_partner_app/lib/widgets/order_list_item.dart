import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../models/order.dart';

class OrderListItem extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;

  const OrderListItem({super.key, required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                    Text(
                       'Order #${order.orderNumber}',
                       style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                       '₹${order.orderTotal.toStringAsFixed(2)}', // Example currency format
                       style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
                    ),
                 ],
              ),
              const SizedBox(height: 6),
              Text('From: ${order.restaurantName}', style: theme.textTheme.bodyMedium),
              Text('To: ${order.deliveryAddress.street}', style: theme.textTheme.bodyMedium),
               const SizedBox(height: 4),
              Text('Status: ${order.status.toString().split('.').last}', // Simple status display
                  style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
              const SizedBox(height: 4),
              Text(formattedDate, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }
}
