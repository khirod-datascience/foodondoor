import 'package:flutter/material.dart';
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

// --- HomeScreen and _HomeScreenState implementation ---

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
  bool _addressSheetShownAfterLoad = false;
  String? _authToken;
  bool _useCurrentLocation = false;
  String? _selectedPincode;
  bool _isFetchingAddress = false;

  @override
  void initState() {
    super.initState();
    _startupAuthAndLocation();
    // Fetch address after first frame so UI loads immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAndSetAddress();
    });
  }

  Future<void> _startupAuthAndLocation() async {
    await _checkAuthToken();
    await _verifyAuthentication();
    if (mounted && _authToken != null) {
      await _initializeHomeScreenData();
      _fetchAndSetAddress();
    }
  }

  Future<void> _checkAuthToken() async {
    _authToken = await AuthStorage.getToken();
  }

  Future<void> _verifyAuthentication() async {
    if (_authToken == null || _authToken!.isEmpty) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<void> _initializeHomeScreenData() async {
    // Placeholder for future extensibility (fetch user profile, etc.)
    // Currently does nothing.
  }

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

  Future<void> _reverseGeocodeAndSet(double lat, double lon) async {
    try {
      final dio = Dio();
      final token = await AuthStorage.getToken();
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

  Future<void> onAddressSelected(Map<String, dynamic> address) async {
    setState(() {
      globalCurrentAddress = address;
      _useCurrentLocation = false;
    });
    await _fetchAndSetAddress();
  }

  // ... (other methods for UI, address selection, banners, categories, restaurant list, food list, etc.)

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HomeProvider>(
      create: (_) => HomeProvider()..fetchBanners()..fetchCategories()..fetchNearbyRestaurants()..fetchTopRatedRestaurants()..fetchPopularFoodItems(),
      child: Consumer<HomeProvider>(
        builder: (context, homeProvider, _) {
          if (homeProvider.isLoading) {
            return AppScaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (homeProvider.error != null && homeProvider.error!.isNotEmpty) {
            return AppScaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 48),
                    SizedBox(height: 16),
                    Text(
                      homeProvider.error!,
                      style: TextStyle(fontSize: 18, color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        await Future.wait([
                          homeProvider.fetchBanners(),
                          homeProvider.fetchCategories(),
                          homeProvider.fetchNearbyRestaurants(),
                          homeProvider.fetchTopRatedRestaurants(),
                          homeProvider.fetchPopularFoodItems(),
                        ]);
                      },
                      child: Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          return AppScaffold(
            body: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  homeProvider.fetchBanners(),
                  homeProvider.fetchCategories(),
                  homeProvider.fetchNearbyRestaurants(),
                  homeProvider.fetchTopRatedRestaurants(),
                  homeProvider.fetchPopularFoodItems(),
                ]);
              },
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildTopBar(context),
                  _buildAddressSelector(context),
                  homeProvider.banners.isNotEmpty
                    ? _buildBannerCarousel(homeProvider)
                    : _buildPlaceholder('No banners available'),
                  homeProvider.categories.isNotEmpty
                    ? _buildCategoryList(homeProvider)
                    : _buildPlaceholder('No categories found'),
                  _buildSectionHeader('Nearby Restaurants', onViewAll: () => _navigateToRestaurantList(context, 'nearby')),
                  homeProvider.nearbyRestaurants.isNotEmpty
                    ? _buildRestaurantList(homeProvider.nearbyRestaurants)
                    : _buildPlaceholder('No nearby restaurants'),
                  _buildSectionHeader('Top Rated Restaurants', onViewAll: () => _navigateToRestaurantList(context, 'top-rated')),
                  homeProvider.topRatedRestaurants.isNotEmpty
                    ? _buildRestaurantList(homeProvider.topRatedRestaurants)
                    : _buildPlaceholder('No top rated restaurants'),
                  _buildSectionHeader('Popular Foods', onViewAll: () => _navigateToPopularFoods(context)),
                  homeProvider.popularFoodItems.isNotEmpty
                    ? _buildFoodList(homeProvider.popularFoodItems)
                    : _buildPlaceholder('No popular foods'),
                  SizedBox(height: 16),
                ],
              ),
            ),
            floatingActionButton: _buildFAB(context),
          );
        },
      ),
    );
  }

  Widget _buildPlaceholder(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('FoodOnDoor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.orange[700])),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.notifications_outlined),
                onPressed: () => Navigator.pushNamed(context, '/notifications'),
              ),
              IconButton(
                icon: Icon(Icons.account_circle_outlined),
                onPressed: () => Navigator.pushNamed(context, '/profile'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSelector(BuildContext context) {
    // Use globalCurrentAddress and allow switching between saved/current location
    final addressLine = globalCurrentAddress != null ? (globalCurrentAddress!['address_line1'] ?? 'Select Address') : 'Select Address';
    return GestureDetector(
      onTap: () => _showAddressSelectionSheet(context),
      child: Container(
        color: Colors.orange.withOpacity(0.08),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.location_on, color: Colors.orange[700]),
            SizedBox(width: 8),
            Expanded(child: Text(addressLine, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15))),
            Icon(Icons.keyboard_arrow_down),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerCarousel(HomeProvider provider) {
    if (provider.banners.isEmpty) {
      return Container(height: 140, alignment: Alignment.center, child: CircularProgressIndicator());
    }
    return Container(
      height: 140,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: PageView.builder(
        itemCount: provider.banners.length,
        controller: PageController(viewportFraction: 0.9),
        itemBuilder: (context, index) {
          final url = provider.banners[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: url.isNotEmpty ? Image.network(url, fit: BoxFit.cover, width: double.infinity) : Container(color: Colors.grey[200]),
          );
        },
      ),
    );
  }

  Widget _buildCategoryList(HomeProvider provider) {
    if (provider.categories.isEmpty) {
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = categories[index];
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = category['name'];
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedCategory == category['name'] ? Colors.orange[100] : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  if ((category['image_url'] ?? '').isNotEmpty)
                    CircleAvatar(
                      backgroundImage: NetworkImage(category['image_url']),
                      radius: 16,
                      backgroundColor: Colors.transparent,
                    ),
                  if ((category['image_url'] ?? '').isNotEmpty)
                    SizedBox(width: 8),
                  Text(
                    category['name'] ?? '',
                    style: TextStyle(fontWeight: FontWeight.w500, color: Colors.orange[800]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onViewAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          if (onViewAll != null)
            GestureDetector(
              onTap: onViewAll,
              child: Text('View All', style: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.w500)),
            ),
        ],
      ),
    );
  }

  Widget _buildRestaurantList(List<Map<String, dynamic>>? restaurants) {
    final safeRestaurants = restaurants ?? [];
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: safeRestaurants.length,
        separatorBuilder: (context, index) => SizedBox(width: 12),
        itemBuilder: (context, index) {
          final restaurant = safeRestaurants[index];
          return RestaurantCard(restaurant: restaurant);
        },
      ),
    );
  }

  Widget _buildFoodList(List<Map<String, dynamic>>? foods) {
    final safeFoods = foods ?? [];
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: safeFoods.length,
        separatorBuilder: (context, index) => SizedBox(width: 12),
        itemBuilder: (context, index) {
          final food = safeFoods[index];
          return HomeFoodCard(food: food);
        },
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => Navigator.pushNamed(context, '/cart'),
      icon: Icon(Icons.shopping_cart_outlined),
      label: Text('Cart'),
      backgroundColor: Colors.orange[700],
    );
  }

  void _showAddressSelectionSheet(BuildContext context) {
    // TODO: Implement address selection sheet (show saved addresses, option for current location, add new address)
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => Container(
        height: 320,
        child: Center(child: Text('Address selection UI goes here.')),
      ),
    );
  }

  void _navigateToRestaurantList(BuildContext context, String type) {
    // TODO: Implement navigation to full restaurant list page
    // type: 'nearby' or 'top-rated'
  }

  void _navigateToPopularFoods(BuildContext context) {
    // TODO: Implement navigation to full popular foods page
  }
}

