import 'package:flutter/material.dart';
import '../services/customer_api_service.dart';

class RatingProvider extends ChangeNotifier {
  bool submitting = false;
  String? message;

  Future<void> submitRating(Map<String, dynamic> data) async {
    submitting = true; notifyListeners();
    final response = await CustomerApiService.submitRating(data);
    if (response.statusCode == 200) {
      message = 'Rating submitted!';
    } else {
      message = 'Failed to submit rating.';
    }
    submitting = false; notifyListeners();
  }
}
