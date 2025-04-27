import 'package:flutter/material.dart';
import '../authentication/login.dart';
import '../global/global.dart';
import '../mainScreens/earning_screens.dart';
import '../mainScreens/history_screen.dart';
import '../mainScreens/home_screen.dart';
import '../mainScreens/new_orders_screen.dart';
import '../api/api_service.dart';

class MyDrawer extends StatelessWidget {
  final ApiService _apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    String name = sharedPreferences?.getString("name") ?? "Vendor Name";
    String email = sharedPreferences?.getString("email") ?? "vendor@email.com";
    String photoUrl = sharedPreferences?.getString("PhotoUrl") ?? "";

    return Drawer(
      child: ListView(
        children: [
          Container(
            color: Theme.of(context).colorScheme.primary,
            padding: const EdgeInsets.only(top: 40, bottom: 20),
            child: Column(
              children: [
                Material(
                  borderRadius: const BorderRadius.all(Radius.circular(80)),
                  elevation: 8,
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: SizedBox(
                      height: 100,
                      width: 100,
                      child: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        backgroundImage: photoUrl.isNotEmpty
                           ? NetworkImage(photoUrl)
                           : null,
                        child: photoUrl.isEmpty
                           ? Icon(Icons.person, size: 60, color: Theme.of(context).colorScheme.primary)
                           : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(name, style: TextStyle(fontSize: 20, fontFamily: "TrainOne", color: Theme.of(context).colorScheme.onPrimary)),
                Text(email, style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 1.0),
            child: Column(
              children: [
                Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.5)),
                ListTile(
                  leading: Icon(
                    Icons.home,
                  ),
                  title: const Text(
                    "Home",
                  ),
                  onTap: () {
                    Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const HomeScreen()));
                  },
                ),
                Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.5)),
                ListTile(
                  leading: const Icon(
                    Icons.access_time,
                  ),
                  title: const Text(
                    "My Earnings",
                  ),
                  onTap: () {
                     Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const EarningScreen()));
                  },
                ),
                Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.5)),
                ListTile(
                  leading: const Icon(
                    Icons.reorder,
                  ),
                  title: const Text(
                    "New orders",
                  ),
                  onTap: () {
                     Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const NewOrdersScreen()));
                  },
                ),
                Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.5)),
                ListTile(
                  leading: const Icon(
                    Icons.local_shipping,
                  ),
                  title: const Text(
                    "History - Orders",
                  ),
                  onTap: () {
                    Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const HistoryScreen()));
                  },
                ),
                Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.5)),
                ListTile(
                  leading: Icon(
                    Icons.logout,
                    color: Colors.red.shade700,
                  ),
                  title: Text(
                    "Sign Out",
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                  onTap: () async {
                    await _apiService.logoutVendor();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (c) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                ),
                Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.5)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
