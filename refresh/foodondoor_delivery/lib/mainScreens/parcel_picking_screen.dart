import 'package:flutter/material.dart';
import 'package:foodondoor_delivery/services/api_service.dart';
import 'package:foodondoor_delivery/widgets/progress_bar.dart';
import '../assistant_methods/get_current_location.dart';
import '../global/global.dart';
import '../mainScreens/parcel_delivering_screen.dart';
import '../maps/map_utils.dart';
import '../models/order_model.dart';

class ParcelPickingScreen extends StatefulWidget {
  final OrderModel orderModel;

  const ParcelPickingScreen({
    super.key,
    required this.orderModel,
  });

  @override
  State<ParcelPickingScreen> createState() => _ParcelPickingScreenState();
}

class _ParcelPickingScreenState extends State<ParcelPickingScreen> {
  bool _isUpdating = false;
  final ApiService _apiService = ApiService();

  Future<void> _confirmPickup() async {
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
        newStatus: "delivering",
        lat: position!.latitude,
        lng: position!.longitude,
      );

      if (success && mounted) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (c) => ParcelDeliveringScreen(
                      orderModel: widget.orderModel,
                    )));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to confirm pickup. Please try again."), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print("Error confirming pickup: $e");
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
    return Scaffold(
      appBar: AppBar(
          title: Text("Pickup Order: ${widget.orderModel.orderId.substring(0, 6)}..."),
          leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
          ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            "assets/images/confirm1.png",
            width: 350,
          ),
          const SizedBox(
            height: 5,
          ),
          /* --- Seller Location Button - Commented Out: Seller Lat/Lng Unavailable --- */
          /*
          GestureDetector(
            onTap: () {
              if (sellerLat != null && sellerLng != null && position != null) {
                MapUtils.launchMapFromSourceToDestination(
                    position!.latitude, position!.longitude, sellerLat, sellerLng);
              } else {
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Could not get seller or current location to show route."), backgroundColor: Colors.orange),
                  );
                 print("Missing location data: Rider Lat: ${position?.latitude}, Rider Lng: ${position?.longitude}, Seller Lat: $sellerLat, Seller Lng: $sellerLng");
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  "assets/images/restaurant.png",
                  width: 50,
                ),
                const SizedBox(
                  width: 7,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SizedBox(
                      height: 13,
                    ),
                    Text(
                      "Show Seller/Restaurant Location",
                      style: TextStyle(
                          color: Colors.blue,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: "Acme"
                         ),
                    ),
                  ],
                )
              ],
            ),
          ),
          */
          /* --- End Seller Location Button --- */

          const SizedBox(
            height: 25,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Center(
              child: InkWell(
                onTap: _isUpdating ? null : _confirmPickup,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: _isUpdating ? [Colors.grey, Colors.grey] : [Colors.cyan, Colors.amber],
                      begin: FractionalOffset(0.0, 0.0),
                      end: FractionalOffset(1.0, 0.0),
                      stops: const [0.0, 1.0],
                      tileMode: TileMode.clamp,
                    ),
                  ),
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: 50,
                  child: _isUpdating
                      ? circularProgress()
                      : const Text(
                          "Confirm: Order Picked Up",
                          style: TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
