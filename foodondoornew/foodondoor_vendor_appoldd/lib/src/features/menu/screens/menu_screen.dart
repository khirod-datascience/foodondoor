import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:foodondoor_vendor_app/src/features/menu/providers/menu_provider.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure the Provider is available when fetch is called
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Trigger fetch only if data hasn't been loaded or isn't currently loading
      final provider = context.read<MenuProvider>();
      if (provider.status == MenuStateStatus.initial || provider.status == MenuStateStatus.error) {
         print("[MenuScreen] Initializing fetch...");
         provider.fetchRestaurantAndMenu();
      } else {
         print("[MenuScreen] Skipping fetch, status: ${provider.status}");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Menu'),
        actions: [
          // Add refresh button later if needed
          // IconButton(
          //   icon: const Icon(Icons.refresh),
          //   onPressed: () => context.read<MenuProvider>().fetchRestaurantAndMenu(),
          // ),
           // Add '+' button later for adding categories/items
           IconButton(
             icon: const Icon(Icons.add_circle_outline), 
             tooltip: 'Add Category/Item', // Add tooltip
             onPressed: () {
               // TODO: Implement add category/item flow
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Add functionality coming soon!')),
               );
             },
           ),
        ],
      ),
      body: Consumer<MenuProvider>(
        builder: (context, provider, child) {
          switch (provider.status) {
            case MenuStateStatus.loading:
              print("[MenuScreen] Displaying Loading Indicator");
              return const Center(child: CircularProgressIndicator());
            case MenuStateStatus.error:
              print("[MenuScreen] Displaying Error: ${provider.errorMessage}");
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: ${provider.errorMessage ?? "Failed to load menu."}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.fetchRestaurantAndMenu(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            case MenuStateStatus.notFound:
               print("[MenuScreen] Displaying Not Found message");
               return Center(
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     const Icon(Icons.storefront_outlined, size: 60, color: Colors.grey),
                     const SizedBox(height: 16),
                     Text(
                      provider.errorMessage ?? 'Restaurant details not found.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                     ),
                     const SizedBox(height: 8),
                     const Text(
                      'Please complete your restaurant setup.', // TODO: Link to setup screen later
                      textAlign: TextAlign.center,
                     ),
                     const SizedBox(height: 16),
                     // TODO: Add Button to navigate to a potential Restaurant Setup Screen
                     // ElevatedButton(
                     //   onPressed: () { /* Navigate to setup screen */ },
                     //   child: const Text('Set Up Restaurant'),
                     // ),
                   ],
                 ),
               );
            case MenuStateStatus.loaded:
              print("[MenuScreen] Displaying Loaded State");
              final restaurant = provider.restaurant;
              if (restaurant == null) {
                // This case should ideally be handled by 'notFound' or 'error'
                return const Center(child: Text('Restaurant data is unexpectedly null.'));
              }
              // Basic display for now - will build out category/item list next
              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Text(
                    restaurant.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(restaurant.description ?? 'No description available.'),
                  const Divider(height: 32),
                  Text(
                    'Categories & Items (Coming Soon)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  // TODO: Build category and item list here
                  const Center(
                     child: Padding(
                       padding: EdgeInsets.all(32.0),
                       child: Text('Menu items will appear here.'),
                    )
                  )
                ],
              );
            case MenuStateStatus.initial:
            default: // Fallback for initial state or unexpected states
              print("[MenuScreen] Displaying Initial/Default State");
              return const Center(child: Text('Initializing menu...'));
          }
        },
      ),
    );
  }
}
