import 'package:flutter/material.dart';
import '../models/address.dart';
import '../splashScreen/splash_screen.dart';

class ShipmentAddressDesign extends StatelessWidget {
  final Address? model;

  const ShipmentAddressDesign({super.key, this.model});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(10.0),
          child: Text(
            "Shipping Details: ",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(
          height: 6,
        ),
        Row(
          children: [
            const Icon(Icons.person, color: Colors.cyan, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model!.address_line_1 ?? 'No Address Line 1',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (model!.address_line_2 != null && model!.address_line_2!.isNotEmpty)
                    Text(model!.address_line_2!),
                ],
              ),
            )
          ],
        ),
        const SizedBox(height: 10),
        const Icon(Icons.phone, color: Colors.grey, size: 18),
        Text("Phone number not available"),
        const SizedBox(height: 10),
        const Icon(Icons.location_city, color: Colors.grey, size: 18),
        Text(
          "${model!.city ?? ''}, ${model!.state ?? ''} - ${model!.pincode ?? ''}",
          textAlign: TextAlign.justify,
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: Center(
            child: InkWell(
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const MySplashScreen()));
              },
              child: Container(
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.pinkAccent, Colors.redAccent],
                    begin: FractionalOffset(0.0, 0.0),
                    end: FractionalOffset(1.0, 0.0),
                    stops: [0.0, 1.0],
                    tileMode: TileMode.clamp,
                  ),
                ),
                width: MediaQuery.of(context).size.width - 40,
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
        )
      ],
    );
  }
}