// --- RestaurantCard Widget ---
class RestaurantCard extends StatelessWidget {
  final Map<String, dynamic> restaurant;
  const RestaurantCard({Key? key, required this.restaurant}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name = restaurant['name'] ?? 'Unknown Restaurant';
    final rating = (restaurant['rating'] ?? 0.0).toDouble();
    final cuisineType = restaurant['cuisine_type'] ?? 'Various Cuisines';
    final imageUrl = restaurant['image'] ?? '';
    final vendorId = restaurant['vendor_id']?.toString() ?? restaurant['id']?.toString() ?? '';
    return GestureDetector(
      onTap: () {
        if (vendorId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Restaurant ID not found')),
          );
          return;
        }
        Navigator.pushNamed(
          context,
          '/restaurant-detail',
          arguments: {'vendor_id': vendorId},
        );
      },
      child: Card(
        child: Column(
          children: [
            _buildRestaurantImage(imageUrl, name),
            Text(name),
            Text(cuisineType),
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 14),
                Text(rating > 0 ? rating.toStringAsFixed(1) : 'New'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantImage(String imageUrl, String name) {
    if (imageUrl.isEmpty) {
      return Icon(Icons.restaurant, size: 40, color: Colors.grey);
    }
    return Image.network(imageUrl, height: 80, width: double.infinity, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Icon(Icons.restaurant, size: 40, color: Colors.grey));
  }
}

// --- HomeFoodCard Widget ---
class HomeFoodCard extends StatelessWidget {
  final Map<String, dynamic> food;
  const HomeFoodCard({Key? key, required this.food}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final imageUrl = food['image'] ?? '';
    final name = food['name'] ?? '';
    final price = food['price'] ?? '';
    return Container(
      width: 160,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl, height: 100, width: 160, fit: BoxFit.cover)
                : Container(
                    height: 100,
                    width: 160,
                    color: Colors.orange[50],
                    child: Icon(Icons.fastfood_outlined, color: Colors.orange[200], size: 48),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('₹$price', style: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


