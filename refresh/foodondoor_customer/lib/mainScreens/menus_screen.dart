import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models/food_item.dart';
import '../widgets/menus_design.dart';
import '../widgets/my_drower.dart';
import '../widgets/progress_bar.dart';
import '../widgets/text_widget_header.dart';
import '../services/api_service.dart';
import '../global/global.dart';
import '../splashScreen/splash_screen.dart';

class MenusScreen extends StatefulWidget {
  final String vendorId;

  const MenusScreen({super.key, required this.vendorId});

  @override
  State<MenusScreen> createState() => _MenusScreenState();
}

class _MenusScreenState extends State<MenusScreen> {
  Map<String, dynamic>? _restaurantDetails;
  List<FoodItem> _menuItems = [];
  bool _isLoading = true;
  String? _error;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchRestaurantDetailsAndMenu();
  }

  Future<void> _fetchRestaurantDetailsAndMenu() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _restaurantDetails = null;
      _menuItems = [];
    });

    try {
      final endpoint = '/api/restaurants/${widget.vendorId}/';
      final response = await _apiService.get(endpoint);

      if (response is Map<String, dynamic> && (response['error'] == null)) {
        final List<dynamic>? menuData = response['menu'] as List<dynamic>?;

        setState(() {
          _restaurantDetails = response;
          _menuItems = menuData != null
              ? menuData.map((json) => FoodItem.fromJson(json as Map<String, dynamic>)).toList()
              : [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _restaurantDetails = null;
          _menuItems = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _restaurantDetails = null;
        _menuItems = [];
        _isLoading = false;
      });
    }
  }

  Widget _buildMenu() {
    if (_isLoading) {
      return SliverToBoxAdapter(child: Center(child: circularProgress()));
    }
    if (_error != null) {
      if (_restaurantDetails == null) {
        return SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error loading restaurant: $_error', textAlign: TextAlign.center),
            ),
          ),
        );
      } else {
        return SliverToBoxAdapter(child: Center(child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error loading menu: $_error', textAlign: TextAlign.center),
        )));
      }
    }
    if (_menuItems.isEmpty) {
      return const SliverToBoxAdapter(child: Center(child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('This restaurant has no menu items listed yet.', textAlign: TextAlign.center),
      )));
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          FoodItem foodItemModel = _menuItems[index];
          // Pass FoodItem and vendorId to the design widget
          return MenusDesignWidget(
            model: foodItemModel, // Pass FoodItem model
            context: context,
            vendorId: widget.vendorId, // Pass vendorId
          );
        },
        childCount: _menuItems.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle = _isLoading 
        ? 'Loading...' 
        : _restaurantDetails?['name'] as String? ?? 'Restaurant Menu';
    
    String headerTitle = _isLoading
        ? 'Loading Details...'
        : _restaurantDetails?['name'] as String? ?? 'Menu Items';

    return Scaffold(
      appBar: AppBar(
        title: Text('Menu', style: Theme.of(context).appBarTheme.titleTextStyle),
        centerTitle: true,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          if (_restaurantDetails != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_restaurantDetails!['name'] ?? 'Restaurant Name', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(_restaurantDetails!['address'] ?? 'Address not available'),
                    const SizedBox(height: 4),
                    if (_restaurantDetails!['rating'] != null)
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(_restaurantDetails!['rating'].toString()),
                        ],
                      ),
                    if (_restaurantDetails!['cuisine_type'] != null)
                      Text('Cuisine: ${_restaurantDetails!['cuisine_type']}'),
                    const SizedBox(height: 10),
                    const Divider(),
                    Text('Menu', style: Theme.of(context).textTheme.titleMedium),

                  ],
                ),
              ),
            ), 
          _buildMenu(),
        ],
      ),
    );
  }
}
