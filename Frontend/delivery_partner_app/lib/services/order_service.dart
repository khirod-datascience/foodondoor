import '../models/order.dart';
import 'api_helper.dart';

class OrderService {
  final ApiHelper _apiHelper = ApiHelper();

  // Fetch orders based on status (pending, ongoing, completed)
  Future<Map<String, dynamic>> fetchOrders({String status = 'pending'}) async {
    // Endpoint might look like /delivery/orders?status=pending
    final response = await _apiHelper.get('/orders?status=$status');

    if (response['success']) {
      try {
        final List<dynamic> orderData = response['data'] ?? [];
        final List<Order> orders = orderData
            .map((data) => Order.fromJson(data as Map<String, dynamic>))
            .toList();
        return {'success': true, 'orders': orders};
      } catch (e) {
         print("Order parsing error: $e");
         return {'success': false, 'message': 'Error parsing order data.'};
      }
    } else {
      return response; // Return the error response from ApiHelper
    }
  }

  // Fetch a single order by ID
  Future<Map<String, dynamic>> fetchOrderDetails(String orderId) async {
     final response = await _apiHelper.get('/orders/$orderId/');
     if (response['success']) {
        try {
           final Order order = Order.fromJson(response['data'] as Map<String, dynamic>);
           return {'success': true, 'order': order};
        } catch (e) {
          print("Order details parsing error: $e");
          return {'success': false, 'message': 'Error parsing order details.'};
        }
     } else {
       return response;
     }
  }

  // Accept an order
  Future<Map<String, dynamic>> acceptOrder(String orderId) async {
    // Endpoint might be /delivery/orders/{orderId}/accept/
    final response = await _apiHelper.post('/orders/$orderId/accept/');
    return response; // Return success/failure directly
  }

  // Reject an order
  Future<Map<String, dynamic>> rejectOrder(String orderId, {String? reason}) async {
     // Endpoint might be /delivery/orders/{orderId}/reject/
     final response = await _apiHelper.post(
        '/orders/$orderId/reject/',
        body: reason != null ? {'reason': reason} : null,
     );
     return response;
  }

  // Update order status (e.g., picked_up, delivered)
  Future<Map<String, dynamic>> updateOrderStatus(String orderId, OrderStatus newStatus) async {
     // Endpoint might be /delivery/orders/{orderId}/status/
     // Or potentially specific endpoints like /pickup/, /deliver/

     String statusString = newStatus.toString().split('.').last; // Convert enum to string e.g., 'pickedUp'

     // Example using a general status update endpoint (adapt as needed)
     final response = await _apiHelper.put(
         '/orders/$orderId/status/', // Adjust endpoint if needed
         body: {'status': statusString}
     );
     return response;
  }

  // Specific functions for clarity (might call updateOrderStatus internally)
  Future<Map<String, dynamic>> markAsPickedUp(String orderId) async {
     // Could call updateOrderStatus or have a dedicated endpoint
     // return updateOrderStatus(orderId, OrderStatus.pickedUp);
     final response = await _apiHelper.post('/orders/$orderId/pickup/'); // Example dedicated endpoint
     return response;
  }

  Future<Map<String, dynamic>> markAsDelivered(String orderId) async {
     // Could call updateOrderStatus or have a dedicated endpoint
     // return updateOrderStatus(orderId, OrderStatus.delivered);
      final response = await _apiHelper.post('/orders/$orderId/deliver/'); // Example dedicated endpoint
     return response;
  }

}
