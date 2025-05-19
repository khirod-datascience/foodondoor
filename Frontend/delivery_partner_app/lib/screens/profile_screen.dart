import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: user == null
            ? const Center(child: Text('User not logged in.')) // Should not happen if routed correctly
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      // TODO: Implement profile picture loading
                      backgroundImage: user.profilePictureUrl != null
                          ? NetworkImage(user.profilePictureUrl!)
                          : null,
                      child: user.profilePictureUrl == null
                          ? const Icon(Icons.person, size: 50)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildProfileInfo(context, 'Name', user.name),
                  _buildProfileInfo(context, 'Phone', user.phoneNumber),
                  if (user.email != null && user.email!.isNotEmpty)
                    _buildProfileInfo(context, 'Email', user.email!),

                  const Spacer(), // Pushes logout button to the bottom

                  Center(
                    child: ElevatedButton.icon(
                       icon: const Icon(Icons.logout, color: Colors.white),
                       label: const Text('Logout', style: TextStyle(color: Colors.white)),
                       style: ElevatedButton.styleFrom(
                         backgroundColor: Colors.redAccent,
                         padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                       ),
                       onPressed: () => _showLogoutConfirmation(context, authProvider),
                    ),
                  ),
                   const SizedBox(height: 20), // Bottom padding
                ],
              ),
      ),
    );
  }

  Widget _buildProfileInfo(BuildContext context, String label, String value) {
     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 8.0),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text(
             label,
             style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
           ),
           Text(
             value,
             style: Theme.of(context).textTheme.titleMedium,
           ),
           const Divider(),
         ],
       ),
     );
  }

   void _showLogoutConfirmation(BuildContext context, AuthProvider authProvider) {
     showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Logout',
                style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.of(ctx).pop(); // Close dialog
              authProvider.logout(); // Perform logout
              // AuthWrapper in main.dart will handle navigation back to LoginScreen
            },
          ),
        ],
      ),
    );
  }
}
