import 'package:flutter/material.dart';
// Purpose: Provides the main home screen UI, including banners, categories, restaurants, and address selection.

import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import '../providers/home_provider.dart';
import '../utils/globals.dart';
import '../config.dart';
import './search_screen.dart';
import '../providers/cart_provider.dart';
import './cart_screen.dart';
import './profile_screen.dart';
import '../providers/home_provider.dart';
import './add_edit_address_screen.dart';
import './orders_screen.dart';
import './wallet_screen.dart';
import './promotions_screen.dart';
import './notifications_screen.dart';
import '../utils/auth_storage.dart'; 
import '../utils/auth_api.dart'; 
import '../providers/auth_provider.dart';
import './login_screen.dart';
import 'package:food_ordering_app/services/customer_api_service.dart';
import 'dart:convert';
import '../widgets/app_scaffold.dart';
import '../widgets/order_status_banner.dart';
// --- HomeScreen and _HomeScreenState implementation restored below ---

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Position? _currentPosition;
  bool _isDeliveryAvailable = false;
  bool _locationPermissionDenied = false;
  String? _selectedCategory;
  bool _addressSheetShownAfterLoad = false; // Flag to show sheet only once
  String? _authToken;

  @override
  void initState() {
    super.initState();
    _startupAuthAndLocation();
  }

  // Combined startup logic for auth and location
  Future<void> _startupAuthAndLocation() async {
    await _checkAuthToken(); // Always set _authToken
    await _verifyAuthentication();
    if (mounted && _authToken != null) {
      await _initializeHomeScreenData(); // Load main content first
      _fetchAndSetAddress(); // Fetch address in the background
    }
  }

  // Fetch address in the background, update UI when ready
  Future<void> _fetchAndSetAddress() async {
    setState(() { _isFetchingAddress = true; });
    try {
      if (_useCurrentLocation) {
        await _getUserLocationAndReverseGeocode();
      } else if (globalCurrentAddress != null && globalCurrentAddress!['latitude'] != null && globalCurrentAddress!['longitude'] != null) {
        await _reverseGeocodeAndSet(globalCurrentAddress!['latitude'], globalCurrentAddress!['longitude']);
      }
    } finally {
      if (mounted) setState(() { _isFetchingAddress = false; });
    }
  }

  // Helper to get user location and reverse geocode
  Future<void> _getUserLocationAndReverseGeocode() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      await _reverseGeocodeAndSet(pos.latitude, pos.longitude);
    } catch (e) {
      debugPrint('Error getting user location: $e');
    }
  }

  // Reverse geocode and update globalCurrentAddress
  Future<void> _reverseGeocodeAndSet(double lat, double lon) async {
    try {
      final dio = Dio();
      final token = await AuthStorage.getAccessToken();
      final options = Options(headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });
      final response = await AuthApi.authenticatedRequest(() => dio.post(
        AppConfig.baseUrl + '/reverse-geocode/',
        data: {
          'latitude': lat,
          'longitude': lon,
        },
        options: options,
      ));
      if (response != null && response.statusCode == 200 && response.data != null) {
        setState(() {
          globalCurrentAddress = response.data;
        });
      }
    } catch (e) {
      debugPrint('Reverse geocode API error: $e');
    }
  }

  // Call this when user selects an address (not current location)
  Future<void> onAddressSelected(Map<String, dynamic> address) async {
    setState(() {
      globalCurrentAddress = address;
      _useCurrentLocation = false;
      _selectedPincode = null;
      _isFetchingAddress = true;
    });
    if (address['latitude'] != null && address['longitude'] != null) {
      await _reverseGeocodeAndSet(address['latitude'], address['longitude']);
    }
    setState(() { _isFetchingAddress = false; });
    await _checkDeliveryAvailability(
      latitude: (address['latitude'] as num?)?.toDouble(),
      longitude: (address['longitude'] as num?)?.toDouble(),
      pincode: address['postal_code']?.toString(),
    );
    await _initializeHomeScreenData();
  }

  // Call this when user selects "Use Current Location"
  Future<void> onUseCurrentLocation() async {
    setState(() {
      _useCurrentLocation = true;
      globalCurrentAddress = null;
      _selectedPincode = null;
      _isFetchingAddress = true;
    });
    await _getUserLocationAndReverseGeocode();
    setState(() { _isFetchingAddress = false; });
    await _checkDeliveryAvailability();
    await _initializeHomeScreenData();
  }

  bool _isFetchingAddress = false;

  Future<void> _checkAuthToken() async {
    final token = await AuthStorage.getAccessToken();
    debugPrint('(HomeScreen) Retrieved auth_token: ${token != null ? "exists" : "not found"}');
    if (token != null) {
      debugPrint('(HomeScreen) Token length: ${token.length}');
      debugPrint('(HomeScreen) Token begins with: ${token.substring(0, token.length > 10 ? 10 : token.length)}...');
    }
    setState(() {
      _authToken = token;
    });
  }

  // Verify authentication status and redirect to login if needed
  Future<void> _verifyAuthentication() async {
    if (mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await AuthStorage.getAccessToken();
      
      if (token == null) {
        debugPrint('(HomeScreen) No auth token found, redirecting to login');
        _redirectToLogin('Please log in to continue');
        return;
      }

      try {
        final isAuthenticated = await authProvider.isAuthenticated();
        
        if (!isAuthenticated && mounted) {
          debugPrint('(HomeScreen) Token validation failed, redirecting to login');
          _redirectToLogin('Your session has expired. Please log in again.');
          return;
        }
        
        debugPrint('(HomeScreen) User is authenticated, continuing');
      } catch (e) {
        debugPrint('(HomeScreen) Error verifying authentication: $e');
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
    setState(() { _locationPermissionDenied = false; });
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location service disabled.');
      setState(() { _locationPermissionDenied = true; });
      await _checkDeliveryAvailability();
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permission denied.');
        setState(() { _locationPermissionDenied = true; });
        await _checkDeliveryAvailability();
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permission denied forever.');
      setState(() { _locationPermissionDenied = true; });
      await _checkDeliveryAvailability();
      return;
    }
    debugPrint('Location permission granted.');
    try {
      _currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      debugPrint('Current position obtained: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
      try {
        final dio = Dio();
        final token = await AuthStorage.getAccessToken();
        final options = Options(headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        });
        final response = await AuthApi.authenticatedRequest(() => dio.post(
          AppConfig.baseUrl + '/reverse-geocode/',
          data: {
            'latitude': _currentPosition?.latitude,
            'longitude': _currentPosition?.longitude,
          },
          options: options,
        ));
        if (response != null && response.statusCode == 200 && response.data != null) {
          debugPrint('Reverse geocode API response: ${response.data}');
          setState(() {
            globalCurrentAddress = response.data;
            _useCurrentLocation = true;
            _selectedPincode = null;
          });
          await _initializeHomeScreenData(); // <-- Fetch home data for new address
        } else {
          debugPrint('Reverse geocode API failed with status: ${response?.statusCode}');
          setState(() {
            globalCurrentAddress = null;
            _useCurrentLocation = true;
            _selectedPincode = null;
          });
        }
      } catch (e) {
        debugPrint('Reverse geocode API error: $e');
        setState(() {
          globalCurrentAddress = null;
          _useCurrentLocation = true;
          _selectedPincode = null;
        });
      }
      await _checkDeliveryAvailability(
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
      );
    } catch (e) {
      debugPrint('Error getting current position: $e');
      setState(() { _locationPermissionDenied = true; });
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

      final bool available = response.data?['delivery_available'] ?? false;
      
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
    final homeProvider = Provider.of<HomeProvider>(context, listen: false);
    if (!homeProvider.isLoading && globalCurrentAddress == null && !_addressSheetShownAfterLoad) {
      _addressSheetShownAfterLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
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
                                 _isFetchingAddress
  ? Row(children: [SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text('Fetching address...', style: TextStyle(fontSize: 13, color: Colors.grey))])
  : Text(
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
                                  ),
                                ),
                              },
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: filteredPopularFood.length,
                        itemBuilder: (context, index) {
                          final foodItem = filteredPopularFood[index];
                          return GestureDetector(
                            onTap: () => _showFoodDetailsDialog(context, foodItem),
                            child: FoodCard(food: foodItem),
                          );
                        },
                      ),
                    )
                  else if (_selectedCategory != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                      child: Center(
                        child: Text(
                          'No popular items found for "$_selectedCategory".',
                          style: const TextStyle(color: Colors.grey, fontSize: 15),
                        ),
                      ),
                    ),

                  // Popular Food Items Section - Modern, robust, with empty/loading handling
                   Padding(
                     padding: const EdgeInsets.only(top: 8.0),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Padding(
                           padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                           child: Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               const Text(
                                 'Popular Foods',
                                 style: TextStyle(
                                   fontSize: 20,
                                   fontWeight: FontWeight.bold,
                                   color: Colors.orange,
                                 ),
                               ),
                               if (_selectedCategory != null)
                                 Text(
                                   'Filtered by: $_selectedCategory',
                                   style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
                                 ),
                             ],
                           ),
                         ),
                         if (homeProvider.isLoading)
                           const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.orange))),
                         if (!homeProvider.isLoading && filteredPopularFood.isEmpty)
                           Padding(
                             padding: const EdgeInsets.symmetric(vertical: 18.0),
                             child: Center(
                               child: Text(
                                 _selectedCategory != null
                                     ? 'No popular items found for "$_selectedCategory".'
                                     : 'No popular food items available',
                                 style: const TextStyle(color: Colors.grey, fontSize: 15),
                               ),
                             ),
                           ),
                         if (filteredPopularFood.isNotEmpty)
                           SizedBox(
                             height: 190,
                             child: ListView.builder(
                               scrollDirection: Axis.horizontal,
                               padding: const EdgeInsets.symmetric(horizontal: 12),
                               itemCount: filteredPopularFood.length,
                               itemBuilder: (context, index) {
                                 final foodItem = filteredPopularFood[index];
                                 return GestureDetector(
                                   onTap: () => _showFoodDetailsDialog(context, foodItem),
                                   child: FoodCard(food: foodItem),
                                 );
                               },
                             ),
                           ),
                       ],
                     ),
                   ),

                  // Nearby Restaurants Section - Modern, robust, with empty/loading handling
                   Padding(
                     padding: const EdgeInsets.only(top: 8.0),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Padding(
                           padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                           child: Text(
                             'Nearby Restaurants',
                             style: TextStyle(
                               fontSize: 20,
                               fontWeight: FontWeight.bold,
                               color: Colors.orange,
                             ),
                           ),
                         ),
                         if (homeProvider.isLoading)
                           const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.orange))),
                         if (!homeProvider.isLoading && homeProvider.nearbyRestaurants.isEmpty)
                           const Center(
                             child: Padding(
                               padding: EdgeInsets.symmetric(vertical: 18.0),
                               child: Text('No nearby restaurants found', style: TextStyle(color: Colors.grey, fontSize: 15)),
                             ),
                           ),
                         if (homeProvider.nearbyRestaurants.isNotEmpty)
                           SizedBox(
                             height: 180,
                             child: ListView.builder(
                               scrollDirection: Axis.horizontal,
                               padding: const EdgeInsets.symmetric(horizontal: 12),
                               itemCount: homeProvider.nearbyRestaurants.length,
                               itemBuilder: (context, index) {
                                 final restaurant = homeProvider.nearbyRestaurants[index];
                                 return RestaurantCard(restaurant: restaurant);
                               },
                             ),
                           ),
                       ],
                     ),
                   ),
                  // Top Rated Restaurants Section - Modern, robust, with empty/loading handling
                   Padding(
                     padding: const EdgeInsets.only(top: 8.0),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Padding(
                           padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                           child: Text(
                             'Top Rated Restaurants',
                             style: TextStyle(
                               fontSize: 20,
                               fontWeight: FontWeight.bold,
                               color: Colors.orange,
                             ),
                           ),
                         ),
                         if (homeProvider.isLoading)
                           const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.orange))),
                         if (!homeProvider.isLoading && homeProvider.topRatedRestaurants.isEmpty)
                           const Center(
                             child: Padding(
                               padding: EdgeInsets.symmetric(vertical: 18.0),
                               child: Text('No top rated restaurants found', style: TextStyle(color: Colors.grey, fontSize: 15)),
                             ),
                           ),
                         if (homeProvider.topRatedRestaurants.isNotEmpty)
                           SizedBox(
                             height: 180,
                             child: ListView.builder(
                               scrollDirection: Axis.horizontal,
                               padding: const EdgeInsets.symmetric(horizontal: 12),
                               itemCount: homeProvider.topRatedRestaurants.length,
                               itemBuilder: (context, index) {
                                 final restaurant = homeProvider.topRatedRestaurants[index];
                                 return RestaurantCard(restaurant: restaurant);
                               },
                             ),
                           ),
                       ],
                     ),
                   ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

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
  // Show current location if selected
  if (_useCurrentLocation && _currentPosition != null) {
    String lat = _currentPosition!.latitude.toStringAsFixed(5);
    String lon = _currentPosition!.longitude.toStringAsFixed(5);
    // Optionally, you could reverse geocode for a human-readable address
    return 'Current Location ($lat, $lon)';
  }
  // Show pincode if set and no address
  if (_selectedPincode != null && _selectedPincode!.isNotEmpty) {
    return 'Pincode: $_selectedPincode';
  }
  if (address == null) return 'Select Address';
  final line1 = address['address_line1']?.toString() ?? '';
  final city = address['city']?.toString() ?? '';
  final state = address['state']?.toString() ?? '';
  List<String> parts = [];
  if (line1.isNotEmpty) parts.add(line1);
  if (city.isNotEmpty) parts.add(city);
  if (state.isNotEmpty) parts.add(state);
  if (parts.isEmpty) {
    return 'Address Details Missing';
  } else {
    return parts.join(', ');
  }
}


  // Helper method to show address selection bottom sheet
  // Track if user wants to use current location
