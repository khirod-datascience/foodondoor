import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../global/global.dart';

import '../splashScreen/splash_screen.dart';

class EarningScreen extends StatefulWidget {
  const EarningScreen({super.key});

  @override
  State<EarningScreen> createState() => _EarningScreenState();
}

class _EarningScreenState extends State<EarningScreen> {
  double sellerTotalEarnings = 0;

  // TODO: Replace Firebase logic with API call to fetch earnings
  // Example placeholder function:
  Future<void> retriveSellersEarnings() async {
    // Simulate loading
    await Future.delayed(const Duration(seconds: 1));
    // Placeholder - fetch from API endpoint
    // final response = await ApiService().get('/vendor_auth/vendor/earnings/');
    // if (mounted && response.containsKey('total_earnings')) {
    //   setState(() {
    //     sellerTotalEarnings = double.tryParse(response['total_earnings'].toString()) ?? 0.0;
    //   });
    // }
    if (mounted) {
       setState(() {
         sellerTotalEarnings = 0.0; // Placeholder value changed to 0.0
       });
    }
    debugPrint("WARNING: Earnings are currently placeholder values.");
  }

  @override
  void initState() {
    super.initState();
    retriveSellersEarnings();
  }

  @override
  Widget build(BuildContext context) {
    // Use Theme colors
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      // Use themed background color
      // backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Earnings"), // Add an AppBar
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context), // Allow back navigation
          ),
      ),
      body: SafeArea(
          child: Center( // Center the content
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ignore: prefer_interpolation_to_compose_strings
                Text(
                  "₹ ${sellerTotalEarnings.toStringAsFixed(2)}", // Format currency
                  style: textTheme.displayLarge?.copyWith(
                    color: colorScheme.primary, // Use primary color for amount
                    fontFamily: "Signatra", // Keep custom font if desired
                    fontSize: 60, // Adjusted size
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Total Earnings",
                  style: textTheme.titleMedium?.copyWith(
                    // color: Colors.grey, // Use default text color from theme
                    letterSpacing: 2, // Reduced spacing
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 200,
                  child: Divider(
                    color: colorScheme.primary.withOpacity(0.5), // Use theme color
                    thickness: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                // REMOVED Back Button Card (use AppBar back button)
                // GestureDetector(
                //   onTap: () {
                //     Navigator.push(context,
                //         MaterialPageRoute(builder: (c) => MySplashScreen()));
                //   },
                //   child: const Card(...)
                // )
              ],
            ),
          )),
    );
  }
}
