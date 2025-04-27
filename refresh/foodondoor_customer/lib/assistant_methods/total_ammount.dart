import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart'; // Import ApiService

class TotalAmount extends ChangeNotifier {
 
  // double _totalAmount=0;
  double _totalAmount = 0.0; // Initialize to 0.0
  final ApiService _apiService = ApiService(); // Instantiate ApiService

  // double get tAmmount=>_totalAmount;
  double get totalAmount => _totalAmount;

  // Method to explicitly set the total amount
  // displayTotolAmmount(double number) async{
  void setTotalAmount(double newAmount) {
    // _totalAmount=number;
    _totalAmount = newAmount;
    notifyListeners();
    // Remove the arbitrary delay
    // await Future.delayed(const Duration(microseconds: 100),(){
    //   notifyListeners();
    // }
    // );
  }

  // Method to fetch total amount from API
  Future<void> fetchTotalAmount() async {
      try {
         final response = await _apiService.getCart();
         double fetchedAmount = 0.0;

         if (response['success'] == true && response.containsKey('total_amount')) {
            // Attempt to parse the total amount
            final rawAmount = response['total_amount'];
            if (rawAmount is double) {
               fetchedAmount = rawAmount;
            } else if (rawAmount is int) {
               fetchedAmount = rawAmount.toDouble();
            } else if (rawAmount is String) {
               fetchedAmount = double.tryParse(rawAmount) ?? 0.0;
            }
         } else {
             debugPrint("Cart API response missing 'total_amount' or call failed: ${response['error']}");
         }

          // Only update if the fetched amount is different
          if ((_totalAmount - fetchedAmount).abs() > 0.001) { // Compare doubles with tolerance
             _totalAmount = fetchedAmount;
             notifyListeners();
          }

      } catch (e) {
         debugPrint("Exception fetching total amount: ${e.toString()}");
          // Optionally reset to 0 on exception
         // if (_totalAmount != 0.0) {
         //    _totalAmount = 0.0;
         //    notifyListeners();
         // }
      }
  }
}
