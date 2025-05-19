import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'package:foodondoor_restaurant/utils/globals.dart';

class PromotionsScreen extends StatefulWidget {
  @override
  _PromotionsScreenState createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  List<dynamic> _promos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPromos();
  }

  Future<void> _fetchPromos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/auth/vendor-promotions/${Globals.vendorId}/'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _promos = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to fetch promotions';
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

  Future<void> _addPromo() async {
    String? promoTitle;
    String? promoDescription;
    DateTime? startDate;
    DateTime? endDate;
    final titleController = TextEditingController();
    final descController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Promotion'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(hintText: 'Promotion title'),
              ),
              SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: InputDecoration(hintText: 'Description'),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(startDate == null ? 'Start Date' : startDate!.toLocal().toString().split(' ')[0]),
                  ),
                  TextButton(
                    child: Text('Pick'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        startDate = picked;
                        (context as Element).markNeedsBuild();
                      }
                    },
                  )
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(endDate == null ? 'End Date' : endDate!.toLocal().toString().split(' ')[0]),
                  ),
                  TextButton(
                    child: Text('Pick'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        endDate = picked;
                        (context as Element).markNeedsBuild();
                      }
                    },
                  )
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('Add'),
            onPressed: () async {
              promoTitle = titleController.text;
              promoDescription = descController.text;
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                final response = await http.post(
                  Uri.parse('${Config.baseUrl}/auth/vendor-promotions/${Globals.vendorId}/'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'title': promoTitle,
                    'description': promoDescription,
                    'start_date': startDate != null ? startDate!.toIso8601String().split('T')[0] : null,
                    'end_date': endDate != null ? endDate!.toIso8601String().split('T')[0] : null,
                  }),
                );
                if (response.statusCode == 201) {
                  _fetchPromos();
                } else {
                  setState(() {
                    _error = 'Failed to add promotion';
                    _isLoading = false;
                  });
                }
              } catch (e) {
                setState(() {
                  _error = 'Network error';
                  _isLoading = false;
                });
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
        title: Text('Promotions'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _addPromo,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: Colors.red)))
              : _promos.isEmpty
                  ? Center(child: Text('No promotions found'))
                  : ListView.builder(
                      itemCount: _promos.length,
                      itemBuilder: (context, idx) {
                        final promo = _promos[idx];
                        return Card(
                          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: Icon(Icons.campaign, color: Colors.orange.shade700),
                            title: Text(promo['title'] ?? 'Untitled'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ID: 	${promo['id'] ?? ''}'),
                                if (promo['description'] != null) Text(promo['description']),
                                if (promo['start_date'] != null) Text('Start: ${promo['start_date']}'),
                                if (promo['end_date'] != null) Text('End: ${promo['end_date']}'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _editPromoDialog(promo),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deletePromo(promo['id']),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  Future<void> _editPromoDialog(Map promo) async {
    final titleController = TextEditingController(text: promo['title'] ?? '');
    final descController = TextEditingController(text: promo['description'] ?? '');
    DateTime? startDate = promo['start_date'] != null && promo['start_date'] != ''
        ? DateTime.tryParse(promo['start_date'])
        : null;
    DateTime? endDate = promo['end_date'] != null && promo['end_date'] != ''
        ? DateTime.tryParse(promo['end_date'])
        : null;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Promotion'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(hintText: 'Promotion title'),
              ),
              SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: InputDecoration(hintText: 'Description'),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(startDate == null ? 'Start Date' : (startDate?.toLocal().toString().split(' ')[0] ?? 'Start Date')),
                  ),
                  TextButton(
                    child: Text('Pick'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        startDate = picked;
                        (context as Element).markNeedsBuild();
                      }
                    },
                  )
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(endDate == null ? 'End Date' : (endDate?.toLocal().toString().split(' ')[0] ?? 'End Date')),
                  ),
                  TextButton(
                    child: Text('Pick'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: endDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        endDate = picked;
                        (context as Element).markNeedsBuild();
                      }
                    },
                  )
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('Save'),
            onPressed: () async {
              final promoTitle = titleController.text;
              final promoDescription = descController.text;
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                final response = await http.put(
                  Uri.parse('${Config.baseUrl}/auth/vendor-promotions/${Globals.vendorId}/${promo['id']}/'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'title': promoTitle,
                    'description': promoDescription,
                    'start_date': startDate != null ? startDate?.toIso8601String().split('T')[0] : null,
                    'end_date': endDate != null ? endDate?.toIso8601String().split('T')[0] : null,
                  }),
                );
                if (response.statusCode == 200) {
                  _fetchPromos();
                } else {
                  setState(() {
                    _error = 'Failed to update promotion';
                    _isLoading = false;
                  });
                }
              } catch (e) {
                setState(() {
                  _error = 'Network error';
                  _isLoading = false;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deletePromo(int promoId) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Promotion'),
        content: Text('Are you sure you want to delete this promotion?'),
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
          Uri.parse('${Config.baseUrl}/auth/vendor-promotions/${Globals.vendorId}/$promoId/'),
        );
        if (response.statusCode == 200) {
          _fetchPromos();
        } else {
          setState(() {
            _error = 'Failed to delete promotion';
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
