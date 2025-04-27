import 'package:flutter/material.dart';
import '../authentication/auth_screen.dart';
import '../global/global.dart';
import '../mainScreens/address_screen.dart';
import '../mainScreens/history_screen.dart';
import '../mainScreens/home_screen.dart';
import '../mainScreens/my_orders_screen.dart';
import '../mainScreens/search_screen.dart';
import '../services/api_service.dart';

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final String? photoUrl = sharedPreferences?.getString("photo");
    final String name = sharedPreferences?.getString("name") ?? "Guest";
    final String defaultAvatar = 'assets/images/default_avatar.png';

    return Drawer(
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 25, bottom: 10),
            child: Column(
              children: [
                Material(
                  borderRadius: const BorderRadius.all(Radius.circular(80)),
                  elevation: 10,
                  child: Padding(
                    padding: const EdgeInsets.all(1.0),
                    child: SizedBox(
                      height: 160,
                      width: 160,
                      child: CircleAvatar(
                        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                            ? NetworkImage(photoUrl)
                            : AssetImage(defaultAvatar) as ImageProvider,
                        onBackgroundImageError: (exception, stackTrace) {
                           print("Error loading profile image: $exception");
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Text(
                  name,
                  style: const TextStyle(
                      color: Colors.black, fontSize: 20, fontFamily: "Train"),
                )
              ],
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          Container(
            padding: const EdgeInsets.only(top: 1.0),
            child: Column(
              children: [
                const Divider(
                  height: 10,
                  color: Colors.grey,
                  thickness: 2,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.home,
                    color: Colors.black,
                  ),
                  title: const Text(
                    "Home",
                    style: TextStyle(color: Colors.black),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
                  },
                ),
                const Divider(
                  height: 10,
                  color: Colors.grey,
                  thickness: 2,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.reorder,
                    color: Colors.black,
                  ),
                  title: const Text(
                    "My Orders",
                    style: TextStyle(color: Colors.black),
                  ),
                  onTap: () {
                     Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => MyOrdersScreen()));
                  },
                ),
                const Divider(
                  height: 10,
                  color: Colors.grey,
                  thickness: 2,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.access_time,
                    color: Colors.black,
                  ),
                  title: const Text(
                    "History",
                    style: TextStyle(color: Colors.black),
                  ),
                  onTap: () {
                     Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const HistoryScreen()));
                  },
                ),
                const Divider(
                  height: 10,
                  color: Colors.grey,
                  thickness: 2,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.search,
                    color: Colors.black,
                  ),
                  title: const Text(
                    "Search",
                    style: TextStyle(color: Colors.black),
                  ),
                  onTap: () {
                     Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => SearchScreen()));
                  },
                ),
                const Divider(
                  height: 10,
                  color: Colors.grey,
                  thickness: 2,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.add_location,
                    color: Colors.black,
                  ),
                  title: const Text(
                    "Add new Address",
                    style: TextStyle(color: Colors.black),
                  ),
                  onTap: () {
                     Navigator.pop(context);
                     Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => AddressScreen()));
                  },
                ),
                const Divider(
                  height: 10,
                  color: Colors.grey,
                  thickness: 2,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.exit_to_app,
                    color: Colors.black,
                  ),
                  title: const Text(
                    "Sign Out",
                    style: TextStyle(color: Colors.black),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final apiService = ApiService();
                    await apiService.deleteToken();

                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const AuthScreen()),
                      (route) => false,
                    );
                  },
                ),
                const Divider(
                  height: 10,
                  color: Colors.grey,
                  thickness: 2,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
