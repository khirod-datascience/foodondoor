import 'package:flutter/material.dart';
import 'dart:convert';
// Purpose: Provides the main home screen UI, including banners, categories, restaurants, and address selection.

import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import '../providers/home_provider.dart';
import '../utils/globals.dart';
import '../config.dart';
import '../services/customer_api_service.dart';
import './search_screen.dart';
import '../providers/cart_provider.dart';
import './cart_screen.dart';
import './profile_screen.dart';
import './add_edit_address_screen.dart';
import '../utils/auth_storage.dart';
import '../utils/auth_api.dart';
import '../providers/auth_provider.dart';
import './login_screen.dart';
import '../utils/auth_utils.dart'; // <-- Import the new utility

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Position _currentPosition;
  bool _isDeliveryAvailable = false;
  bool _locationPermissionDenied = false;
  String? _selectedCategory;
  bool _addressSheetShownAfterLoad = false; // Flag to show sheet only once
  String? _authToken;

  @override
  void initState() {
    super.initState();
    // Proactively refresh token on HomeScreen load
    refreshTokenIfNeeded(context);
    _checkAuthenticationStatus();
    // Schedule initialization after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkAuthToken();
        _verifyAuthentication(); // Add authentication check
        // Start both initialization and location check concurrently
        _initializeHomeScreenData(); // <<-- Now called after first frame
        _initializeLocationCheck(); // <<-- Location check can also start here
      }
    });
  }

  Future<void> _checkAuthToken() async {
    final token = await AuthStorage.getToken();
    debugPrint('(HomeScreen) Retrieved auth_token: ${token != null ? "exists" : "not found"}');
    if (token != null) {
      debugPrint('(HomeScreen) Token length: ${token.length}');
      // Log first characters of token for debugging
      debugPrint('(HomeScreen) Token begins with: ${token.substring(0, token.length > 10 ? 10 : token.length)}...');
    }
    _authToken = token;
  }

  // Verify authentication status and redirect to login if needed
  Future<void> _verifyAuthentication() async {
    if (mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await AuthStorage.getToken();
      
      if (token == null) {
        debugPrint('(HomeScreen) No auth token found, attempting refresh...');
        await refreshTokenIfNeeded(context);
        final refreshedToken = await AuthStorage.getToken();
        if (refreshedToken == null) {
          debugPrint('(HomeScreen) Still no auth token after refresh. Showing error but not logging out.');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Authentication error. Please try again later.')),
            );
          }
          return;
        }
      }

      try {
        final isAuthenticated = await authProvider.isAuthenticated();
        
        if (!isAuthenticated && mounted) {
          debugPrint('(HomeScreen) Token validation failed, attempting refresh...');
          await refreshTokenIfNeeded(context);
          final refreshedToken = await AuthStorage.getToken();
          if (refreshedToken == null) {
            debugPrint('(HomeScreen) Still no valid token after refresh. Showing error but not logging out.');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Authentication error. Please try again later.')),
              );
            }
            return;
          }
        }
        
        debugPrint('(HomeScreen) User is authenticated, continuing');
      } catch (e) {
        debugPrint('(HomeScreen) Error verifying authentication: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('An error occurred. Please try again later.')),
          );
        }
        _redirectToLogin('An error occurred. Please log in again.');
      }
    }
  }

  void _redirectToLogin([String? message]) {
    // If a message is provided, show it
    if (message != null && message.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  // Renamed original _initializeScreen to focus on location
  Future<void> _initializeLocationCheck() async {
    debugPrint('Starting location/delivery check...');
    await _getUserLocation(); // This will set _isDeliveryAvailable and _locationPermissionDenied
    // No need to call _initializeHomeScreenData here anymore
    // The UI will rebuild based on _isDeliveryAvailable when this finishes
  }

  Future<void> _getUserLocation() async {
    // Clear flags initially
    bool wasPermissionDenied = _locationPermissionDenied;
    setState(() {
      _locationPermissionDenied = false;
    });
    
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location service disabled.');
      setState(() { _locationPermissionDenied = true; });
      // If permission was previously granted, but service is now off, 
      // we might still show the main content but with a warning later.
      // Or force pincode if _isDeliveryAvailable is false after check.
      _checkDeliveryAvailability(); // Check without location to see if backend handles it
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permission denied.');
        setState(() { _locationPermissionDenied = true; });
        _checkDeliveryAvailability(); // Check without location
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permission denied forever.');
      setState(() { _locationPermissionDenied = true; });
       _checkDeliveryAvailability(); // Check without location
      return;
    }

    // If we reach here, permission is granted
    debugPrint('Location permission granted.');
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      debugPrint('Current position obtained: ${_currentPosition.latitude}, ${_currentPosition.longitude}');
      // Check delivery using fetched location (will prioritize global address first inside the method)
      await _checkDeliveryAvailability(
        latitude: _currentPosition.latitude,
        longitude: _currentPosition.longitude,
      );
    } catch (e) {
       debugPrint('Error getting current position: $e');
       setState(() { _locationPermissionDenied = true; }); 
       // Check delivery without location as fallback (will use global address if available)
       await _checkDeliveryAvailability(); 
    }
  }

  Future<void> _checkDeliveryAvailability({double? latitude, double? longitude, String? pincode}) async {
    // Prioritize using globalCurrentAddress if available
    Map<String, dynamic>? addressToCheck = globalCurrentAddress;
    double? checkLat = latitude;
    double? checkLon = longitude;
    String? checkPincode = pincode;

    if (addressToCheck != null) {
       debugPrint('Using globally set address for delivery check.');
       // Extract details from the global address if needed by API
       checkLat = (addressToCheck['latitude'] as num?)?.toDouble() ?? checkLat; 
       checkLon = (addressToCheck['longitude'] as num?)?.toDouble() ?? checkLon;
       checkPincode = addressToCheck['postal_code']?.toString() ?? checkPincode; 
    }

    bool deliveryStatusKnown = _isDeliveryAvailable || _locationPermissionDenied;

    try {
      debugPrint('Checking delivery availability (Using Lat: $checkLat, Lon: $checkLon, Pincode: $checkPincode)...');
      
      // Prepare request data with at least one location identifier
      final Map<String, dynamic> requestData = {};
      
      // Always include customer_id if available
      if (globalCustomerId != null) {
         requestData['customer_id'] = globalCustomerId;
      }

      // Add location data if available
      if (checkLat != null && checkLon != null) {
         requestData['latitude'] = checkLat;
         requestData['longitude'] = checkLon;
      } else if (checkPincode != null && checkPincode.isNotEmpty) {
         requestData['pincode'] = checkPincode;
      }

      // Ensure we have at least one location identifier
      if (!requestData.containsKey('latitude') && !requestData.containsKey('pincode')) {
         debugPrint('Cannot check delivery: No location data available.');
         if (mounted) setState(() { 
            _locationPermissionDenied = true; 
            _isDeliveryAvailable = false; 
         });
         return;
      }

      final dio = Dio();
      final String? token = await AuthStorage.getToken();
      final options = Options();
      if (token != null) {
        options.headers = {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        };
        debugPrint('(HomeScreen) Adding Auth header to check-delivery request.');
      }

      final response = await dio.post(
        '${AppConfig.baseUrl}/check-delivery/',
        data: requestData,
        options: options,
      );
      
      debugPrint('Delivery API Response: ${response.data}');

      final bool available = response.data['delivery_available'] ?? false;
      
      if (mounted) {
         setState(() {
            _isDeliveryAvailable = available;
            _locationPermissionDenied = false;
         });
         debugPrint('Delivery availability set to: $_isDeliveryAvailable');
      }
    } catch (e) {
      debugPrint('Error in delivery API call: $e');
      if (mounted) {
         setState(() {
            _isDeliveryAvailable = false;
            if (latitude == null && longitude == null && pincode == null && globalCurrentAddress == null) {
               _locationPermissionDenied = true;
            }
         });
      }
    }
  }

  Future<void> _initializeHomeScreenData() async {
    debugPrint('Starting to initialize home screen data...');
    final homeProvider = Provider.of<HomeProvider>(context, listen: false);
    try {
      await homeProvider.initializeHomeScreen();
      debugPrint('Home screen data initialized successfully');
    } catch (e) {
      debugPrint('Error initializing home screen data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading data. Please try again.')),
      );
    }
  }

  Future<void> _askForPincode() async {
    String? pincode = await showDialog<String>(
      context: context,
      builder: (context) {
        String enteredPincode = '';
        return AlertDialog(
          title: const Text('Enter Pincode'),
          content: TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Enter your pincode'),
            onChanged: (value) {
              enteredPincode = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(enteredPincode),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (pincode != null && pincode.isNotEmpty) {
      print('Pincode entered: $pincode'); // Debug log
      await _checkDeliveryAvailability(pincode: pincode);
    } else {
      print('No pincode entered'); // Debug log
    }
  }

  Future<void> _onRefresh() async {
    debugPrint('Refreshing home screen...');
    await _getUserLocation();

    final homeProvider = Provider.of<HomeProvider>(context, listen: false);
    await Future.wait([
      homeProvider.fetchBanners(),
      homeProvider.fetchCategories(),
      homeProvider.fetchNearbyRestaurants(),
      homeProvider.fetchTopRatedRestaurants(),
    ]);

    debugPrint('Banners: ${homeProvider.banners}');
    debugPrint('Categories: ${homeProvider.categories}');
    debugPrint('Nearby Restaurants: ${homeProvider.nearbyRestaurants}');
    debugPrint('Top-rated Restaurants: ${homeProvider.topRatedRestaurants}');
  }

  void _selectCategory(String category) {
    setState(() {
      if (category == 'All') {
        _selectedCategory = null;
      } else if (_selectedCategory == category) {
        _selectedCategory = null;
      } else {
        _selectedCategory = category;
      }
      debugPrint('Selected category: $_selectedCategory');
    });
  }

  // *** NEW: Function to conditionally show address sheet after build ***
  void _conditionallyShowAddressSheet() {
     // Check if data is loaded, no address is set, and sheet hasn't been shown yet
     final homeProvider = Provider.of<HomeProvider>(context, listen: false);
     if (!homeProvider.isLoading && globalCurrentAddress == null && !_addressSheetShownAfterLoad) {
       // Mark as shown immediately to prevent multiple triggers during rebuilds
       _addressSheetShownAfterLoad = true; 
       // Schedule the sheet to be shown after the current frame is built
       WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) { // Ensure widget is still in the tree
             _showAddressSelectionSheet(context); 
          }
       });
     }
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = Provider.of<HomeProvider>(context);
    final cartProvider = Provider.of<CartProvider>(context);

    // *** Call the function to check if sheet should be shown ***
    _conditionallyShowAddressSheet();

    final filteredPopularFood = _selectedCategory == null
        ? homeProvider.popularFoodItems
        : homeProvider.popularFoodItems
            .where((item) { 
                final itemCategory = item['category']?.toString()?.toLowerCase() ?? '';
                final itemCuisine = item['cuisine_type']?.toString()?.toLowerCase() ?? '';
                final selected = _selectedCategory!.toLowerCase();
                final match = itemCategory == selected || itemCuisine == selected;
                // Debug print to see values being compared
                // Remove this print once filtering works
                // debugPrint('Filtering item: ${item['name']} - Category: "$itemCategory", Cuisine: "$itemCuisine" | Selected: "$selected" | Match: $match'); 
                return match;
            })
            .toList();

    // Determine body based on loading, error, or delivery status
    Widget bodyContent;
    if (homeProvider.isLoading) {
      bodyContent = const Center(child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
      ));
    } else if (homeProvider.error != null) {
      bodyContent = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(homeProvider.error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeHomeScreenData, // Retry data fetch
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Retry Data'),
            ),
          ],
        ),
      );
    } else {
      // Show main content (potentially with a delivery unavailable message if needed)
      // The address display will show "Select Address" if globalCurrentAddress is null
      bodyContent = Container(
         decoration: BoxDecoration(
           gradient: LinearGradient(
             begin: Alignment.topCenter,
             end: Alignment.bottomCenter,
             colors: [
               Colors.orange.withOpacity(0.1),
               Colors.white,
             ],
           ),
         ),
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            color: Colors.orange,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display Current Address Section
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                     child: InkWell( // Make tappable
                       onTap: () => _showAddressSelectionSheet(context),
                       child: Row(
                         crossAxisAlignment: CrossAxisAlignment.center,
                         children: [
                           const Icon(Icons.location_on_outlined, color: Colors.orange, size: 20),
                           const SizedBox(width: 8),
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 const Text('Delivering To', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                 Text(
                                    // Combine address line 1 and city if available
                                    _formatDisplayAddress(globalCurrentAddress),
                                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                 ),
                               ],
                             ),
                           ),
                           const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                         ],
                       ),
                     ),
                   ),
                   const Divider(height: 1), // Separator
                 
                  // Optional: Show a non-blocking warning if delivery unavailable but location known
                  if (!_isDeliveryAvailable && !_locationPermissionDenied)
                     Padding(
                       padding: const EdgeInsets.all(8.0),
                       child: Card(
                         color: Colors.yellow.shade100,
                         child: const ListTile(
                            leading: Icon(Icons.warning_amber_rounded, color: Colors.orange),
                            title: Text('Delivery currently unavailable for your location.', style: TextStyle(fontSize: 14)),
                         ),
                       ),
                     ),
                 
                  // Banners Section
                  if (homeProvider.banners.isNotEmpty)
                    Container(
                      height: 150,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: homeProvider.banners.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                homeProvider.banners[index],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 280,
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: Icon(Icons.error_outline),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // Categories Section - Updated to GridView
                  if (homeProvider.categories.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8), 
                      child: Text(
                        'Categories',
                        style: TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                    // Use GridView for categories with images
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: GridView.builder(
                        shrinkWrap: true, // Important inside SingleChildScrollView
                        physics: const NeverScrollableScrollPhysics(), // Disable GridView's own scrolling
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4, // Adjust number of columns
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.85, // Adjust aspect ratio (width/height)
                        ),
                        itemCount: homeProvider.categories.length,
                        itemBuilder: (context, index) {
                          final category = homeProvider.categories[index];
                          final categoryName = category['name']?.toString() ?? 'N/A';
                          final imageUrl = category['image_url']?.toString() ?? '';
                          final isSelected = _selectedCategory == categoryName;

                          return GestureDetector(
                            onTap: () => _selectCategory(categoryName),
                            child: Card(
                              elevation: isSelected ? 4 : 1,
                              color: isSelected ? Colors.orange.shade50 : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isSelected ? Colors.orange : Colors.grey.shade300,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    flex: 3, // Give more space to image
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 6.0),
                                      child: _buildCategoryImage(imageUrl), // Image helper
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2, // Less space for text
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
                                      child: Text(
                                        categoryName,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 11, // Smaller font size
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected ? Colors.orange.shade800 : Colors.black87,
                                        ),
                                        maxLines: 2, // Allow text wrapping
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // Popular Food Items Section - Use filtered list
                  if (filteredPopularFood.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Text(
                        'Popular Food Items',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                    Container(
                      height: 190,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: filteredPopularFood.length,
                        itemBuilder: (context, index) {
                          final foodItem = filteredPopularFood[index];
                          // Wrap FoodCard with GestureDetector
                          return GestureDetector(
                             onTap: () => _showFoodDetailsDialog(context, foodItem),
                             child: FoodCard(food: foodItem),
                          );
                        },
                      ),
                    ),
                  ] else if (_selectedCategory != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                      child: Center(
                        child: Text(
                          'No popular items found for "$_selectedCategory".',
                          style: const TextStyle(color: Colors.grey, fontSize: 15),
                        ),
                      ),
                    ),
                  ],

                  // Nearby Restaurants Section
                  if (homeProvider.nearbyRestaurants.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Nearby Restaurants',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                    Container(
                      height: 180,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: homeProvider.nearbyRestaurants.length,
                        itemBuilder: (context, index) {
                          final restaurant = homeProvider.nearbyRestaurants[index];
                          return RestaurantCard(restaurant: restaurant);
                        },
                      ),
                    ),
                  ],

                  // Top-rated Restaurants Section
                  if (homeProvider.topRatedRestaurants.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Top-rated Restaurants',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                    Container(
                      height: 180,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: homeProvider.topRatedRestaurants.length,
                        itemBuilder: (context, index) {
                          final restaurant = homeProvider.topRatedRestaurants[index];
                          return RestaurantCard(restaurant: restaurant);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Delivery App'),
        backgroundColor: Colors.orange,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CartScreen()),
                  );
                },
              ),
              if (cartProvider.itemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      cartProvider.itemCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'My Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: bodyContent, // Use the determined body content
    );
  }

  // Helper function to format address for display
  String _formatDisplayAddress(Map<String, dynamic>? address) {
    if (address == null) return 'Select Address';
    
    final line1 = address['address_line1']?.toString() ?? '';
    final city = address['city']?.toString() ?? '';
    final state = address['state']?.toString() ?? '';
    
    // Improved formatting logic
    List<String> parts = [];
    if (line1.isNotEmpty) parts.add(line1);
    if (city.isNotEmpty) parts.add(city);
    if (state.isNotEmpty) parts.add(state);

    if (parts.isEmpty) {
       return 'Address Details Missing';
    } else {
       return parts.join(', '); // Join parts with comma and space
    }
  }

  // Helper method to show address selection bottom sheet
  void _showAddressSelectionSheet(BuildContext context) async {
    // State for location fetching
    bool isLocating = false;
    String? locationError;

    Future<void> _useCurrentLocation(StateSetter setSheetState) async {
      setSheetState(() {
        isLocating = true;
        locationError = null;
      });
      try {
        // 1. Get current position
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        // 2. Call reverse geocode API
        final response = await CustomerApiService.reverseGeocode(latitude: pos.latitude, longitude: pos.longitude);
        if (response.statusCode == 200 && response.body.isNotEmpty) {
          final data = jsonDecode(response.body);
          if (data != null && data is Map<String, dynamic>) {
            setState(() {
              globalCurrentAddress = data;
              saveCurrentAddressId(data['id']?.toString());
            });
            Navigator.of(context).pop(); // Close the sheet
            // Optionally, trigger delivery check
            _checkDeliveryAvailability(
              latitude: (data['latitude'] as num?)?.toDouble(),
              longitude: (data['longitude'] as num?)?.toDouble(),
              pincode: data['postal_code']?.toString(),
            );
            return;
          } else {
            locationError = 'Could not parse address.';
          }
        } else {
          locationError = 'Failed to get address from location.';
        }
      } on PermissionDeniedException {
        locationError = 'Location permission denied.';
      } on LocationServiceDisabledException {
        locationError = 'Location services are disabled.';
      } catch (e) {
        locationError = 'Error: ${e.toString()}';
      }
      setSheetState(() {
        isLocating = false;
      });
    }

     List<Map<String, dynamic>> savedAddresses = [];
     bool isLoading = true;
     String? fetchError;

     // --- Fetch addresses when the sheet is opened ---
     // Proactively refresh token before fetching addresses
     await AuthApi.refreshToken();
     if (globalCustomerId != null) {
       try {
          final dio = Dio();
          final url = '${AppConfig.baseUrl}/customer/$globalCustomerId/addresses/';
          debugPrint('(Sheet) Fetching addresses from: $url');
          try {
            final response = await dio.get(url);
            debugPrint('(Sheet) Saved Addresses Response (${response.statusCode}): ${response.data}');
            if (response.statusCode == 200 && response.data is List) {
              savedAddresses = List<Map<String, dynamic>>.from(
                (response.data as List).where((item) => item is Map).map((item) => Map<String, dynamic>.from(item))
              );
              debugPrint('(Sheet) Parsed savedAddresses: $savedAddresses');
              // --- Auto-select default address if none selected ---
              if (globalCurrentAddress == null && savedAddresses.isNotEmpty) {
                Map<String, dynamic>? defaultAddr = savedAddresses.firstWhere(
                  (addr) => addr['is_default'] == true,
                  orElse: () => savedAddresses.first,
                );
                debugPrint('(Sheet) Setting globalCurrentAddress to: $defaultAddr');
                globalCurrentAddress = defaultAddr;
                saveCurrentAddressId(defaultAddr['id']?.toString());
              }
            } else {
              fetchError = 'Failed to load addresses. Status: ${response.statusCode}';
            }
          } on DioException catch (e) {
            fetchError = 'Error loading addresses: ${e.response?.data?['detail'] ?? e.message}';
            debugPrint('(Sheet) DioError fetching saved addresses: $e');
          } catch (e) {
            fetchError = 'Could not load addresses.';
            debugPrint('(Sheet) Fetch error: $e');
          }
       } catch (e) {
           fetchError = 'Could not load addresses.';
           debugPrint('(Sheet) Fetch error: $e');
       }
     } else {
        fetchError = 'Not logged in.';
     }
     isLoading = false;
     // --- End fetch ---

     // Use a stateful builder to handle async loading within the sheet
     showModalBottomSheet(
        context: context,
        isScrollControlled: true, // Allows sheet to take more height if needed
        shape: const RoundedRectangleBorder(
           borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) {
           // Use StatefulBuilder to manage loading/error state within the sheet
           return StatefulBuilder(
              builder: (BuildContext context, StateSetter setSheetState) {
                 // Function to refresh addresses within the sheet (e.g., after adding)
                 Future<void> refreshAddresses() async {
                      setSheetState(() { isLoading = true; fetchError = null; });
                      // Re-run fetch logic
                       if (globalCustomerId != null) {
                         try {
                            final dio = Dio();
                            final url = '${AppConfig.baseUrl}/customer/$globalCustomerId/addresses/';
                            try {
                              final response = await dio.get(url);
                              debugPrint('(Sheet) Saved Addresses Response (${response.statusCode}): ${response.data}');
                              if (response.statusCode == 200 && response.data is List) {
                                savedAddresses = List<Map<String, dynamic>>.from(
                                  (response.data as List).where((item) => item is Map).map((item) => Map<String, dynamic>.from(item))
                                );
                                debugPrint('(Sheet) Parsed savedAddresses: $savedAddresses');
                              } else {
                                fetchError = 'Failed to load addresses. Status: ${response.statusCode}';
                              }
                            } on DioException catch (e) {
                              fetchError = 'Error loading addresses: ${e.response?.data?['detail'] ?? e.message}';
                              debugPrint('(Sheet) DioError fetching saved addresses: $e');
                            } catch (e) {
                              fetchError = 'An unexpected error occurred loading addresses.';
                              debugPrint('(Sheet) Error fetching saved addresses: $e');
                            }
                         } catch (e) {
                            fetchError = 'Could not load addresses.';
                            debugPrint('(Sheet) Fetch error: $e');
                         }
                       } else {
                          fetchError = 'Not logged in.';
                       }
                       isLoading = false;
                       // Crucially update the sheet's state
                       setSheetState(() {}); 
                 }

                 // Function to navigate to add screen and refresh on return
                 void goToAddAddress() async {
                    Navigator.pop(sheetContext); // Close sheet first
                    final result = await Navigator.push(
                       context, 
                       MaterialPageRoute(builder: (context) => const AddEditAddressScreen())
                    );
                    if (result == true) { // If address was added
                       // Re-show the sheet and refresh its content (or just refresh HomeScreen)
                       // Option 1: Just refresh HomeScreen (simpler)
                       // setState((){}); // Trigger HomeScreen rebuild to show new address potentially
                       // Option 2: Re-show sheet with updated data (better UX)
                       _showAddressSelectionSheet(context);
                    }
                 }

                 // Function to show pincode dialog and check delivery
                 void checkDeliveryWithPincode() async {
                    Navigator.pop(sheetContext); // Close sheet first
                    await _askForPincode(); // Reuse existing pincode dialog logic
                 }

                 // --- Use Current Location Button ---
                 final Widget useLocationButton = Padding(
                   padding: const EdgeInsets.symmetric(vertical: 8.0),
                   child: OutlinedButton.icon(
                     icon: const Icon(Icons.my_location, size: 20, color: Colors.orange),
                     label: isLocating
                         ? const SizedBox(
                             width: 18,
                             height: 18,
                             child: CircularProgressIndicator(
                               strokeWidth: 2,
                               valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                             ),
                           )
                         : const Text('Use Current Location', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                     style: OutlinedButton.styleFrom(
                       foregroundColor: Colors.orange,
                       side: BorderSide(color: Colors.orange.shade200, width: 1.5),
                       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                       backgroundColor: Colors.white,
                     ),
                     onPressed: isLocating ? null : () => _useCurrentLocation(setSheetState),
                   ),
                 );

                 // <<<--- ADD DEBUG PRINT HERE --->>
                 debugPrint('(Sheet Builder) isLoading: $isLoading, fetchError: $fetchError, savedAddresses count: ${savedAddresses.length}');
                 final bool shouldShowList = !isLoading && fetchError == null && savedAddresses.isNotEmpty;
                 debugPrint('(Sheet Builder) Condition to show list (shouldShowList): $shouldShowList');
                 // <<<--- END DEBUG PRINT --->>

                 return Padding(
                     padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), // Adjust for keyboard
                     child: Container(
                       padding: const EdgeInsets.all(16),
                       child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // --- Use Current Location Button ---
                            useLocationButton,
                            if (locationError != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  locationError!,
                                  style: const TextStyle(color: Colors.red, fontSize: 13),
                                ),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Select Delivery Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(sheetContext)),
                              ],
                            ),
                            const Divider(height: 20),
                            if (isLoading)
                               const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())),
                            if (!isLoading && fetchError != null)
                                Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 20.0), child: Text(fetchError!, style: TextStyle(color: Colors.red)))),
                            if (!isLoading && fetchError == null && savedAddresses.isEmpty) ...[
                               const SizedBox(height: 10),
                               Center(
                                  child: OutlinedButton.icon(
                                     icon: const Icon(Icons.pin_drop_outlined, size: 16),
                                     label: const Text('Check Delivery via Pincode'),
                                     onPressed: checkDeliveryWithPincode,
                                     style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.orange,
                                        side: BorderSide(color: Colors.orange.shade200),
                                     ),
                                  ),
                               ),
                            ],
                            // Use the debugged condition here
                            if (shouldShowList) // <<<--- Use the boolean variable
                               LimitedBox(
                                  maxHeight: MediaQuery.of(context).size.height * 0.35, // Increased height slightly
                                  child: ListView.builder(
                                     shrinkWrap: true,
                                     itemCount: savedAddresses.length,
                                     itemBuilder: (listContext, index) {
                                        final address = savedAddresses[index];
                                        final bool isCurrent = globalCurrentAddress?['id'] == address['id'];

                                        // Log all keys for debugging
                                        debugPrint('(Sheet ListTile Builder) Address keys: ${address.keys}');
                                        // Try possible variants for address line 1
                                        String addressLine1 = address['address_line_1']?.toString() ?? address['line1']?.toString() ?? address['address1']?.toString() ?? '';
                                        debugPrint('(Sheet ListTile Builder) Index: $index, Address ID: ${address['id']}, value for title: "$addressLine1", isEmpty: ${addressLine1.isEmpty}');

                                        return ListTile(
                                           leading: Icon(
                                              isCurrent ? Icons.check_circle : Icons.radio_button_unchecked,
                                              color: isCurrent ? Colors.orange : Colors.grey,
                                              size: 22,
                                           ),
                                           // Use the safe addressLine1 and provide placeholder if empty
                                           title: Text(addressLine1.isNotEmpty ? addressLine1 : '(No Address Line 1)'),
                                           subtitle: Text('${address['city'] ?? ''}, ${address['state'] ?? ''} ${address['postal_code'] ?? ''}'),
                                           onTap: () {
                                              // Set the global address
                                              final selectedAddress = Map<String, dynamic>.from(address); // Create copy
                                              setState(() { // Update HomeScreen's state
                                                 globalCurrentAddress = selectedAddress;
                                                 saveCurrentAddressId(selectedAddress['id']?.toString()); // Save preference
                                              });
                                              Navigator.pop(sheetContext); // Close the sheet
                                              // Trigger delivery check with the NEWLY selected address details
                                              _checkDeliveryAvailability(
                                                  latitude: (selectedAddress['latitude'] as num?)?.toDouble(),
                                                  longitude: (selectedAddress['longitude'] as num?)?.toDouble(),
                                                  pincode: selectedAddress['postal_code']?.toString()
                                              );
                                           },
                                        );
                                     },
                                  ),
                               ),
                            const Divider(height: 20),
                            Row(
                               mainAxisAlignment: MainAxisAlignment.center,
                               children: [
                                 TextButton.icon(
                                   icon: const Icon(Icons.add_circle_outline, size: 16),
                                   label: const Text('Add New Address'),
                                   onPressed: goToAddAddress,
                                 ),
                                 const SizedBox(width: 10),
                                 TextButton.icon(
                                    icon: const Icon(Icons.settings_outlined, size: 16),
                                    label: const Text('Manage All'),
                                    onPressed: () {
                                       Navigator.pop(sheetContext); // Close sheet first
                                       Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
                                    },
                                 ),
                               ],
                            ),
                            // --- Option to Check Pincode (alternative place) ---
                           if (!isLoading && fetchError == null) ...[
                              const SizedBox(height: 10),
                              Center(
                                child: TextButton.icon(
                                  icon: const Icon(Icons.pin_drop_outlined, size: 16),
                                  label: const Text('Or Check Delivery via Pincode'),
                                  onPressed: checkDeliveryWithPincode,
                                  style: TextButton.styleFrom(foregroundColor: Colors.orange.shade700)
                                ),
                              ),
                           ],
                         ],
                      ),
                    ),
                 );
              },
           );
        },
     );
  }

  // Helper method to build category image widgets
  Widget _buildCategoryImage(String imageUrl) {
    // Use similar logic as _buildCartItemImage or FoodCard._buildImage
    Uri? uri = Uri.tryParse(imageUrl);
    bool isNetworkUrl = uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    bool isLocalAsset = imageUrl.startsWith('assets/');

    // Handle relative paths from server
    if (!isNetworkUrl && !isLocalAsset && imageUrl.startsWith('/')) {
      imageUrl = '${AppConfig.baseUrl}$imageUrl';
      uri = Uri.tryParse(imageUrl);
      isNetworkUrl = uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    }

    Widget placeholder = Icon(Icons.category_outlined, size: 30, color: Colors.grey.shade400);

    if (imageUrl.isEmpty || (!isNetworkUrl && !isLocalAsset)) {
      return placeholder;
    }

    if (isNetworkUrl) {
      return Image.network(
        imageUrl,
        fit: BoxFit.contain, // Contain might be better than cover here
        errorBuilder: (context, error, stackTrace) => placeholder,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          // Simple progress indicator
          return Center(child: CircularProgressIndicator(value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null, strokeWidth: 2));
        },
      );
    } else { // isLocalAsset
      return Image.asset(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    }
  }

  // --- Copied Helper Method to Show Food Details Dialog --- (From MenuScreen)
  void _showFoodDetailsDialog(BuildContext context, Map<String, dynamic> foodItem) {
    final imageUrl = foodItem['image']?.toString() ?? '';
    final description = foodItem['description']?.toString() ?? 'No description available.';
    final rating = (foodItem['rating'] as num?)?.toDouble(); // Can be null
    final priceValue = foodItem['price'];
    final price = priceValue?.toString() ?? ''; // Get price for display

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: EdgeInsets.zero, // Remove default padding
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image Header
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  child: _buildDialogImage(imageUrl), // Use helper
                ),
              ),
              // Details Padding
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(foodItem['name'] ?? 'Food Item', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    // Display Price
                    if (price.isNotEmpty) 
                       Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text('₹$price', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                       ),
                    // Display Rating
                    if (rating != null)
                       Padding(
                         padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                         child: Row(
                            children: [
                               Icon(Icons.star, color: Colors.amber.shade700, size: 16),
                               const SizedBox(width: 4),
                               Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w500)),
                            ],
                         ),
                       ),
                    const SizedBox(height: 8),
                    Text(description, style: const TextStyle(fontSize: 14, color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          // Add to Cart button in dialog
          ElevatedButton.icon(
             icon: const Icon(Icons.add_shopping_cart, size: 16),
             label: const Text('Add to Cart'),
             style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
             onPressed: () {
               // Ensure item has necessary info before adding
               if (foodItem['id'] != null && priceValue != null) {
                   final cartItem = Map<String, dynamic>.from(foodItem);
                   cartItem['price'] = (priceValue is num) ? priceValue : (double.tryParse(price) ?? 0.0);
                   Provider.of<CartProvider>(context, listen: false).addToCart(cartItem);
                   Navigator.of(ctx).pop(); // Close dialog
                   ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added "${cartItem['name'] ?? 'Item'}" to cart!'), duration: Duration(seconds: 1))
                   );
               } else {
                  Navigator.of(ctx).pop(); // Close dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not add item: Missing details.'), duration: Duration(seconds: 2), backgroundColor: Colors.red)
                  );
               }
             },
          )
        ],
      ),
    );
  }

  // --- Copied Helper to build image for the dialog --- (From MenuScreen)
   Widget _buildDialogImage(String imageUrl) {
    Uri? uri = Uri.tryParse(imageUrl);
    bool isNetworkUrl = uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    bool isLocalAsset = imageUrl.startsWith('assets/');

    if (!isNetworkUrl && !isLocalAsset && imageUrl.startsWith('/')) {
      imageUrl = '${AppConfig.baseUrl}$imageUrl';
      uri = Uri.tryParse(imageUrl);
      isNetworkUrl = uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    }

    Widget placeholder = const FittedBox(
      fit: BoxFit.contain,
      child: Icon(Icons.fastfood, size: 60, color: Colors.grey),
    );

    if (imageUrl.isEmpty || (!isNetworkUrl && !isLocalAsset)) {
      return placeholder;
    }

    if (isNetworkUrl) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        },
      );
    } else { // isLocalAsset
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    }
  }

  Future<void> _checkAuthenticationStatus() async {
    if (mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final isAuthenticated = await authProvider.isAuthenticated();
      
      if (!isAuthenticated) {
        // Try to load customer ID from storage again
        final customerId = await AuthStorage.getCustomerId();
        if (customerId != null && customerId.isNotEmpty) {
          globalCustomerId = customerId;
          // Also make sure we have a token
          final token = await AuthStorage.getToken();
          if (token == null || token.isEmpty) {
            _redirectToLogin();
          }
        } else {
          _redirectToLogin();
        }
      }
    }
  }
}

