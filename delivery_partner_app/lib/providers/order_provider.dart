import 'package:flutter/material.dart';
import '../services/order_service.dart';
import '../models/order.dart';

// Enum to represent the different order lists/tabs
enum OrderListType { pending, ongoing, completed }

class OrderProvider with ChangeNotifier {
  final OrderService _orderService = OrderService();

  // State variables
  Map<OrderListType, List<Order>> _orders = {
    OrderListType.pending: [],
    OrderListType.ongoing: [],
    OrderListType.completed: [],
  };
  Map<OrderListType, bool> _isLoading = {
    OrderListType.pending: false,
    OrderListType.ongoing: false,
    OrderListType.completed: false,
  };
  Map<OrderListType, String?> _errorMessages = {
    OrderListType.pending: null,
    OrderListType.ongoing: null,
    OrderListType.completed: null,
  };

  bool _isUpdatingOrder = false; // For single order actions (accept, reject, update status)
  String? _updateErrorMessage;

  // Getters for UI
  List<Order> ordersFor(OrderListType type) => _orders[type] ?? [];
  bool isLoading(OrderListType type) => _isLoading[type] ?? false;
  String? errorMessage(OrderListType type) => _errorMessages[type];

  bool get isUpdatingOrder => _isUpdatingOrder;
  String? get updateErrorMessage => _updateErrorMessage;

  // --- Fetching Orders ---

  Future<void> fetchOrders(OrderListType type, {bool forceRefresh = false}) async {
    // Avoid fetching if already loading or if data exists and not forcing refresh
    if (_isLoading[type]! || (!forceRefresh && _orders[type]!.isNotEmpty)) {
      return;
    }

    _isLoading[type] = true;
    _errorMessages[type] = null;
    notifyListeners();

    String statusParam;
    switch (type) {
      case OrderListType.pending:
        statusParam = 'pending';
        break;
      case OrderListType.ongoing:
        // Combine statuses that count as ongoing
        statusParam = 'accepted,readyForPickup,pickedUp,outForDelivery';
        break;
      case OrderListType.completed:
        statusParam = 'delivered,cancelled,rejected'; // Include rejected/cancelled here
        break;
    }

    final result = await _orderService.fetchOrders(status: statusParam);

    if (result['success']) {
      _orders[type] = result['orders'] as List<Order>;
    } else {
      _errorMessages[type] = result['message'] ?? 'Failed to fetch orders';
      _orders[type] = []; // Clear list on error
    }

    _isLoading[type] = false;
    notifyListeners();
  }

 // --- Order Actions ---

  Future<bool> acceptOrder(String orderId) async {
     return _handleOrderAction(() => _orderService.acceptOrder(orderId), orderId, OrderListType.pending);
  }

  Future<bool> rejectOrder(String orderId, {String? reason}) async {
    return _handleOrderAction(() => _orderService.rejectOrder(orderId, reason: reason), orderId, OrderListType.pending);
  }

  Future<bool> markAsPickedUp(String orderId) async {
    return _handleOrderAction(() => _orderService.markAsPickedUp(orderId), orderId, OrderListType.ongoing);
  }

  Future<bool> markAsDelivered(String orderId) async {
    return _handleOrderAction(() => _orderService.markAsDelivered(orderId), orderId, OrderListType.ongoing);
  }

  // Helper for order actions
  Future<bool> _handleOrderAction(Future<Map<String, dynamic>> Function() action, String orderId, OrderListType listToRemoveFrom) async {
    _isUpdatingOrder = true;
    _updateErrorMessage = null;
    notifyListeners();

    final result = await action();

    if (result['success']) {
      // Remove the order from its current list immediately for UI responsiveness
      _orders[listToRemoveFrom]?.removeWhere((order) => order.id == orderId);

      // TODO: Optionally fetch the updated order details or just refresh relevant lists
      // For simplicity, we'll just refresh the affected lists after a short delay
      // This isn't ideal for immediate feedback but avoids complex state merging.
      Future.delayed(const Duration(milliseconds: 500), () {
          refreshAllLists(); // Refresh all lists to ensure consistency
      });

       _isUpdatingOrder = false;
       notifyListeners();
       return true;
    } else {
      _updateErrorMessage = result['message'] ?? 'Failed to update order status';
      _isUpdatingOrder = false;
      notifyListeners();
      return false;
    }
  }

  // Refresh all order lists
  Future<void> refreshAllLists() async {
     // Reset state before fetching
     _orders = { OrderListType.pending: [], OrderListType.ongoing: [], OrderListType.completed: [] };
     _isLoading = { OrderListType.pending: false, OrderListType.ongoing: false, OrderListType.completed: false };
     _errorMessages = { OrderListType.pending: null, OrderListType.ongoing: null, OrderListType.completed: null };
     notifyListeners();

     // Fetch all lists concurrently
     await Future.wait([
        fetchOrders(OrderListType.pending, forceRefresh: true),
        fetchOrders(OrderListType.ongoing, forceRefresh: true),
        fetchOrders(OrderListType.completed, forceRefresh: true),
     ]);
  }
}