bool _useCurrentLocation = false;
String? _selectedPincode; // Track last entered pincode

void _showAddressSelectionSheet(BuildContext context) async {
     List<Map<String, dynamic>> savedAddresses = [];
     bool isLoading = true;
     String? fetchError;

     // --- Fetch addresses when the sheet is opened ---
      if (globalCustomerId != null) {
        try {
          final dio = Dio();
          final url = '${AppConfig.baseUrl}/customer/$globalCustomerId/addresses/';
          debugPrint('(Sheet) Fetching addresses from: $url');
          final response = await AuthApi.authenticatedRequest(() => dio.get(
            url,
            options: Options(headers: {
              'Content-Type': 'application/json',
            }),
          ));
          debugPrint('(Sheet) Raw Response Data: ${response?.data}');
          if (response != null && response.statusCode == 200 && response.data != null) {
            debugPrint('(Sheet) Data before parsing: ${response.data}');
            savedAddresses = List<Map<String, dynamic>>.from(
              (response.data as List).where((item) => item is Map).map((item) => Map<String, dynamic>.from(item))
            );
            debugPrint('(Sheet) Parsed savedAddresses: $savedAddresses');
          } else {
            fetchError = 'Failed to load addresses.';
            debugPrint('(Sheet) Fetch failed, status: ${response?.statusCode}');
          }
        } catch (e) {
          fetchError = 'Could not load addresses.';
          debugPrint('(Sheet) Fetch error: $e');
          if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
            fetchError = 'Authentication failed. Please log in again.';
            // Optionally clear token, etc.
          }
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
                          final response = await AuthApi.authenticatedRequest(() => dio.get(
                            url,
                            options: Options(headers: {
                              'Content-Type': 'application/json',
                            }),
                          ));
                          if (response != null && response.statusCode == 200 && response.data is List) {
                            savedAddresses = List<Map<String, dynamic>>.from(
                              (response.data as List).where((item) => item is Map).map((item) => Map<String, dynamic>.from(item))
                            );
                          } else {
                            fetchError = 'Failed to load addresses.';
                          }
                        } catch (e) {
                          fetchError = 'Could not load addresses.';
                          if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
                            fetchError = 'Authentication failed. Please log in again.';
                          }
                        }
                      } else { fetchError = 'Not logged in.'; }
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
                      setState(() {
                        _selectedPincode = pincode;
                        _useCurrentLocation = false;
                        globalCurrentAddress = null;
                      });
                      await _checkDeliveryAvailability(pincode: pincode);
                      await _initializeHomeScreenData(); // Refresh home data for new pincode
                    }
                 }

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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Select Delivery Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(sheetContext)),
                              ],
                            ),
                            Divider(height: 20),
                            if (isLoading)
                               Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())),
                            if (!isLoading && fetchError != null)
                                Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 20.0), child: Text(fetchError!, style: TextStyle(color: Colors.red)))),
                            if (!isLoading && fetchError == null && savedAddresses.isEmpty) ...[
                               SizedBox(height: 10),
                               Center(
                                  child: OutlinedButton.icon(
                                     icon: Icon(Icons.pin_drop_outlined, size: 16),
                                     label: Text('Check Delivery via Pincode'),
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
                                        final addressLine1 = address['address_line_1']?.toString() ?? ''; 

                                        debugPrint('(Sheet ListTile Builder) Index: $index, Address ID: ${address['id']}, value for title: "$addressLine1", isEmpty: ${addressLine1.isEmpty}');

                                        return ListTile(
                                           leading: Icon(
                                              isCurrent ? Icons.check_circle : Icons.radio_button_unchecked,
                                              color: isCurrent ? Colors.orange : Colors.grey,
                                              size: 22,
                                           ),
                                           title: Text(addressLine1.isNotEmpty ? addressLine1 : '(No Address Line 1)'), 
                                           subtitle: Text('${address['city'] ?? ''}, ${address['state'] ?? ''} ${address['postal_code'] ?? ''}'),
                                           onTap: () async {
                                              final selectedAddress = Map<String, dynamic>.from(address); 
                                              setState(() {
                                                globalCurrentAddress = selectedAddress;
                                                saveCurrentAddressId(selectedAddress['id']?.toString());
                                              });
                                              Navigator.pop(sheetContext);
                                              await _checkDeliveryAvailability(
                                                  latitude: (selectedAddress['latitude'] as num?)?.toDouble(),
                                                  longitude: (selectedAddress['longitude'] as num?)?.toDouble(),
                                                  pincode: selectedAddress['postal_code']?.toString()
                                              );
                                              await _initializeHomeScreenData(); 
                                           },
                                        );
                                     },
                                  ),
                               ),
                            Divider(height: 20),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                TextButton.icon(
                                  icon: Icon(Icons.my_location, size: 16),
                                  label: Text('Use Current Location'),
                                  onPressed: () async {
  Navigator.pop(sheetContext);
  await onUseCurrentLocation();
},
                                  style: TextButton.styleFrom(foregroundColor: Colors.blue.shade700),
                                ),
                                TextButton.icon(
                                  icon: Icon(Icons.add_circle_outline, size: 16),
                                  label: Text('Add New Address'),
                                  onPressed: goToAddAddress,
                                ),
                                const SizedBox(width: 10),
                                TextButton.icon(
                                  icon: Icon(Icons.settings_outlined, size: 16),
                                  label: Text('Manage All'),
                                  onPressed: () {
                                    Navigator.pop(sheetContext); 
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
                                  },
                                ),
                              ],
                            ),
                            if (!isLoading && fetchError == null) 
                              Center(
                                child: TextButton.icon(
                                  icon: Icon(Icons.pin_drop_outlined, size: 16),
                                  label: const Text('Or Check Delivery via Pincode'),
                                  onPressed: checkDeliveryWithPincode,
                                  style: TextButton.styleFrom(foregroundColor: Colors.orange.shade700),
                                ),
                              ),
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
                    OrderStatusBanner(),
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
          final token = await AuthStorage.getAccessToken();
          if (token == null || token.isEmpty) {
            _redirectToLogin();
          }
          _redirectToLogin();
        }
      } else {
        _redirectToLogin();
      }
    }
  }
}