class RestaurantCard extends StatelessWidget {
  final Map<String, dynamic> restaurant;

  const RestaurantCard({Key? key, required this.restaurant}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    debugPrint('Restaurant Data in Card: $restaurant');
    
    final name = restaurant['name'] ?? 'Unknown Restaurant';
    final rating = (restaurant['rating'] ?? 0.0).toDouble();
    final cuisineType = restaurant['cuisine_type'] ?? 'Various Cuisines';
    final imageUrl = restaurant['image'] ?? '';
    
    // Match the pattern from SearchResult - use vendor_id if available, fallback to id
    final vendorId = restaurant['vendor_id']?.toString() ?? restaurant['id']?.toString() ?? '';
    
    debugPrint('Building RestaurantCard - vendorId: $vendorId');

    return GestureDetector(
      onTap: () {
        if (vendorId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Restaurant ID not found')),
          );
          return;
        }

        debugPrint('Navigating to restaurant-detail with vendorId: $vendorId');
        Navigator.pushNamed(
          context,
          '/restaurant-detail',
          arguments: {
            'vendor_id': vendorId,
          },
        );
      },
      child: SizedBox(
        width: 160,
        height: 180,
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: SizedBox(
                  height: 100,
                  width: double.infinity,
                  child: _buildImage(imageUrl, name),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cuisineType,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 14,
                            color: rating > 0 ? Colors.amber[700] : Colors.grey[400],
                          ),
                          const SizedBox(width: 2),
                          Text(
                            rating > 0 ? rating.toStringAsFixed(1) : 'New',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                              color: rating > 0 ? Colors.black87 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // *** REPLACE THIS METHOD ***
  Widget _buildImage(String imageUrl, String name) {
    Uri? uri = Uri.tryParse(imageUrl);
    bool isNetworkUrl = uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    bool isLocalAsset = imageUrl.startsWith('assets/');

    // Handle relative paths from server (if applicable)
    if (!isNetworkUrl && !isLocalAsset && imageUrl.startsWith('/')) {
      imageUrl = '${AppConfig.baseUrl}$imageUrl'; // Assuming AppConfig is available or adjust as needed
      uri = Uri.tryParse(imageUrl);
      isNetworkUrl = uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
      debugPrint('(RestaurantCard) Corrected relative image URL to: $imageUrl');
    }

    if (imageUrl.isEmpty || (!isNetworkUrl && !isLocalAsset)) {
      if (imageUrl.isNotEmpty) {
        debugPrint('(RestaurantCard) Invalid or unhandled image URL format: $imageUrl');
      }
      return _buildPlaceholderImage(name);
    }

    if (isNetworkUrl) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
           if (loadingProgress == null) return child;
           return Center(child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
           ));
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('(RestaurantCard) Error loading network image "$imageUrl": $error');
          return _buildPlaceholderImage(name);
        },
      );
    } else { // isLocalAsset
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('(RestaurantCard) Error loading asset image "$imageUrl": $error');
          return _buildPlaceholderImage(name);
        },
      );
    }
  }

  Widget _buildPlaceholderImage(String name) {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant, size: 32, color: Colors.grey[400]),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                name,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FoodCard extends StatelessWidget {
  final Map<String, dynamic> food;

  const FoodCard({Key? key, required this.food}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Ensure data types and handle nulls gracefully
    final name = food['name']?.toString() ?? 'Unknown Food';
    final priceValue = food['price'];
    final price = priceValue?.toString() ?? '0.00';
    final rating = (food['rating'] as num?)?.toDouble() ?? 0.0;
    // *** START CHANGE ***
    // Prioritize the first URL from image_urls if available
    final imageList = food['image_urls'] as List?;
    String imageUrl = '';
    if (imageList != null && imageList.isNotEmpty && imageList[0] is String) {
       imageUrl = imageList[0] as String;
    } else {
       // Fallback to the 'image' field if 'image_urls' is missing or empty
       imageUrl = food['image']?.toString() ?? '';
    }
    // *** END CHANGE ***
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    debugPrint('FoodCard data: $food'); // Log data for debugging nulls
    debugPrint('FoodCard using image URL: $imageUrl'); // Log the URL being used

    return SizedBox(
      width: 140,
      height: 180,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 80,
              width: double.infinity,
              child: _buildImage(imageUrl, name), // Pass the potentially updated imageUrl
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '₹$price',
                      style: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.bold, fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Icon(Icons.star, size: 12, color: rating > 0 ? Colors.amber[700] : Colors.grey[400]),
                        const SizedBox(width: 2),
                        Text(
                          rating > 0 ? rating.toStringAsFixed(1) : 'New',
                          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 10, color: rating > 0 ? Colors.black87 : Colors.grey[600]),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 24,
                      child: ElevatedButton(
                        onPressed: () {
                          if (food['id'] != null && name != 'Unknown Food' && priceValue != null) {
                             final cartItem = Map<String, dynamic>.from(food);
                             cartItem['price'] = (priceValue is num) ? priceValue : (double.tryParse(price) ?? 0.0);

                             cartProvider.addToCart(cartItem);
                             ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added "$name" to cart'),
                                  duration: const Duration(seconds: 1),
                                  backgroundColor: Colors.green[700],
                                ),
                             );
                          } else {
                             debugPrint('Cannot add item to cart: Missing details - $food');
                             ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cannot add item: Missing details'),
                                  duration: Duration(seconds: 2),
                                  backgroundColor: Colors.red,
                                ),
                             );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: EdgeInsets.zero,
                          textStyle: const TextStyle(fontSize: 11),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Add to Cart'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String imageUrl, String name) {
    Uri? uri = Uri.tryParse(imageUrl);
    bool isNetworkUrl = uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    bool isLocalAsset = imageUrl.startsWith('assets/');

    if (!isNetworkUrl && !isLocalAsset && imageUrl.startsWith('/')) {
      imageUrl = '${AppConfig.baseUrl}$imageUrl';
      uri = Uri.tryParse(imageUrl);
      isNetworkUrl = uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
      debugPrint('Corrected relative image URL to: $imageUrl');
    }

    if (imageUrl.isEmpty || (!isNetworkUrl && !isLocalAsset)) {
      if (imageUrl.isNotEmpty) {
        debugPrint('Invalid or unhandled image URL format: $imageUrl');
      }
      return _buildPlaceholderImage(name);
    }

    if (isNetworkUrl) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
           if (loadingProgress == null) return child;
           return Center(child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
           ));
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading network image "$imageUrl": $error');
          return _buildPlaceholderImage(name);
        },
      );
    } else {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading asset image "$imageUrl": $error');
          return _buildPlaceholderImage(name);
        },
      );
    }
  }

  Widget _buildPlaceholderImage(String name) {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fastfood, size: 24, color: Colors.orange[300]),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                name,
                style: TextStyle(color: Colors.grey[600], fontSize: 10),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RestaurantSearchDelegate extends SearchDelegate {
  final HomeProvider homeProvider;

  RestaurantSearchDelegate(this.homeProvider);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = homeProvider.searchRestaurants(query) ?? [];
    return results.isEmpty
        ? const Center(child: Text('No results found'))
        : ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(results[index]['name'] ?? 'Unknown'),
                subtitle: Text(results[index]['description'] ?? 'No description available'),
              );
            },
          );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return const Center(child: Text('Search for restaurants'));
  }
}
