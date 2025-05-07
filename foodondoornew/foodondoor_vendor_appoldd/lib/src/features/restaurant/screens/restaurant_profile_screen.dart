import 'package:flutter/material.dart';
import 'package:foodondoor_vendor_app/src/features/restaurant/models/restaurant_model.dart';
import 'package:foodondoor_vendor_app/src/features/restaurant/providers/restaurant_provider.dart';
import 'package:foodondoor_vendor_app/src/features/restaurant/screens/edit_restaurant_screen.dart';
import 'package:provider/provider.dart';

class RestaurantProfileScreen extends StatefulWidget {
  const RestaurantProfileScreen({Key? key}) : super(key: key);

  static const String routeName = '/restaurant-profile';

  @override
  State<RestaurantProfileScreen> createState() => _RestaurantProfileScreenState();
}

class _RestaurantProfileScreenState extends State<RestaurantProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch details when the screen loads, but only if not already loaded/loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<RestaurantProvider>(context, listen: false);
      if (provider.status == RestaurantStatus.initial || provider.status == RestaurantStatus.error) {
         print("[RestaurantProfileScreen] Initial fetch triggered.");
         provider.fetchRestaurantDetails();
      } else {
         print("[RestaurantProfileScreen] Skipping initial fetch, status: ${provider.status}");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Profile'),
        actions: [
          Consumer<RestaurantProvider>( // Use Consumer to access restaurant data
            builder: (context, provider, child) {
              if (provider.status == RestaurantStatus.loaded && provider.restaurant != null) {
                // Only show edit button if data is loaded
                return IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit Profile',
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      EditRestaurantScreen.routeName,
                      arguments: provider.restaurant, // Pass current restaurant data
                    );
                  },
                );
              }
              return const SizedBox.shrink(); // Return empty if not loaded
            },
          ),
        ],
      ),
      body: Consumer<RestaurantProvider>(
        builder: (context, provider, child) {
          switch (provider.status) {
            case RestaurantStatus.loading:
            case RestaurantStatus.initial: // Show loading initially too
               print("[RestaurantProfileScreen] Displaying loading indicator.");
              return const Center(child: CircularProgressIndicator());
            case RestaurantStatus.error:
            case RestaurantStatus.updateError: // Show error message
               print("[RestaurantProfileScreen] Displaying error message: ${provider.errorMessage}");
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 60),
                      const SizedBox(height: 16),
                      Text(
                        'Error: ${provider.errorMessage ?? "Could not load restaurant details."}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        onPressed: () => _fetchDetails(), // Retry fetching
                      )
                    ],
                  ),
                ),
              );
            case RestaurantStatus.loaded:
            case RestaurantStatus.updating: // Show loaded data even while updating
              if (provider.restaurant == null) {
                return const Center(child: Text('No restaurant data found.'));
              }
              final restaurant = provider.restaurant!;
              return RefreshIndicator(
                onRefresh: () => _fetchDetails(), // Allow pull-to-refresh
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    if (provider.status == RestaurantStatus.updating)
                       const Padding(
                         padding: EdgeInsets.only(bottom: 10.0),
                         child: LinearProgressIndicator(),
                       ),
                    _buildDetailItem(context, 'Name', restaurant.name),
                    _buildDetailItem(context, 'Description', restaurant.description ?? 'N/A'),
                    _buildDetailItem(context, 'Address', restaurant.address ?? 'N/A'), 
                    // _buildDetailItem(context, 'City', restaurant.city ?? 'N/A'), // Uncomment when added to model
                    // _buildDetailItem(context, 'State', restaurant.state ?? 'N/A'), // Uncomment when added to model
                    // _buildDetailItem(context, 'Postal Code', restaurant.postalCode ?? 'N/A'), // Uncomment when added to model
                    // _buildDetailItem(context, 'Phone', restaurant.phoneNumber ?? 'N/A'), // Uncomment when added to model
                    if (restaurant.logoUrl != null && restaurant.logoUrl!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Image.network(restaurant.logoUrl!, height: 150, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image), loadingBuilder: (context, child, loadingProgress) => loadingProgress == null ? child : const Center(child: CircularProgressIndicator())), 
                      ),
                    // Add other fields as needed (Cover Photo, Lat/Lng etc.)
                  ],
                ),
              );
          } // Closing brace for switch
        }, // Closing brace for builder
      ), // Closing parenthesis for Consumer
    ); // Closing parenthesis for Scaffold
  } // Closing brace for build method

  Widget _buildDetailItem(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Future<void> _fetchDetails() async {
    final provider = Provider.of<RestaurantProvider>(context, listen: false);
    await provider.fetchRestaurantDetails();
  }
}
