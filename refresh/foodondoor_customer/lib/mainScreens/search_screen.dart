import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // Remove import
import '../models/sellers.dart';
import '../widgets/sellers_design.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // Future<QuerySnapshot>? restaurentsDocumentsList; // Comment out Future
  String sellerNameText = "";

  // initSearchingRestaurant(String textEntered)
  // {
  //   restaurentsDocumentsList = FirebaseFirestore.instance
  //       .collection("sellers")
  //       .where("sellerName", isGreaterThanOrEqualTo: textEntered)
  //       .get();
  // } // Comment out initialization function

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search', style: Theme.of(context).appBarTheme.titleTextStyle),
        centerTitle: true,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(child: TextField(
        onChanged: (textEntered) {
          setState(() {
            sellerNameText = textEntered;
          });
          // initSearchingRestaurant(textEntered); // Comment out call
        },
        decoration: InputDecoration(
          hintText: "Search Restaurant here...",
          hintStyle: const TextStyle(color: Colors.white54),
          border: InputBorder.none,
          suffixIcon: IconButton(
            icon: const Icon(Icons.search),
            color: Colors.white,
            onPressed: () {
              // initSearchingRestaurant(sellerNameText); // Comment out call
            },
          ),
        ),
        style: const TextStyle(color: Colors.white, fontSize: 16),
      )),
      // body: Center(child: Text("Search results will appear here later from API.")), // Placeholder
      // body: FutureBuilder<QuerySnapshot>(
      //   future: restaurentsDocumentsList,
      //   builder: (context, snapshot)
      //   {
      //     return snapshot.hasData
      //         ? ListView.builder(
      //             itemCount: snapshot.data!.docs.length,
      //             itemBuilder: (context, index)
      //             {
      //               Sellers model = Sellers.fromJson(
      //                 snapshot.data!.docs[index].data()! as Map<String, dynamic>
      //               );
      //
      //               return SellersDesignWidget(
      //                 model: model,
      //                 context: context,
      //               );
      //             },
      //           )
      //         : const Center(child: Text("No Record Found"),);
      //   },
      // ),
    );
  }
}
