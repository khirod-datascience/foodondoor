import 'package:flutter/material.dart';
// Purpose: Provides the search UI and handles fetching/displaying search results for restaurants and food items.

import 'package:provider/provider.dart';
import '../providers/home_provider.dart';
import 'dart:async';
import '../config.dart';
import 'package:dio/dio.dart';

class SearchResult {
  final String id;
  final String vendorId;
  final String name;
  final String description;
  final String imageUrl;
  final double rating;
  final double distance;
  final String type; // 'restaurant' or 'food'

  SearchResult({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.rating,
    required this.distance,
    required this.type,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final vendorId = json['vendor_id']?.toString() ?? '';
    
    // Debug print to check the id and vendorId
    debugPrint('Creating SearchResult with id: $id, vendorId: $vendorId');

    return SearchResult(
      id: id,
      vendorId: json['vendor_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      description: json['description']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      type: json['type']?.toString() ?? 'restaurant',
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _debouncer = Debouncer(milliseconds: 500);
  List<SearchResult> _searchResults = [];
  bool _isLoading = false;
  String _error = '';

  @override
  void dispose() {
    _searchController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _error = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final url = '${AppConfig.baseUrl}/search/';
      debugPrint('Making search request to: $url');
      debugPrint('Search query: $query');

      final response = await Dio().get(
        url,
        queryParameters: {'query': query},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => true, // This will prevent Dio from throwing errors for any status code
        ),
      );

      debugPrint('Search response status: ${response.statusCode}');
      debugPrint('Search response data: ${response.data}');
      debugPrint('Full API response: ${response.data}');

      if (response.statusCode == 200) {
        if (response.data == null) {
          debugPrint('Response data is null');
          setState(() {
            _error = 'Invalid response from server';
            _isLoading = false;
          });
          return;
        }

        final List<dynamic> restaurantResults = response.data['restaurants'] ?? [];
        final List<dynamic> foodResults = response.data['foods'] ?? [];
        debugPrint('Parsed ${restaurantResults.length} restaurant results');
        debugPrint('Parsed ${foodResults.length} food results');

        setState(() {
          _searchResults = [
            ...restaurantResults.map((result) => SearchResult.fromJson(result)).toList(),
            ...foodResults.map((result) => SearchResult.fromJson(result)).toList(),
          ];
          _isLoading = false;
        });
      } else {
        debugPrint('Error status code: ${response.statusCode}');
        debugPrint('Error response: ${response.data}');
        setState(() {
          _error = 'Server returned status code: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Search error: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _error = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search for restaurants or dishes',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                : null,
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: (value) {
            debugPrint('Search text changed: $value');
            _debouncer.run(() => _performSearch(value));
          },
          autofocus: true,
        ),
      ),
      body: Column(
        children: [
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              ),
            ),
          Expanded(
            child: _searchResults.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.isEmpty
                          ? 'Start typing to search'
                          : 'No results found',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final result = _searchResults[index];
                      return SearchResultTile(result: result);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class SearchResultTile extends StatelessWidget {
  final SearchResult result;

  const SearchResultTile({
    Key? key,
    required this.result,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Debug print to check the vendorId
    debugPrint('Navigating to restaurant-detail with vendorId: ${result.vendorId}');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: result.imageUrl.isNotEmpty
              ? Image.network(
                  result.imageUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildPlaceholderIcon();
                  },
                )
              : _buildPlaceholderIcon(),
        ),
        title: Text(
          result.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.star, size: 16, color: Colors.amber.shade700),
                const SizedBox(width: 4),
                Text(
                  result.rating.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                Text(
                  '${result.distance.toStringAsFixed(1)} km away',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          debugPrint('Navigating to restaurant-detail with id: ${result.vendorId}');
          Navigator.pushNamed(
            context,
            '/restaurant-detail',
            arguments: {
              'id': result.vendorId,
            },
          );
        },
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      width: 56,
      height: 56,
      color: Colors.grey.shade200,
      child: Icon(
        result.type == 'restaurant' ? Icons.restaurant : Icons.fastfood,
        color: Colors.grey[400],
      ),
    );
  }
}

class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}