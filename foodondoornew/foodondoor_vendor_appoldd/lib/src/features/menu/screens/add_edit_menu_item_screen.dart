import 'dart:io'; // Import dart:io for File
import 'package:cached_network_image/cached_network_image.dart'; // Import CachedNetworkImage
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; // Import provider
import 'package:foodondoor_vendor_app/src/features/menu/models/category_model.dart';
import 'package:foodondoor_vendor_app/src/features/menu/models/menu_item.dart'; // Import MenuItem
import 'package:foodondoor_vendor_app/src/features/menu/providers/category_provider.dart';
import 'package:foodondoor_vendor_app/src/features/menu/providers/menu_provider.dart';
import 'package:image_picker/image_picker.dart'; // Import image_picker

class AddEditMenuItemScreen extends StatefulWidget {
  final MenuItem? menuItem; // Null if adding, non-null if editing

  // Add the constructor back
  const AddEditMenuItemScreen({super.key, this.menuItem});

  @override
  AddEditMenuItemScreenState createState() => AddEditMenuItemScreenState();
}

class AddEditMenuItemScreenState extends State<AddEditMenuItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  String? _selectedCategoryId; // State for selected category ID
  bool _isAvailable = true;
  bool _isVegetarian = false;
  XFile? _pickedImageFile; // State for picked image file
  final ImagePicker _picker = ImagePicker(); // ImagePicker instance

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CategoryNotifier>(context, listen: false).fetchCategories();
    });
    final item = widget.menuItem;
    _nameController = TextEditingController(text: item?.name ?? '');
    _descriptionController = TextEditingController(text: item?.description ?? '');
    _priceController = TextEditingController(text: item?.price.toString() ?? '');
    // Use categoryId
    _selectedCategoryId = item?.categoryId; // Initialize selected ID if editing
    _isAvailable = item?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // Helper methods for picking/removing image
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80, // Optional: Adjust quality
        maxWidth: 1024,   // Optional: Adjust max width
        maxHeight: 1024,  // Optional: Adjust max height
      );
      if (pickedFile != null) {
        setState(() {
          _pickedImageFile = pickedFile;
        });
      }
    } catch (e) {
      print("Error picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to pick image.')),
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _pickedImageFile = null;
      // Note: This only removes the local preview/selection.
      // To remove the image on the server during an update,
      // the backend API would need to support setting the image to null.
      // Our current setup with PATCH might implicitly handle this if 'image' is not sent,
      // but explicit handling (e.g., sending {'image': null}) might be safer if supported.
    });
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final menuNotifier = Provider.of<MenuNotifier>(context, listen: false);

      // Prepare data as Map<String, dynamic>
      final Map<String, dynamic> itemData = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'category': _selectedCategoryId,
        'is_available': _isAvailable,
        'is_vegetarian': _isVegetarian,
      };

      bool success = false;
      try {
        if (widget.menuItem == null) {
          // Add new item
          success = await menuNotifier.addMenuItem(itemData, imageFile: _pickedImageFile);
        } else {
          // Update existing item
          success = await menuNotifier.updateMenuItem(widget.menuItem!.id, itemData, imageFile: _pickedImageFile);
        }

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Menu item ${widget.menuItem == null ? 'added' : 'updated'} successfully!')),
          );
          Navigator.of(context).pop();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to ${widget.menuItem == null ? 'add' : 'update'} menu item. ${menuNotifier.errorMessage ?? ''}')),
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

  // Build method for Image Picker section
  Widget _buildImagePicker() {
    final currentImageUrl = widget.menuItem?.imageUrl;
    Widget imagePreview = const SizedBox.shrink();

    // Display network image if editing, exists, and no new file picked
    if (_pickedImageFile == null && currentImageUrl != null && currentImageUrl.isNotEmpty) {
      imagePreview = CachedNetworkImage(
        imageUrl: currentImageUrl,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }
    // Display picked file image if it exists
    else if (_pickedImageFile != null) {
      imagePreview = Image.file(
        File(_pickedImageFile!.path),
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Menu Item Image (Optional)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade100, // Background color
          ),
          clipBehavior: Clip.antiAlias, // Clip the image to the rounded corners
          child: (_pickedImageFile == null && (currentImageUrl == null || currentImageUrl.isEmpty))
              ? const Center(child: Text('No Image Selected', style: TextStyle(color: Colors.grey)))
              : imagePreview,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Gallery'),
              onPressed: () => _pickImage(ImageSource.gallery),
            ),
            TextButton.icon(
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Camera'),
              onPressed: () => _pickImage(ImageSource.camera),
            ),
            // Show remove button only if there's an image (picked or existing)
            if (_pickedImageFile != null || (currentImageUrl != null && currentImageUrl.isNotEmpty))
              TextButton.icon(
                icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                label: Text('Remove', style: TextStyle(color: Colors.red.shade700)),
                onPressed: _removeImage,
                style: TextButton.styleFrom(foregroundColor: Colors.red.shade700)
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the category provider state
    final categoryNotifier = context.watch<CategoryNotifier>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.menuItem == null ? 'Add Menu Item' : 'Edit Menu Item'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              // --- Image Picker --- 
              _buildImagePicker(),
              // --- Category Dropdown --- 
              Consumer<CategoryNotifier>(
                builder: (context, categoryNotifier, child) {
                  if (categoryNotifier.isLoading) {
                    return DropdownButtonFormField<String>(
                      items: [],
                      hint: Text('Loading categories...'),
                      onChanged: null,
                    );
                  } 
                  else if (categoryNotifier.categories.isEmpty) {
                    return const Text('No categories found. Please add categories first.');
                  }

                  // Ensure _selectedCategoryId is valid or null
                  final categoryIds = categoryNotifier.categories.map((c) => c.id).toSet();
                  if (_selectedCategoryId != null && !categoryIds.contains(_selectedCategoryId)) {
                    _selectedCategoryId = null;
                  }
                  return DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    hint: const Text('Select Category'),
                    items: categoryNotifier.categories
                        .map<DropdownMenuItem<String>>((Category category) {
                      return DropdownMenuItem<String>(
                        value: category.id,
                        child: Text(category.name),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCategoryId = newValue;
                      });
                    },
                    validator: (value) => value == null ? 'Please select a category' : null,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              // --- Name --- 
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // --- Description --- 
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // --- Price --- 
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price', prefixText: '\$'), // Escaped dollar
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // --- Availability & Vegetarian Switches --- 
              Row(
                children: [
                  SwitchListTile(
                    title: const Text('Available for Ordering'),
                    value: _isAvailable,
                    onChanged: (bool value) {
                      setState(() {
                        _isAvailable = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Vegetarian'),
                    value: _isVegetarian,
                    onChanged: (bool value) {
                      setState(() {
                        _isVegetarian = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // --- Submit Button --- 
              ElevatedButton(
                onPressed: _submit,
                child: Consumer<MenuNotifier>( // Use Consumer to show loading state
                  builder: (context, menuNotifier, child) {
                    return menuNotifier.isItemLoading // Check item-specific loading state
                        ? const SizedBox(
                            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(widget.menuItem == null ? 'Add Item' : 'Update Item');
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
