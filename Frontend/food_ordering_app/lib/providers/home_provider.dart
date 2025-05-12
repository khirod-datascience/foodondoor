import 'package:flutter/material.dart';
// Purpose: Manages the state for the home screen, fetching banners, categories, restaurants, and popular food items.

import 'package:dio/dio.dart';
import '../config.dart';
import '../services/location_service.dart';
import '../screens/search_screen.dart';

class HomeProvider extends ChangeNotifier {
  final Dio _dio = Dio();
  bool isLoading = true;
  String? error;
  List<String> banners = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> nearbyRestaurants = [];
  List<Map<String, dynamic>> topRatedRestaurants = [];
  List<Map<String, dynamic>> popularFoodItems = []; // New list for food items

  HomeProvider() {
    _dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: true,
      responseBody: true,
      error: true,
    ));

    // Configure Dio to not throw on 404 errors
    _dio.options.validateStatus = (status) {
      return status! < 500;
    };
  }

  Future<void> initializeHomeScreen() async {
    try {
      debugPrint('(HomeProvider) Starting data initialization...');
      isLoading = true;
      error = null;
      notifyListeners();

      // Fetch all data concurrently for better performance
      debugPrint('(HomeProvider) Fetching data concurrently...');
      final results = await Future.wait([
        fetchBanners().then((_) => 'banners'),
        fetchCategories().then((_) => 'categories'),
        fetchNearbyRestaurants().then((_) => 'nearby'),
        fetchTopRatedRestaurants().then((_) => 'top-rated'),
        fetchPopularFoodItems().then((_) => 'popular'),
      ], eagerError: false);

      // Check if any data is missing
      final missingData = results.where((result) => result == null).toList();
      if (missingData.isNotEmpty) {
        error = 'Some data could not be loaded. Please try again.';
        debugPrint('(HomeProvider) Missing data: $missingData');
      }

      debugPrint('(HomeProvider) Data fetch complete');
      debugPrint('Banners: ${banners.length}');
      debugPrint('Categories: ${categories.length}');
      debugPrint('Nearby restaurants: ${nearbyRestaurants.length}');
      debugPrint('Top-rated restaurants: ${topRatedRestaurants.length}');
      debugPrint('Popular food items: ${popularFoodItems.length}');

    } catch (e) {
      debugPrint('(HomeProvider) Error during initialization: $e');
      error = 'Failed to load data. Please try again.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> requestLocation() async {
    try {
      final location = await LocationService.getCurrentLocation();
      if (location == null) {
        debugPrint('Location not available or permissions denied');
        return;
      }
      debugPrint('User location: $location');
      // Check delivery availability here if needed
    } catch (e) {
      debugPrint('Error fetching location: $e');
    }
  }

  Future<void> fetchBanners() async {
    try {
      debugPrint('(HomeProvider) Fetching banners...');
      final response = await _dio.get('${AppConfig.baseUrl}/banners/');
      debugPrint('(HomeProvider) Banners API Response: ${response.data}');
      
      if (response.statusCode == 200) {
        if (response.data is List) {
          banners = List<String>.from(response.data.where((item) => item != null));
        } else if (response.data['banners'] is List) {
          banners = List<String>.from(response.data['banners'].where((item) => item != null));
        } else {
          debugPrint('(HomeProvider) Unexpected banners response format');
          banners = [];
        }
      } else {
        debugPrint('(HomeProvider) Banners API returned status ${response.statusCode}');
        banners = [];
      }
      debugPrint('(HomeProvider) Banners fetched: ${banners.length}');
    } catch (e) {
      debugPrint('(HomeProvider) Error fetching banners: $e');
      banners = [];
      rethrow;
    }
  }

  Future<void> fetchCategories() async {
    final String url = '${AppConfig.baseUrl}/categories/';
    try {
      debugPrint('(HomeProvider) Fetching categories from URL: $url');
      final response = await _dio.get(url);
      debugPrint('(HomeProvider) Categories API Response: ${response.data}');
      
      if (response.statusCode == 200) {
        if (response.data is List) {
          categories = List<Map<String, dynamic>>.from(
            (response.data as List).where((item) => 
              item is Map<String, dynamic> && 
              item.containsKey('name') &&
              item['name'] != null
            ).map((item) {
              final categoryMap = Map<String, dynamic>.from(item);
              categoryMap['image_url'] = categoryMap['image_url']?.toString() ?? '';
              return categoryMap;
            })
          );
          
          if (categories.isNotEmpty && categories.first['name'] != 'All') {
            categories.insert(0, {'name': 'All', 'image_url': ''});
          }
        } else {
          debugPrint('(HomeProvider) Categories API did not return a list');
          categories = [];
        }
      } else {
        debugPrint('(HomeProvider) Categories API returned status ${response.statusCode}');
        categories = [];
      }
      debugPrint('(HomeProvider) Categories fetched: ${categories.length}');
    } catch (e) {
      debugPrint('(HomeProvider) Error fetching categories: $e');
      categories = [];
      rethrow;
    }
  }

  Future<void> fetchNearbyRestaurants() async {
    try {
      debugPrint('(HomeProvider) Fetching nearby restaurants...');
      final response = await _dio.get('${AppConfig.baseUrl}/nearby-restaurants/');
      debugPrint('(HomeProvider) Nearby restaurants API response: ${response.data}');
      
      if (response.statusCode == 200 && response.data is List) {
        final List<dynamic> data = response.data;
        nearbyRestaurants = data.map((item) {
          if (item is Map<String, dynamic>) {
            final restaurant = Map<String, dynamic>.from(item);
            if (restaurant['image'] == null || restaurant['image'].toString().isEmpty) {
              restaurant['image'] = 'https://placehold.co/150x150/EAEAEA/6D6D6D.png?text=${Uri.encodeComponent(restaurant['name']?.toString() ?? 'Restaurant')}';
            }
            return restaurant;
          }
          return <String, dynamic>{};
        }).where((item) => item.isNotEmpty).toList();
      } else {
        debugPrint('(HomeProvider) Unexpected response format for nearby restaurants');
        nearbyRestaurants = [];
      }
      debugPrint('(HomeProvider) Nearby restaurants fetched: ${nearbyRestaurants.length}');
    } catch (e) {
      debugPrint('(HomeProvider) Error fetching nearby restaurants: $e');
      nearbyRestaurants = [];
      rethrow;
    }
  }

  Future<void> fetchTopRatedRestaurants() async {
    try {
      debugPrint('(HomeProvider) Fetching top-rated restaurants...');
      final response = await _dio.get('${AppConfig.baseUrl}/top-rated-restaurants/');
      debugPrint('(HomeProvider) Top-rated restaurants API response: ${response.data}');
      
      if (response.statusCode == 200 && response.data is List) {
        final List<dynamic> data = response.data;
        topRatedRestaurants = data.map((item) {
          if (item is Map<String, dynamic>) {
            final restaurant = Map<String, dynamic>.from(item);
            if (restaurant['image'] == null || restaurant['image'].toString().isEmpty) {
              restaurant['image'] = 'https://placehold.co/150x150/EAEAEA/6D6D6D.png?text=${Uri.encodeComponent(restaurant['name']?.toString() ?? 'Restaurant')}';
            }
            return restaurant;
          }
          return <String, dynamic>{};
        }).where((item) => item.isNotEmpty).toList();
      } else {
        debugPrint('(HomeProvider) Unexpected response format for top-rated restaurants');
        topRatedRestaurants = [];
      }
      debugPrint('(HomeProvider) Top-rated restaurants fetched: ${topRatedRestaurants.length}');
    } catch (e) {
      debugPrint('(HomeProvider) Error fetching top-rated restaurants: $e');
      topRatedRestaurants = [];
      rethrow;
    }
  }

  Future<void> fetchPopularFoodItems() async {
    try {
      debugPrint('(HomeProvider) Fetching popular food items...');
      final response = await _dio.get('${AppConfig.baseUrl}/popular-foods/');
      debugPrint('(HomeProvider) Popular food items API response: ${response.data}');
      
      if (response.statusCode == 200 && response.data is List) {
        final List<dynamic> data = response.data;
        popularFoodItems = data.map((item) {
          if (item is Map<String, dynamic>) {
            final food = Map<String, dynamic>.from(item);
            if (food['image'] == null || food['image'].toString().isEmpty) {
              food['image'] = 'https://placehold.co/150x150/EAEAEA/6D6D6D.png?text=${Uri.encodeComponent(food['name']?.toString() ?? 'Food')}';
            }
            return food;
          }
          return <String, dynamic>{};
        }).where((item) => item.isNotEmpty).toList();
      } else {
        debugPrint('(HomeProvider) Unexpected response format for popular food items');
        popularFoodItems = [];
      }
      debugPrint('(HomeProvider) Popular food items fetched: ${popularFoodItems.length}');
    } catch (e) {
      debugPrint('(HomeProvider) Error fetching popular food items: $e');
      popularFoodItems = [];
      rethrow;
    }
  }

  Future<List<SearchResult>> searchRestaurantsAndFood(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      debugPrint('(HomeProvider) Searching for: $query');
      final response = await _dio.get(
        '${AppConfig.baseUrl}/search/',
        queryParameters: {'q': query.trim()},
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = response.data is List 
          ? response.data 
          : response.data['results'] as List? ?? [];

        return results.where((item) => item is Map<String, dynamic>).map((item) {
          try {
            return SearchResult.fromJson(item as Map<String, dynamic>);
          } catch (e) {
            debugPrint('(HomeProvider) Error parsing search result: $e');
            return null;
          }
        }).whereType<SearchResult>().toList();
      }
      
      debugPrint('(HomeProvider) Search API returned status ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('(HomeProvider) Error searching: $e');
      return [];
    }
  }

  // Add methods for recent searches
  List<String> _recentSearches = [];

  Future<List<String>> getRecentSearches() async {
    return _recentSearches;
  }

  Future<void> addRecentSearch(String query) async {
    if (!_recentSearches.contains(query)) {
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 10) {
        _recentSearches.removeLast();
      }
      notifyListeners();
    }
  }

  Future<void> removeRecentSearch(String query) async {
    _recentSearches.remove(query);
    notifyListeners();
  }

  Future<List<String>> getSearchSuggestions(String query) async {
    try {
      final response = await _dio.get(
        '${AppConfig.baseUrl}/search-suggestions/',
        queryParameters: {'q': query},
      );

      if (response.data is List) {
        return List<String>.from(response.data);
      } else if (response.data['suggestions'] is List) {
        return List<String>.from(response.data['suggestions']);
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> searchRestaurants(String query) {
    query = query.toLowerCase();
    return [...nearbyRestaurants, ...topRatedRestaurants]
        .where((restaurant) => 
            restaurant['name']?.toString().toLowerCase().contains(query) == true ||
            restaurant['cuisine_type']?.toString().toLowerCase().contains(query) == true)
        .toList();
  }
}