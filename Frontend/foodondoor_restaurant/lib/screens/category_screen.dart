import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'package:foodondoor_restaurant/utils/globals.dart';

class CategoryScreen extends StatefulWidget {
  @override
  _CategoryScreenState createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  List<dynamic> _categories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/auth/vendor-categories/${Globals.vendorId}/'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _categories = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to fetch categories';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error';
        _isLoading = false;
      });
    }
  }

  Future<void> _addCategory() async {
    String? categoryName;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Category'),
        content: TextField(
          onChanged: (val) => categoryName = val,
          decoration: InputDecoration(hintText: 'Category name'),
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('Add'),
            onPressed: () async {
              if (categoryName != null && categoryName!.trim().isNotEmpty) {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  final response = await http.post(
                    Uri.parse('${Config.baseUrl}/auth/vendor-categories/${Globals.vendorId}/'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({'name': categoryName}),
                  );
                  if (response.statusCode == 201) {
                    _fetchCategories();
                  } else {
                    setState(() {
                      _error = 'Failed to add category';
                      _isLoading = false;
                    });
                  }
                } catch (e) {
                  setState(() {
                    _error = 'Network error';
                    _isLoading = false;
                  });
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Categories'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _addCategory,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: Colors.red)))
              : _categories.isEmpty
                  ? Center(child: Text('No categories found'))
                  : ListView.builder(
                      itemCount: _categories.length,
                      itemBuilder: (context, idx) {
                        final cat = _categories[idx];
                        return Card(
                          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: Icon(Icons.category, color: Colors.orange.shade700),
                            title: Text(cat['name'] ?? 'Unnamed'),
                            subtitle: Text('ID: ${cat['id'] ?? ''}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _editCategoryDialog(cat),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteCategory(cat['id']),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  Future<void> _editCategoryDialog(Map cat) async {
    final nameController = TextEditingController(text: cat['name'] ?? '');
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Category'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(hintText: 'Category name'),
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('Save'),
            onPressed: () async {
              final newName = nameController.text;
              if (newName.trim().isNotEmpty) {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  final response = await http.put(
                    Uri.parse('${Config.baseUrl}/auth/vendor-categories/${Globals.vendorId}/${cat['id']}/'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({'name': newName}),
                  );
                  if (response.statusCode == 200) {
                    _fetchCategories();
                  } else {
                    setState(() {
                      _error = 'Failed to update category';
                      _isLoading = false;
                    });
                  }
                } catch (e) {
                  setState(() {
                    _error = 'Network error';
                    _isLoading = false;
                  });
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(int catId) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Category'),
        content: Text('Are you sure you want to delete this category?'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final response = await http.delete(
          Uri.parse('${Config.baseUrl}/auth/vendor-categories/${Globals.vendorId}/$catId/'),
        );
        if (response.statusCode == 200) {
          _fetchCategories();
        } else {
          setState(() {
            _error = 'Failed to delete category';
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _error = 'Network error';
          _isLoading = false;
        });
      }
    }
  }
}