class RestaurantCard extends StatelessWidget {
  final Map<String, dynamic> restaurant;

  const RestaurantCard({Key? key, required this.restaurant}) : super(key: key);

  Widget _buildRestaurantImage(String imageUrl, String name) {
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
      child: Icon(Icons.store, size: 60, color: Colors.grey),
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
    } else {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    }
  }

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
                  child: _buildRestaurantImage(imageUrl, name),
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
    // Prioritize the first URL from image_urls if available
    final imageList = food['image_urls'] as List?;
    String imageUrl = '';
    if (imageList != null && imageList.isNotEmpty && imageList[0] is String) {
       imageUrl = imageList[0] as String;
    } else {
       // Fallback to the 'image' field if 'image_urls' is missing or empty
       imageUrl = food['image']?.toString() ?? '';
    }
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
              child: FoodCard._buildImage(imageUrl, name), // Use static method
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

  static Widget _buildImage(String imageUrl, String name) {
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
      return FoodCard._buildPlaceholderImage(name);
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
          return FoodCard._buildPlaceholderImage(name);
        },
      );
    } else {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading asset image "$imageUrl": $error');
          return FoodCard._buildPlaceholderImage(name);
        },
      );
    }
  }

  static Widget _buildPlaceholderImage(String name) {
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
