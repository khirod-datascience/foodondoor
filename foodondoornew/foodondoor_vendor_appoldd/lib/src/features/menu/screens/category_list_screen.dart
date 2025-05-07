import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:foodondoor_vendor_app/src/features/menu/models/category_model.dart';
import 'package:foodondoor_vendor_app/src/features/menu/providers/category_provider.dart';
import 'package:foodondoor_vendor_app/src/features/menu/screens/add_edit_category_screen.dart';

class CategoryListScreen extends StatelessWidget {
  const CategoryListScreen({super.key});

  void _navigateToAddEditScreen(BuildContext context, {Category? category}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddEditCategoryScreen(category: category),
      ),
    );
  }

  Future<void> _deleteCategory(BuildContext context, String id) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        // Use a StatefulBuilder to manage the loading state within the dialog
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Delete Category'),
            content: const Text('Are you sure you want to delete this category? This cannot be undone.'),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: isDeleting ? null : () => Navigator.of(dialogContext).pop(),
              ),
              TextButton(
                child: isDeleting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Delete'),
                onPressed: isDeleting ? null : () async {
                  setState(() => isDeleting = true);
                  final notifier = Provider.of<CategoryNotifier>(context, listen: false);
                  final success = await notifier.deleteCategory(id);

                  // Use dialogContext to pop
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();

                  // Show feedback in the main context
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? 'Category deleted.' : 'Failed to delete category. ${notifier.errorMessage ?? ''}')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Category',
            onPressed: () => _navigateToAddEditScreen(context),
          ),
        ],
      ),
      body: Consumer<CategoryNotifier>(
        builder: (context, categoryNotifier, child) {
          // Check loading state
          if (categoryNotifier.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Check for errors
          if (categoryNotifier.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${categoryNotifier.errorMessage}'),
                  ElevatedButton(
                    onPressed: () => context.read<CategoryNotifier>().fetchCategories(),
                    child: const Text('Retry'),
                  )
                ],
              ),
            );
          }

          // Display categories if loaded
          final categories = categoryNotifier.categories;
          if (categories.isEmpty) {
            return const Center(
              child: Text('No categories found. Add one using the + button.'),
            );
          }

          // Build the list view
          return Stack(
            children: [
              ListView.builder(
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return ListTile(
                    title: Text(category.name),
                    subtitle: Text(category.description ?? 'No description'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          tooltip: 'Edit Category',
                          onPressed: () => _navigateToAddEditScreen(context, category: category),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Delete Category',
                          onPressed: () => _deleteCategory(context, category.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Show a loading indicator during item mutations (add/update/delete)
              if (categoryNotifier.isMutating)
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
