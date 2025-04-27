import 'package:flutter/material.dart';
import 'package:foodondoor_delivery/services/api_service.dart';
import 'package:foodondoor_delivery/widgets/progress_bar.dart';
import '../global/global.dart';
import '../mainScreens/parcel_picking_screen.dart';

import '../assistant_methods/get_current_location.dart';
import '../models/address.dart';
import '../models/order_model.dart';
import '../splashScreen/splash_screen.dart';

class ShipmentAddressDesign extends StatefulWidget {
  final OrderModel orderModel;

  const ShipmentAddressDesign({
    super.key,
    required this.orderModel,
  });

  @override
  State<ShipmentAddressDesign> createState() => _ShipmentAddressDesignState();
}

class _ShipmentAddressDesignState extends State<ShipmentAddressDesign> {
  bool _isUpdating = false;
  final ApiService _apiService = ApiService();

  Future<void> _acceptOrderForPicking(BuildContext context) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      UserLocation uLocation = UserLocation();
      await uLocation.getCurrentLocation();

      if (position == null || completeAddress == null || completeAddress!.isEmpty) {
        throw Exception("Could not get current location. Please ensure location services are enabled and try again.");
      }

      final success = await _apiService.updateOrderStatus(
        orderId: widget.orderModel.orderId,
        newStatus: "picking",
        lat: position!.latitude,
        lng: position!.longitude,
      );

      if (success && mounted) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => ParcelPickingScreen(
                      orderModel: widget.orderModel,
                    )));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update order status. Please try again."), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print("Error accepting order: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An error occurred: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String orderStatus = widget.orderModel.status;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(10.0),
          child: Text(
            "Shipping Details: ",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 5),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Text(
              "Location: Lat: ${widget.orderModel.addressLatitude.toStringAsFixed(4)}, Lng: ${widget.orderModel.addressLongitude.toStringAsFixed(4)}",
              textAlign: TextAlign.left,
            ),
          ),
        ),
        const SizedBox(height: 15),
        if (orderStatus == "pending")
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Center(
              child: _isUpdating
                  ? circularProgress()
                  : InkWell(
                      onTap: () {
                        _acceptOrderForPicking(context);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            colors: [Colors.cyan, Colors.amber],
                            begin: FractionalOffset(0.0, 0.0),
                            end: FractionalOffset(1.0, 0.0),
                            stops: [0.0, 1.0],
                            tileMode: TileMode.clamp,
                          ),
                        ),
                        width: MediaQuery.of(context).size.width * 0.85,
                        height: 50,
                        child: const Center(
                          child: Text(
                            "Confirm - Accept Order for Pickup",
                            style: TextStyle(color: Colors.white, fontSize: 15.0, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: Center(
            child: InkWell(
              onTap: () {
                Navigator.pop(context);
              },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [Colors.grey, Colors.blueGrey],
                    begin: FractionalOffset(0.0, 0.0),
                    end: FractionalOffset(1.0, 0.0),
                    stops: [0.0, 1.0],
                    tileMode: TileMode.clamp,
                  ),
                ),
                width: MediaQuery.of(context).size.width * 0.85,
                height: 50,
                child: const Center(
                  child: Text(
                    "Go Back",
                    style: TextStyle(color: Colors.white, fontSize: 15.0),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
