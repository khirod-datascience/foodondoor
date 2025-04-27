import 'package:flutter/material.dart';
import 'package:foodondoor_delivery/services/api_service.dart';
import 'package:foodondoor_delivery/widgets/progress_bar.dart';
import '../assistant_methods/get_current_location.dart';
import '../global/global.dart';
import '../maps/map_utils.dart';
import '../splashScreen/splash_screen.dart';
import '../models/order_model.dart';

class ParcelDeliveringScreen extends StatefulWidget {
  final OrderModel orderModel;

  const ParcelDeliveringScreen({
    super.key,
    required this.orderModel,
  });

  @override
  State<ParcelDeliveringScreen> createState() => _ParcelDeliveringScreenState();
}

class _ParcelDeliveringScreenState extends State<ParcelDeliveringScreen> {
  bool _isUpdating = false;
  final ApiService _apiService = ApiService();

  Future<void> _confirmDelivery() async {
    setState(() {
      _isUpdating = true;
    });

    try {
      UserLocation uLocation = UserLocation();
      await uLocation.getCurrentLocation();

      if (position == null) {
        print("Warning: Could not get current location, proceeding without it.");
      }

      final success = await _apiService.updateOrderStatus(
        orderId: widget.orderModel.orderId,
        newStatus: "completed",
        lat: position?.latitude,
        lng: position?.longitude,
      );

      if (success && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (c) => const MySplashScreen()),
          (route) => false,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to confirm delivery. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Error confirming delivery: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("An error occurred: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
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
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final double? purchaserLat = widget.orderModel.addressLatitude;
    final double? purchaserLng = widget.orderModel.addressLongitude;

    return Scaffold(
      appBar: AppBar(
        title: Text("Deliver Order: ${widget.orderModel.orderId.substring(0, 6)}..."),
        leading: IconButton(
          icon: Icon(Icons.delivery_dining),
          onPressed: null,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            "assets/images/confirm2.png",
            height: MediaQuery.of(context).size.height * 0.3,
            fit: BoxFit.contain,
          ),
          const SizedBox(
            height: 15,
          ),
          GestureDetector(
            onTap: () {
              if (purchaserLat != null && purchaserLng != null && position != null) {
                MapUtils.launchMapFromSourceToDestination(
                  position!.latitude.toString(),
                  position!.longitude.toString(),
                  purchaserLat.toString(),
                  purchaserLng.toString(),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Could not get customer or current location to show route."),
                    backgroundColor: Colors.orange,
                  ),
                );
                print("Missing location data: Rider: ${position?.latitude},${position?.longitude} Customer: $purchaserLat,$purchaserLng");
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  "assets/images/home_marker.png",
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
                      "Show Delivery Drop-off Location",
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: "Acme",
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(
            height: 30,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Center(
              child: InkWell(
                onTap: _isUpdating ? null : _confirmDelivery,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: _isUpdating ? [Colors.grey, Colors.grey] : [Colors.green, Colors.lightGreen],
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
                          "Confirm: Order Delivered",
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
