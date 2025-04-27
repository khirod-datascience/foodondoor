import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import '../mainScreens/order_details_screen.dart';
import '../models/items.dart';

class OrderCard extends StatelessWidget {
  final int? itemCount;
  // final List<DocumentSnapshot>? data;
  final List<dynamic>? data; // Use dynamic list for now
  final String? orderID;
  final List<String>? seperateQuantitiesList;

  OrderCard({
    super.key, // Add super.key
    this.itemCount,
    this.data,
    this.orderID,
    this.seperateQuantitiesList,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (c) => OrderDetailsScreen(orderID: orderID)));
      },
      child: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
          colors: [
            Colors.black12,
            Colors.white54,
          ],
          begin: FractionalOffset(0.0, 0.0),
          end: FractionalOffset(1.0, 0.0),
          stops: [0.0, 1.0],
          tileMode: TileMode.clamp,
        )),
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.all(10),
        // Ensure itemCount is not null before multiplying, provide default
        height: (itemCount ?? 0) * 125,
        child: ListView.builder(
          itemCount: itemCount ?? 0, // Handle null itemCount
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            // Temporarily return placeholder as data structure is unknown
            // and depends on Firebase DocumentSnapshot which is removed.
            // Items model = Items.fromJson(data![index].data()! as Map<String, dynamic>);
            // return placedOrderDesignWidget(model, context, seperateQuantitiesList![index]);
            return Container(
              height: 120,
              child: const Center(
                child: Text("Item Detail Placeholder (Requires API Refactor)"),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Keep placedOrderDesignWidget function as is for now, but it won't be called
// until the ListView.builder is properly refactored with API data.
Widget placedOrderDesignWidget(
    Items model, BuildContext context, seperateQuantitiesList) {
  return Container(
    width: MediaQuery.of(context).size.width,
    height: 120,
    color: Colors.grey[200],
    child: Row(
      children: [
        Image.network(
          model.thumbnailUrl!,
          width: 120,
        ),
        const SizedBox(
          width: 10,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                height: 20,
              ),
              Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: Text(
                      model.title!,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontFamily: "Acme",
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  const Text(
                    "₹",
                    style: TextStyle(fontSize: 16, color: Colors.blue),
                  ),
                  Text(
                    model.price.toString(),
                    style: const TextStyle(color: Colors.blue, fontSize: 18),
                  )
                ],
              ),
              const SizedBox(
                height: 20,
              ),
              Row(
                children: [
                  const Text(
                    "x",
                    style: TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                  Expanded(
                    child: Text(
                      seperateQuantitiesList,
                      style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 30,
                          fontFamily: "Acme"),
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
