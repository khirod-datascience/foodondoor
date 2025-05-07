import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'package:foodondoor_vendor_app/src/features/menu/models/menu_item.dart';
import 'package:foodondoor_vendor_app/src/features/menu/providers/menu_provider.dart';
import 'add_edit_menu_item_screen.dart'; 
import 'category_list_screen.dart'; 
import 'package:cached_network_image/cached_network_image.dart'; 

class MenuListScreen extends StatelessWidget { 
  const MenuListScreen({Key? key}) : super(key: key);

  void _navigateToAddEditScreen(BuildContext context, {MenuItem? item}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditMenuItemScreen(menuItem: item),
      ),
    ).then((_) {
      context.read<MenuNotifier>().fetchMenuItems(); 
    });
  }

  void _confirmDeleteItem(BuildContext context, MenuItem item) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete "${item.name}"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(ctx).pop();
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(ctx).pop(); 
                final success = await context.read<MenuNotifier>().deleteMenuItem(item.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Item deleted.' : 'Failed to delete item.'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Menu Items'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            tooltip: 'Manage Categories',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const CategoryListScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Menu Item',
            onPressed: () => _navigateToAddEditScreen(context),
          ),
        ],
      ),
      body: Consumer<MenuNotifier>(
        builder: (context, menuNotifier, child) {
          if (menuNotifier.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (menuNotifier.status == MenuStateStatus.error || menuNotifier.status == MenuStateStatus.notFound) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(menuNotifier.errorMessage ?? 'An unknown error occurred.'),
                  if (menuNotifier.status == MenuStateStatus.error) 
                    ElevatedButton(
                      onPressed: () => context.read<MenuNotifier>().fetchMenuItems(),
                      child: const Text('Retry'),
                    )
                ],
              ),
            );
          }

          final items = menuNotifier.menuItems;
          if (items.isEmpty) {
            return Center(
                child: const Text('No menu items found. Add one!'));
          }

          return Stack(
            children: [
              ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    leading: SizedBox(
                      width: 60, 
                      height: 60, 
                      child: ClipRRect( 
                        borderRadius: BorderRadius.circular(8.0),
                        child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: item.imageUrl!,
                                placeholder: (context, url) => Container(color: Colors.grey[200]), 
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image, color: Colors.grey, size: 30),
                                ),
                                fit: BoxFit.cover,
                              )
                            : Container( 
                                color: Colors.grey[200],
                                child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 30),
                              ),
                      ),
                    ),
                    title: Text(item.name),
                    subtitle: Text('${item.description}\nPrice: \$${item.price.toStringAsFixed(2)}'), 
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: item.isAvailable,
                          onChanged: (bool value) async {
                            final updatedData = item.toJson();
                            updatedData['is_available'] = value;
                            await context.read<MenuNotifier>().updateMenuItem(item.id, updatedData);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: 'Edit Item',
                          onPressed: () => _navigateToAddEditScreen(context, item: item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Delete Item',
                          onPressed: () => _confirmDeleteItem(context, item),
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (menuNotifier.isItemLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.1),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
