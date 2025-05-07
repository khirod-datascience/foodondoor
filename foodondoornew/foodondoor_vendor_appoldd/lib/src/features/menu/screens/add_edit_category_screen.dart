import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:foodondoor_vendor_app/src/features/menu/models/category_model.dart';
import 'package:foodondoor_vendor_app/src/features/menu/providers/category_provider.dart';

class AddEditCategoryScreen extends StatefulWidget {
  static const routeNameAdd = '/add-category';
  final Category? category; // Null if adding, non-null if editing

  const AddEditCategoryScreen({Key? key, this.category}) : super(key: key);

  AddEditCategoryScreenState createState() => AddEditCategoryScreenState();
}

class AddEditCategoryScreenState extends State<AddEditCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    final cat = widget.category;
    _nameController = TextEditingController(text: cat?.name ?? '');
    _descriptionController = TextEditingController(text: cat?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text;
      final description = _descriptionController.text;
      final notifier = Provider.of<CategoryNotifier>(context, listen: false);

      bool success = false;
      try {
        if (widget.category == null) {
          // Add new category
          success = await notifier.addCategory(name, description: description.isNotEmpty ? description : null);
        } else {
          // Update existing category
          success = await notifier.updateCategory(widget.category!.id, name, description: description.isNotEmpty ? description : null);
        }

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Category ${widget.category == null ? 'added' : 'updated'} successfully!')),
          );
          Navigator.of(context).pop(); // Go back to the list
        } else if (mounted) {
          // Show error message from notifier if operation failed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to ${widget.category == null ? 'add' : 'update'} category. ${notifier.errorMessage ?? ''}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('An error occurred: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category == null ? 'Add Category' : 'Edit Category'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Category Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a category name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description (Optional)'),
                maxLines: 3,
                // No validator needed for optional field
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitForm,
                child: Consumer<CategoryNotifier>(
                  builder: (context, notifier, child) {
                    return notifier.isMutating
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(widget.category == null ? 'Add Category' : 'Update Category');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
