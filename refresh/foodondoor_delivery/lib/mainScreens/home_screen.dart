import 'package:flutter/material.dart';
import '../global/global.dart';
import '../mainScreens/earning_screens.dart';
import '../mainScreens/history_screen.dart';
import '../mainScreens/new_orders_screen.dart';
import '../mainScreens/not_yetDelivered_screen.dart';
import '../mainScreens/parcel_in_progress.dart';
import '../assistant_methods/get_current_location.dart';
import '../services/api_service.dart';
import '../authentication/otp_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Card makeDashboardItems(String title, IconData iconData, int index) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(8),
      child: Container(
        decoration: index == 0 || index == 3 || index == 4
            ? const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.redAccent, Colors.pinkAccent],
                  begin: FractionalOffset(0.0, 0.0),
                  end: FractionalOffset(1.0, 0.0),
                  stops: [0.0, 1.0],
                  tileMode: TileMode.clamp,
                ),
              )
            : const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.redAccent, Colors.amber],
                  begin: FractionalOffset(0.0, 0.0),
                  end: FractionalOffset(1.0, 0.0),
                  stops: [0.0, 1.0],
                  tileMode: TileMode.clamp,
                ),
              ),
        child: InkWell(
          onTap: () async {
            if (index == 0) {
              // new order
              Navigator.push(context,
                  MaterialPageRoute(builder: (c) => const NewOrdersScreen()));
            }
            //Parcel in progress
            if (index == 1) {
              // Parcel in progress
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => const ParcelInProgressScreen())); // Fix Class name
            }
            if (index == 2) {
              // not yet delivered
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (c) => const NotYetDeliveredScreen()));
            }
            if (index == 3) {
              // history
              Navigator.push(context,
                  MaterialPageRoute(builder: (c) => const HistoryScreen()));
            }
            if (index == 4) {
              // total earning
              Navigator.push(context,
                  MaterialPageRoute(builder: (c) => const EarningScreen()));
            }
            if (index == 5) {
              // logout
              bool confirmLogout = await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text("Confirm Logout"),
                  content: Text("Are you sure you want to log out?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text("Logout"),
                    ),
                  ],
                ),
              ) ?? false;

              if (confirmLogout) {
                try {
                  await ApiService().logout();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (c) => const OtpScreen()),
                    (route) => false,
                  );
                } catch (e) {
                  print("Logout error: $e");
                }
              }
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            verticalDirection: VerticalDirection.down,
            children: [
              const SizedBox(
                height: 50,
              ),
              Center(
                child: Icon(
                  iconData,
                  size: 40,
                  color: Colors.black,
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Center(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, color: Colors.black),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    UserLocation uLocation = UserLocation();
    uLocation.getCurrentLocation();
    // getPerParcelDeliveryAmount();
    // getRiderPreviousEarnings();
  }

  // getRiderPreviousEarnings() {
  //   FirebaseFirestore.instance
  //       .collection("riders")
  //       .doc(sharedPreferences!.getString("uid"))
  //       .get()
  //       .then((snap) {
  //     previousRidersEarnings = snap.data()!["earnings"].toString();
  //   });
  // }

  // getPerParcelDeliveryAmount() {
  //   FirebaseFirestore.instance
  //       .collection("perDelivery")
  //       .doc("alizeb438")
  //       .get()
  //       .then((snap) {
  //     perParcelDeliveryAmount = snap.data()!["amount"].toString();
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    String userName = sharedPreferences?.getString("name") ?? "Rider Name";
    String userPhotoUrl = sharedPreferences?.getString("photoUrl") ?? "";

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red, Colors.pink],
              begin: FractionalOffset(0.0, 0.0),
              end: FractionalOffset(1.0, 0.0),
              stops: [0.0, 1.0],
              tileMode: TileMode.clamp,
            ),
          ),
        ),
        title: Text(
          "Welcome $userName",
          style: const TextStyle(
              fontSize: 25,
              color: Colors.white,
              letterSpacing: 2,
              fontFamily: "Signatra"),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 1),
        child: GridView.count(
          crossAxisCount: 2,
          padding: const EdgeInsets.all(2),
          children: [
            makeDashboardItems("New Available Orders", Icons.assignment, 0),
            makeDashboardItems("Parcel in Progress", Icons.airport_shuttle, 1),
            makeDashboardItems("Not Yet Delivered", Icons.location_history, 2),
            makeDashboardItems("History", Icons.done, 3),
            makeDashboardItems("Totol Earning", Icons.monetization_on, 4),
            makeDashboardItems("Logout", Icons.logout, 5),
          ],
        ),
      ),
    );
  }
}
