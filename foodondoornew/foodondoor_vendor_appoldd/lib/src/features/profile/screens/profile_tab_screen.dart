import 'package:flutter/material.dart';
import 'package:foodondoor_vendor_app/src/features/auth/providers/auth_provider.dart';
import 'package:foodondoor_vendor_app/src/features/restaurant/screens/restaurant_profile_screen.dart';
import 'package:provider/provider.dart';

class ProfileTabScreen extends StatelessWidget {
  const ProfileTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // This screen will contain buttons/links for Restaurant Profile,
    // Settings, Logout etc.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            leading: const Icon(Icons.storefront),
            title: const Text('Restaurant Profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, RestaurantProfileScreen.routeName);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Account Settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to Account Settings Screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account Settings - Coming Soon!')),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red.shade700),
            title: Text('Logout', style: TextStyle(color: Colors.red.shade700)),
            onTap: () {
              // Show confirmation dialog before logging out
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Logout Confirmation'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                      },
                    ),
                    TextButton(
                      child: Text('Logout', style: TextStyle(color: Colors.red.shade700)),
                      onPressed: () {
                        Navigator.of(ctx).pop(); // Close dialog
                        context.read<AuthProvider>().logout(); // Perform logout
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
