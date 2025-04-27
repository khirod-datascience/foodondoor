import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart' hide CarouselController;
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Home/home.dart'; 
import '../models/banner.dart'; 
import '../models/category.dart'; 
import '../models/vendor.dart';
import '../widgets/sellers_design.dart';
import '../widgets/my_drower.dart';
import '../widgets/progress_bar.dart';
import '../services/api_service.dart';
import 'save_address_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic> _homeData = {};
  List<dynamic> _banners = []; 
  List<dynamic> _categories = []; 
  List<Vendor> _nearbyRestaurants = [];
  List<Vendor> _topRatedRestaurants = []; 
  List<dynamic> _popularFoods = []; 

  bool _isLoading = true;
  String? _error;
  final ApiService _apiService = ApiService();

  String? _selectedAddressText;

  Future<void> _showAddressSelectionDialog() async {
    final addresses = await _apiService.getCustomerAddresses();
    String? selectedAddressId;
    TextEditingController pincodeController = TextEditingController();
    bool isLoading = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Select Delivery Address', style: Theme.of(context).textTheme.titleLarge),
              content: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (addresses.isNotEmpty)
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Saved Addresses'),
                        value: selectedAddressId,
                        items: addresses.map<DropdownMenuItem<String>>((address) {
                          return DropdownMenuItem<String>(
                            value: address.id.toString(),
                            child: Text(address.displayAddress),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedAddressId = value;
                          });
                        },
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: pincodeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Enter Pincode',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            // TODO: Check pincode delivery availability
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.my_location),
                      label: const Text('Use Current Location'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        textStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        // TODO: Use Geolocator to get current location and check delivery
                      },
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add New Address'),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(builder: (ctx) => const SaveAddressScreen()),
                        );
                        if (result == true) {
                          _showAddressSelectionDialog();
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Save selected address or pincode
                    if (selectedAddressId != null || pincodeController.text.isNotEmpty) {
                      // TODO: Save selected address/pincode to state
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchHomeData();
    // Show address selection dialog after login
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAddressSelectionDialog();
    });
  }

  Future<void> _fetchHomeData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _apiService.get('/api/home-data/'); 

      if (response != null && response is Map<String, dynamic>) {
         setState(() {
           _homeData = response; 
           _banners = response['banners'] as List<dynamic>? ?? [];
           _categories = response['categories'] as List<dynamic>? ?? [];
           _nearbyRestaurants = (response['nearby_restaurants'] as List<dynamic>? ?? [])
                                .map((json) => Vendor.fromJson(json))
                                .toList();
           _topRatedRestaurants = (response['top_rated_restaurants'] as List<dynamic>? ?? [])
                                .map((json) => Vendor.fromJson(json))
                                .toList();
            _popularFoods = response['popular_foods'] as List<dynamic>? ?? [];

           _isLoading = false;
         });
      } else {
         setState(() {
           _error = 'Failed to load home data or invalid format';
           _isLoading = false;
         });
      }
    } catch (e) {
      setState(() {
        _error = "An error occurred: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  Widget _buildNearbyRestaurantList() {
    if (_nearbyRestaurants.isEmpty && !_isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.0),
          child: Text('No nearby restaurants found.', style: TextStyle(fontSize: 16)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _nearbyRestaurants.length,
      itemBuilder: (context, index) {
        Vendor vendorModel = _nearbyRestaurants[index];
        return SellersDesignWidget(
          model: vendorModel,
          context: context,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF6600), // Theme color
        automaticallyImplyLeading: true,
        title: const Text(
          'foodondoor',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        elevation: 1.5,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Open menu',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
        ],
      ),
      drawer: const MyDrawer(),
      body: RefreshIndicator(
        onRefresh: _fetchHomeData,
        color: Colors.orange,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.orange)))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, style: theme.textTheme.bodyMedium!.copyWith(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchHomeData,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Banner Section (Horizontal scroll for consistency)
                        if (_banners.isNotEmpty)
                          Container(
                            height: 150,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _banners.length,
                              itemBuilder: (context, index) {
                                final banner = _banners[index];
                                final imageUrl = banner['image'] as String?;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: imageUrl != null
                                        ? Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            width: 280,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                width: 280,
                                                color: Colors.grey[200],
                                                child: const Center(child: Icon(Icons.error_outline)),
                                              );
                                            },
                                          )
                                        : Container(
                                            width: 280,
                                            color: Colors.grey[200],
                                            child: const Center(child: Icon(Icons.image_not_supported)),
                                          ),
                                  ),
                                );
                              },
                            ),
                          ),
                        // Categories Section (GridView)
                        if (_categories.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              'Categories',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF6600),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 0.85,
                              ),
                              itemCount: _categories.length,
                              itemBuilder: (context, index) {
                                final category = _categories[index];
                                final categoryName = category['name']?.toString() ?? 'N/A';
                                final imageUrl = category['icon']?.toString() ?? '';
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: imageUrl.isNotEmpty
                                          ? Image.network(
                                              imageUrl,
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey, size: 30),
                                            )
                                          : const Icon(Icons.fastfood, color: Color(0xFFFF6600), size: 30),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      categoryName,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                        // Nearby Vendors Section
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 18, 0, 8),
                          child: Text(
                            "Nearby Vendors",
                            style: theme.textTheme.titleLarge!.copyWith(color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                        ),
                        _buildNearbyRestaurantList(),
                        // Popular Foods Section
                        if (_popularFoods.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 18, 0, 8),
                            child: Text(
                              "Popular Foods",
                              style: theme.textTheme.titleLarge!.copyWith(color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                          ),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _popularFoods.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 14),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemBuilder: (context, index) {
                              final food = _popularFoods[index];
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 7,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                                      child: food['image'] != null
                                          ? Image.network(
                                              food['image'],
                                              height: 100,
                                              width: 100,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Container(height: 100, width: 100, color: Colors.grey[200], child: const Icon(Icons.fastfood, size: 40)),
                                            )
                                          : Container(height: 100, width: 100, color: Colors.grey[200], child: const Icon(Icons.fastfood, size: 40)),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              food['name'] ?? '',
                                              style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              "₹${food['price'] ?? '--'}",
                                              style: theme.textTheme.bodyMedium!.copyWith(color: const Color(0xFFFF6600), fontWeight: FontWeight.w600, fontSize: 15),
                                            ),
                                            const SizedBox(height: 8),
                                            SizedBox(
                                              width: 120,
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFFFF6600),
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
                                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                                ),
                                                onPressed: () {
                                                  // Add to cart logic
                                                },
                                                child: const Text('Add to Cart'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }
}
