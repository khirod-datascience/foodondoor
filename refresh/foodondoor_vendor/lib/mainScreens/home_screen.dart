import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../global/global.dart';
import '../widgets/my_drower.dart';
import '../uploadScreens.dart/menus_upload_screen.dart';
import 'new_orders_screen.dart';
import 'itemsScreen.dart'; // Correct relative import
// Import a model for Menu if you have one, otherwise use Map<String, dynamic>
// import '../models/menu.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  int pendingOrdersCount = 0;
  String vendorName = "";
  bool isLoading = true;
  bool isLoadingMenus = true; // Loading state for menus
  List<Map<String, dynamic>> vendorMenus = []; // State variable for menus
  String? menuError; // State variable for menu loading errors

  @override
  void initState() {
    super.initState();
    vendorName = sharedPreferences?.getString("name") ?? "Vendor";
    _loadInitialData(); // Load both orders and menus
  }

  Future<void> _loadInitialData() async {
    setState(() {
      isLoading = true; // For orders
      isLoadingMenus = true; // For menus
      menuError = null;
    });

    await _loadOrderData();
    await _loadMenuData();

    // Can set combined loading state if needed
    // if (mounted) {
    //   setState(() { isLoading = false; isLoadingMenus = false; });
    // }
  }

  Future<void> _loadOrderData() async {
    final ordersResponse = await _apiService.get('/vendor_auth/vendor/orders/?status=Pending');
    if (!mounted) return;
    setState(() {
      if (ordersResponse.containsKey('data') && ordersResponse['data'] is List) {
        pendingOrdersCount = ordersResponse['data'].length;
      } else {
        pendingOrdersCount = 0;
        debugPrint("Error fetching pending orders: ${ordersResponse['error']}");
      }
      isLoading = false; // Orders loaded (or failed)
    });
  }

  Future<void> _loadMenuData() async {
    final menusResponse = await _apiService.getMenus();
    if (!mounted) return;
    setState(() {
      if (menusResponse.containsKey('error')) {
        menuError = menusResponse['error'];
        vendorMenus = [];
        debugPrint("Error fetching menus: $menuError");
      } else if (menusResponse.containsKey('data') && menusResponse['data'] is List) {
        // Assuming the list contains maps representing Menu objects
        vendorMenus = List<Map<String, dynamic>>.from(menusResponse['data']);
        menuError = null;
      } else {
        menuError = "Unexpected response format when fetching menus.";
        vendorMenus = [];
         debugPrint(menuError);
      }
      isLoadingMenus = false; // Menus loaded (or failed)
    });
  }

  Widget _buildMenuList() {
    if (isLoadingMenus) {
      return const Center(child: CircularProgressIndicator());
    }
    if (menuError != null) {
      return Center(child: Text("Error loading menus: $menuError", style: const TextStyle(color: Colors.red)));
    }
    if (vendorMenus.isEmpty) {
      return const Center(child: Text("No menus found. Add one using the '+' button above!"));
    }

    return ListView.builder(
      itemCount: vendorMenus.length,
      itemBuilder: (context, index) {
        final menu = vendorMenus[index];
        final menuName = menu['name'] ?? 'Unnamed Menu'; // Use default if name is null
        final menuId = menu['id']; // Assuming 'id' is the key for the menu ID

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            // TODO: Add thumbnail if available (menu['thumbnail_url'] ?)
            leading: const Icon(Icons.menu_book),
            title: Text(menuName),
            subtitle: Text(menu['description'] ?? ''), // Show description if available
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              if (menuId != null) {
                debugPrint('Tapped on Menu ID: $menuId Name: $menuName');
                // Navigate to the refactored ItemsScreen
                Navigator.push(context, MaterialPageRoute(builder: (c) {
                    return ItemsScreen(menuId: menuId.toString(), menuName: menuName);
                }));
              } else {
                 debugPrint('Tapped on menu without an ID.');
                  ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Error: Cannot navigate. Menu ID is missing.'), backgroundColor: Colors.red)
                 );
              }
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: MyDrawer(),
      appBar: AppBar(
        title: Text(
          sharedPreferences?.getString("name") ?? "foodondoor",
          style: const TextStyle(fontSize: 30, fontFamily: "Lobster"),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.post_add),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const MenusUploadScreen()));
            },
          ),
        ],
      ),
      // Body now shows vendor info and the menu list
      body: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: isLoading
                 ? const Center(child: CircularProgressIndicator(strokeWidth: 2)) // Smaller indicator for orders
                 : Text(
                    "Pending Orders: $pendingOrdersCount",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                 ),
            ),
            const Divider(),
            const Padding(
               padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
               child: Text("Your Menus", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            // Expanded ListView for menus
            Expanded(
              child: _buildMenuList(),
            ),
            // REMOVED old buttons section
         ],
      ),
    );
  }
}
