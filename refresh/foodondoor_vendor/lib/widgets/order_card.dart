import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
// Removed unused imports
// import '../model/items.dart';
// import '../widgets/order_details_screen.dart'; // Navigation handled in parent screen

class OrderCard extends StatelessWidget {
  final Map<String, dynamic> orderData;
  final VoidCallback onTap;

  const OrderCard({
    super.key,
    required this.orderData,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Extract data with null safety
    final orderNumber = orderData['order_number']?.toString() ?? 'N/A';
    final totalPrice = double.tryParse(orderData['total_price']?.toString() ?? '0.0') ?? 0.0;
    final status = orderData['status']?.toString() ?? 'Unknown';
    final customerName = orderData['customer_name']?.toString() ?? '-';
    final itemsList = orderData['items'] as List?;
    final itemCount = itemsList?.length ?? 0;
    final createdAtString = orderData['created_at']?.toString();
    String formattedDate = 'Unknown Date';
    if (createdAtString != null) {
      try {
        final createdAt = DateTime.parse(createdAtString);
        formattedDate = DateFormat('yyyy-MM-dd hh:mm a').format(createdAt); // Example format
      } catch (e) {
        debugPrint("Error parsing order date: $e");
      }
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      // Use InkWell for tap effect if desired, wrapping the Card content
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Order Number and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Order #$orderNumber",
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  // Chip to display status
                  Chip(
                    label: Text(status),
                    backgroundColor: _getStatusColor(status).withOpacity(0.1),
                    labelStyle: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                     visualDensity: VisualDensity.compact,
                     side: BorderSide.none,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Row 2: Customer Name and Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Customer: $customerName", style: textTheme.bodyMedium),
                  Text(formattedDate, style: textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 8),
              // Row 3: Item Count and Total Price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("$itemCount item${itemCount != 1 ? 's' : ''}", style: textTheme.bodyMedium),
                  Text(
                    "₹ ${totalPrice.toStringAsFixed(2)}",
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.secondary, // Use secondary color for price
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

   // Helper to determine status color (customize as needed)
   Color _getStatusColor(String status) {
      switch (status.toLowerCase()) {
        case 'pending':
          return Colors.orange.shade700;
        case 'accepted':
        case 'preparing':
          return Colors.blue.shade700;
         case 'readyforpickup':
            return Colors.cyan.shade700;
         case 'pickedup':
            return Colors.purple.shade700;
        case 'delivered':
          return Colors.green.shade700;
        case 'cancelled':
          return Colors.red.shade700;
        default:
          return Colors.grey.shade700;
      }
   }
}

// Removed placedOrderDesignWidget function
